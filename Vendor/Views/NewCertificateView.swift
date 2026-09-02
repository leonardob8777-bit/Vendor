//
//  NewCertificateView.swift
//  Vendor
//
//  Collects the two files and the optional details needed to register a
//  signing identity, then hands them to CertificateStore, which asks the
//  engine whether the pair can actually sign.
//

import SwiftUI
import UniformTypeIdentifiers

extension UTType {
	/// PKCS#12 key bundle.
	static let p12 = UTType(filenameExtension: "p12") ?? .data
	static let mobileProvision = UTType(filenameExtension: "mobileprovision") ?? .data
}

struct NewCertificateView: View {
	/// Called on close. Presented as an overlay rather than a sheet, so
	/// there is no environment dismiss to reach for.
	var dismiss: () -> Void
	private let store = CertificateStore.shared

	@State private var certificateFile: URL?
	@State private var provisioningFile: URL?
	@State private var password = ""
	@State private var nickname = ""
	@State private var revealPassword = false

	private enum PickMode { case certificate, provision }

	@State private var isSaving = false
	@State private var failure: String?
	/// Whether the discard dialog is up. Tapping away or the X asks first
	/// once there is anything picked or typed — see `requestDismiss`.
	@State private var confirmingDiscard = false
	/// Not read directly — its presence keeps this view subscribed to
	/// `Localizer.shared`, so every `t(...)` call below redraws when the
	/// language flips.
	@ObservedObject private var localizer = Localizer.shared

	/// Both files picked, independent of whether a save is in flight — the
	/// badge on step 1 reads this, and shouldn't flip back to "still needed"
	/// the moment Save is tapped.
	private var filesReady: Bool {
		certificateFile != nil && provisioningFile != nil
	}

	private var canSave: Bool { filesReady && !isSaving }

	var body: some View {
		ZStack {
			// No dimming layer and no backdrop of its own: the caller blurs the
			// screen behind through `Screen(contentBlur:)`, the same as every
			// other floating window.
			Color.clear
				.ignoresSafeArea()
				.contentShape(Rectangle())
				.onTapGesture(perform: requestDismiss)

			panel
				.padding(.horizontal, 26)
				.padding(.vertical, 100)
		}
		// Hiding the tab bar changes the bottom inset partway through the
		// opening, and a panel measured against it settles downwards after it
		// appears. See `AppDetailSheet`.
		.ignoresSafeArea(edges: .bottom)
		// A dialog rather than one of this app's own floating panels, for the
		// same reason `IPAView` reaches for one over its delete: it is the
		// system's own affordance for a destructive answer.
		.confirmationDialog(
			t("certs.discardTitle"),
			isPresented: $confirmingDiscard,
			titleVisibility: .visible
		) {
			Button(t("certs.discard"), role: .destructive, action: dismiss)
		} message: {
			Text(t("certs.discardDetail"))
		}
	}

	/// Tapping away or the X closes it outright, unless that would throw work
	/// away — then it asks first instead of doing nothing.
	///
	/// The X used to dismiss unconditionally regardless of what was picked or
	/// typed, while tapping the background right beside it silently swallowed
	/// the same tap whenever there was anything to lose. Two controls for the
	/// same action disagreeing about what it does reads as one of them being
	/// broken; now both go through this.
	private func requestDismiss() {
		guard !isSaving else { return }
		if canLeaveByTappingAway {
			dismiss()
		} else {
			confirmingDiscard = true
		}
	}

	private var canLeaveByTappingAway: Bool {
		certificateFile == nil
			&& provisioningFile == nil
			&& password.isEmpty
			&& nickname.isEmpty
	}

	private var panel: some View {
		ZStack(alignment: .topTrailing) {
			ScrollView {
				VStack(spacing: 16) {
					heading
					requiredFiles
					certificateDetails
					if let failure {
						failureNote(failure)
					}
					saveButton
				}
				.padding(.horizontal, 18)
				.padding(.top, 22)
				.padding(.bottom, 26)
			}
			.scrollBounceBehaviorCompat()
			.mask(
				LinearGradient(
					stops: [
						.init(color: .black, location: 0),
						.init(color: .black, location: 0.90),
						.init(color: .black.opacity(0), location: 1),
					],
					startPoint: .top,
					endPoint: .bottom
				)
			)

			closeButton
				.padding(.top, 14)
				.padding(.trailing, 14)
		}
		.sheetPanelBackground()
	}

	// MARK: Picking

	private func pick(_ mode: PickMode) {
		DocumentPicker.present(contentTypes: [.data]) { urls in
			guard let url = urls.first else { return }
			let ext = url.pathExtension.lowercased()
			switch mode {
			case .certificate:
				guard ext == "p12" || ext == "pfx" else {
					failure = t("certs.notP12")
					return
				}
				failure = nil
				certificateFile = url
			case .provision:
				guard ext == "mobileprovision" else {
					failure = t("certs.notProvision")
					return
				}
				failure = nil
				provisioningFile = url
			}
		}
	}

	// MARK: Actions

	private func save() {
		guard let p12 = certificateFile, let provision = provisioningFile else { return }
		isSaving = true
		failure = nil

		Task {
			do {
				let cert = try await store.importCertificate(
					p12Source: p12,
					provisionSource: provision,
					password: password,
					nickname: nickname
				)
				isSaving = false
				if cert.isUsable {
					dismiss()
				} else {
					// Kept on screen so the password can be corrected.
					failure = cert.statusMessage
						?? t("certs.engineRefused")
					store.delete(cert)
				}
			} catch {
				isSaving = false
				failure = error.localizedDescription
			}
		}
	}

	// MARK: Chrome

	private var closeButton: some View {
		Button(action: requestDismiss) {
			Image(systemName: "xmark")
				.font(.system(size: 13, weight: .bold))
				.foregroundStyle(Color.inkPrimary)
				.glassCircle(size: 34)
		}
		.accessibilityLabel(t("common.close"))
	}

	/// Full width at the foot of the form rather than in a bar at the top.
	///
	/// The close button now owns the corner, and a Save that sits above the
	/// fields it saves reads as belonging to the screen rather than to the form.
	private var saveButton: some View {
		Button(action: save) {
			HStack(spacing: 8) {
				if isSaving {
					ProgressView().controlSize(.small).tint(.white)
				} else {
					Image(systemName: "checkmark.circle.fill")
						.font(.system(size: 15))
				}
				Text(t("certs.save"))
					.font(.system(size: 15, weight: .bold))
			}
			.foregroundStyle(.white)
			.frame(maxWidth: .infinity)
			.padding(.vertical, 12)
			.background(
				Capsule().fill(
					LinearGradient(colors: [.mint, .mintDeep], startPoint: .leading, endPoint: .trailing)
				)
			)
			.opacity(canSave ? 1 : 0.45)
		}
		.buttonStyle(.plain)
		.disabled(!canSave)
		.padding(.top, 2)
	}

	private var heading: some View {
		HStack(alignment: .top, spacing: 12) {
			VStack(alignment: .leading, spacing: 8) {
				Text(t("certs.new"))
					.font(.system(size: 28, weight: .bold))
					.foregroundStyle(Color.inkPrimary)
				Text(t("certs.newDetail"))
					.font(.system(size: 14))
					.foregroundStyle(Color.inkSecondary)
					.fixedSize(horizontal: false, vertical: true)
			}
			Spacer(minLength: 0)
			CertificateEmblem()
				.frame(width: 64, height: 64)
		}
		.padding(.trailing, 40) // clears the close button
	}

	// MARK: Step 1

	private var requiredFiles: some View {
		VStack(alignment: .leading, spacing: 12) {
			stepHeader(
				index: "1.", title: t("certs.stepFiles"),
				trailing: filesReady ? t("certs.readyTitle") : t("certs.missingTitle"),
				trailingTone: filesReady ? .ok : .warn
			)

			Text(t("certs.inside"))
				.font(.system(size: 11, weight: .medium))
				.foregroundStyle(Color.inkSecondary)

			HStack(alignment: .top, spacing: 12) {
				timeline
				VStack(spacing: 10) {
					fileRow(
						title: t("certs.certificateFile"),
						detail: certificateFile?.lastPathComponent ?? t("certs.p12Required"),
						glyph: "doc.text",
						tint: .mint,
						picked: certificateFile != nil
					) { pick(.certificate) }

					fileRow(
						title: t("certs.provisionFile"),
						detail: provisioningFile?.lastPathComponent ?? t("certs.provisionRequired"),
						glyph: "doc.on.doc",
						tint: .brand,
						picked: provisioningFile != nil
					) { pick(.provision) }
				}
			}
		}
		.card(padding: 14)
	}

	private var timeline: some View {
		VStack(spacing: 0) {
			Circle().fill(certificateFile != nil ? Color.mint : Color.mint.opacity(0.35))
				.frame(width: 9, height: 9)
			Rectangle()
				.fill(LinearGradient(colors: [.mint, .brand], startPoint: .top, endPoint: .bottom))
				.frame(width: 2)
			Circle().fill(provisioningFile != nil ? Color.brand : Color.brand.opacity(0.35))
				.frame(width: 9, height: 9)
		}
		.padding(.vertical, 30)
		.frame(width: 9)
	}

	private func fileRow(
		title: String,
		detail: String,
		glyph: String,
		tint: Color,
		picked: Bool,
		action: @escaping () -> Void
	) -> some View {
		HStack(spacing: 12) {
			GlyphTile(systemName: picked ? "checkmark.circle.fill" : glyph, tint: tint, size: 38)

			VStack(alignment: .leading, spacing: 2) {
				Text(title)
					.font(.system(size: 14, weight: .semibold))
					.foregroundStyle(Color.inkPrimary)
					.lineLimit(1)
					.minimumScaleFactor(0.8)
				Text(detail)
					.font(.system(size: 11.5))
					.foregroundStyle(picked ? tint : Color.inkSecondary)
					.lineLimit(2)
					.minimumScaleFactor(0.85)
					.fixedSize(horizontal: false, vertical: true)
			}

			Spacer(minLength: 6)

			Button(action: action) {
				Text(picked ? t("certs.change") : t("certs.import"))
					.font(.system(size: 13, weight: .semibold))
					.foregroundStyle(tint)
					.fixedSize()
					.padding(.horizontal, 12)
					.padding(.vertical, 8)
					.background(Capsule().fill(tint.opacity(0.14)))
			}
		}
		.padding(10)
		.background(.ultraThinMaterial)
		.clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
	}

	// MARK: Step 2

	private var certificateDetails: some View {
		VStack(alignment: .leading, spacing: 12) {
			stepHeader(index: "2.", title: t("certs.stepDetails"))

			field(glyph: "lock", tint: .mint) {
				HStack(spacing: 8) {
					Group {
						if revealPassword {
							TextField(t("certs.password"), text: $password)
						} else {
							SecureField(t("certs.password"), text: $password)
						}
					}
					.font(.system(size: 15))
					.foregroundStyle(Color.inkPrimary)
					.autocorrectionDisabled()
					.textInputAutocapitalization(.never)

					Button { revealPassword.toggle() } label: {
						Image(systemName: revealPassword ? "eye.slash" : "eye")
							.font(.system(size: 15))
							.foregroundStyle(Color.inkSecondary)
					}
					.accessibilityLabel(revealPassword ? t("certs.hidePassword") : t("certs.showPassword"))
				}
			}

			field(glyph: "person", tint: .brand) {
				TextField(t("certs.nickname"), text: $nickname)
					.font(.system(size: 15))
					.foregroundStyle(Color.inkPrimary)
					.autocorrectionDisabled()
			}
			Text(t("certs.nicknameHint"))
				.font(.system(size: 11))
				.foregroundStyle(Color.inkSecondary)
				.padding(.leading, 4)

			HStack(alignment: .top, spacing: 10) {
				Image(systemName: "info.circle")
					.font(.system(size: 15))
					.foregroundStyle(Color.brand)
				VStack(alignment: .leading, spacing: 6) {
					Text(t("certs.passwordHint"))
						.font(.system(size: 12))
						.foregroundStyle(Color.inkSecondary)
						.fixedSize(horizontal: false, vertical: true)
					// Where it came from, not just what to do with it — the
					// operational note above says nothing about where it ends
					// up, and "somewhere I typed a password into" is the part
					// worth a sentence of its own.
					Text(t("certs.passwordSource"))
						.font(.system(size: 11))
						.foregroundStyle(Color.inkSecondary.opacity(0.85))
						.fixedSize(horizontal: false, vertical: true)
				}
			}
			.padding(12)
			.frame(maxWidth: .infinity, alignment: .leading)
			.background(.ultraThinMaterial)
			.clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
		}
		.card(padding: 14)
	}

	private func field<C: View>(glyph: String, tint: Color, @ViewBuilder content: () -> C) -> some View {
		HStack(spacing: 12) {
			GlyphTile(systemName: glyph, tint: tint, size: 38)
			content()
		}
		.padding(10)
		.background(.ultraThinMaterial)
		.clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
	}

	// MARK: Bits

	private func failureNote(_ message: String) -> some View {
		HStack(alignment: .top, spacing: 10) {
			Image(systemName: "exclamationmark.triangle.fill")
				.font(.system(size: 15))
				.foregroundStyle(Color.bad)
			Text(message)
				.font(.system(size: 13))
				.foregroundStyle(Color.inkPrimary)
				.fixedSize(horizontal: false, vertical: true)
		}
		.padding(14)
		.frame(maxWidth: .infinity, alignment: .leading)
		.background(Color.badSoft)
		.clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
	}

	private func stepHeader(
		index: String, title: String,
		trailing: String? = nil, trailingTone: Badge.Tone = .neutral
	) -> some View {
		HStack(spacing: 8) {
			Circle().fill(Color.mint).frame(width: 9, height: 9)
			Text(index)
				.font(.system(size: 15, weight: .bold))
				.foregroundStyle(Color.inkPrimary)
			Text(title)
				.font(.system(size: 15, weight: .bold))
				.foregroundStyle(Color.inkPrimary)
			Spacer(minLength: 0)
			if let trailing {
				Badge(text: trailing, tone: trailingTone)
			}
		}
	}
}

/// Layered emblem standing in for the illustration in the design.
struct CertificateEmblem: View {
	var body: some View {
		ZStack {
			Circle()
				.fill(
					RadialGradient(
						colors: [Color.mint.opacity(0.35), .clear],
						center: .center, startRadius: 4, endRadius: 60
					)
				)

			RoundedRectangle(cornerRadius: 26, style: .continuous)
				.fill(
					LinearGradient(
						colors: [Color.mint.opacity(0.55), Color.brand.opacity(0.45)],
						startPoint: .topLeading, endPoint: .bottomTrailing
					)
				)
				.rotationEffect(.degrees(12))
				.frame(width: 68, height: 68)

			RoundedRectangle(cornerRadius: 22, style: .continuous)
				.fill(
					LinearGradient(
						colors: [.white.opacity(0.75), .white.opacity(0.25)],
						startPoint: .topLeading, endPoint: .bottomTrailing
					)
				)
				.frame(width: 46, height: 46)

			Image(systemName: "checkmark")
				.font(.system(size: 20, weight: .heavy))
				.foregroundStyle(Color.mint)
		}
	}
}
