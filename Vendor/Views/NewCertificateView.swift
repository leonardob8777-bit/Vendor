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
	@Environment(\.dismiss) private var dismiss
	private let store = CertificateStore.shared

	@State private var certificateFile: URL?
	@State private var provisioningFile: URL?
	@State private var password = ""
	@State private var nickname = ""
	@State private var revealPassword = false

	private enum PickMode { case certificate, provision }

	@State private var isSaving = false
	@State private var failure: String?

	private var canSave: Bool {
		certificateFile != nil && provisioningFile != nil && !isSaving
	}

	var body: some View {
		ZStack(alignment: .top) {
			// No aurora here: this sheet sits over a screen that already draws
			// one, and running two animated backdrops at once is what made the
			// panel stutter on device.
			Color.canvas.ignoresSafeArea()

			ScrollView {
				VStack(spacing: 16) {
					topBar
					heading
					requiredFiles
					certificateDetails
					if let failure {
						failureNote(failure)
					}
				}
				.padding(.horizontal, 16)
				.padding(.top, 6)
				.padding(.bottom, 28)
			}
		}
	}

	// MARK: Picking

	private func pick(_ mode: PickMode) {
		DocumentPicker.present(contentTypes: [.data]) { urls in
			guard let url = urls.first else { return }
			let ext = url.pathExtension.lowercased()
			switch mode {
			case .certificate:
				guard ext == "p12" || ext == "pfx" else {
					failure = "That is not a .p12 file."
					return
				}
				failure = nil
				certificateFile = url
			case .provision:
				guard ext == "mobileprovision" else {
					failure = "That is not a .mobileprovision file."
					return
				}
				failure = nil
				provisioningFile = url
			}
		}
	}

	// MARK: Actions

	private func handlePick(_ result: Result<[URL], Error>, assign: (URL) -> Void) {
		switch result {
		case .success(let urls):
			guard let url = urls.first else { return }
			failure = nil
			assign(url)
		case .failure(let error):
			failure = error.localizedDescription
		}
	}

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
						?? "The engine could not use this certificate. Check the password."
					store.delete(cert)
				}
			} catch {
				isSaving = false
				failure = error.localizedDescription
			}
		}
	}

	// MARK: Chrome

	private var topBar: some View {
		HStack {
			Button { dismiss() } label: {
				Image(systemName: "xmark")
					.font(.system(size: 14, weight: .bold))
					.foregroundStyle(Color.inkPrimary)
					.glassCircle(size: 38)
			}

			Spacer()

			Button(action: save) {
				HStack(spacing: 8) {
					if isSaving {
						ProgressView().tint(.white)
					} else {
						Text(t("certs.save"))
							.font(.system(size: 15, weight: .semibold))
						Image(systemName: "checkmark.circle.fill")
							.font(.system(size: 17))
					}
				}
				.foregroundStyle(.white)
				.frame(minWidth: 104)
				.padding(.leading, 18)
				.padding(.trailing, 8)
				.padding(.vertical, 10)
				.background(
					Capsule().fill(
						LinearGradient(colors: [.mint, .mintDeep], startPoint: .leading, endPoint: .trailing)
					)
				)
				.opacity(canSave ? 1 : 0.45)
			}
			.disabled(!canSave)
		}
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
				.frame(width: 96, height: 96)
		}
		.padding(.top, 8)
	}

	// MARK: Step 1

	private var requiredFiles: some View {
		VStack(alignment: .leading, spacing: 12) {
			stepHeader(index: "1.", title: "Required Files")

			HStack(alignment: .top, spacing: 12) {
				timeline
				VStack(spacing: 10) {
					fileRow(
						title: "Certificate File",
						detail: certificateFile?.lastPathComponent ?? ".p12 file required",
						glyph: "doc.text",
						tint: .mint,
						picked: certificateFile != nil
					) { pick(.certificate) }

					fileRow(
						title: "Provisioning File",
						detail: provisioningFile?.lastPathComponent ?? ".mobileprovision file required",
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
			GlyphTile(systemName: picked ? "checkmark.circle.fill" : glyph, tint: tint, size: 44)

			VStack(alignment: .leading, spacing: 2) {
				Text(title)
					.font(.system(size: 15, weight: .semibold))
					.foregroundStyle(Color.inkPrimary)
				Text(detail)
					.font(.system(size: 11.5))
					.foregroundStyle(picked ? tint : Color.inkSecondary)
					.lineLimit(2)
					.minimumScaleFactor(0.85)
					.fixedSize(horizontal: false, vertical: true)
			}

			Spacer(minLength: 6)

			Button(action: action) {
				Text(picked ? "Change" : "Import")
					.font(.system(size: 13, weight: .semibold))
					.foregroundStyle(tint)
					.padding(.horizontal, 16)
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
			stepHeader(index: "2.", title: "Certificate Details")

			field(glyph: "lock", tint: .mint) {
				HStack(spacing: 8) {
					Group {
						if revealPassword {
							TextField(t("certs.password"), text: $password)
						} else {
							SecureField("Password (Optional)", text: $password)
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
				}
			}

			field(glyph: "person", tint: .brand) {
				TextField(t("certs.nickname"), text: $nickname)
					.font(.system(size: 15))
					.foregroundStyle(Color.inkPrimary)
					.autocorrectionDisabled()
			}

			HStack(alignment: .top, spacing: 10) {
				Image(systemName: "info.circle")
					.font(.system(size: 15))
					.foregroundStyle(Color.brand)
				Text(t("certs.passwordHint"))
					.font(.system(size: 12))
					.foregroundStyle(Color.inkSecondary)
					.fixedSize(horizontal: false, vertical: true)
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

	private func stepHeader(index: String, title: String) -> some View {
		HStack(spacing: 8) {
			Circle().fill(Color.mint).frame(width: 9, height: 9)
			Text(index)
				.font(.system(size: 15, weight: .bold))
				.foregroundStyle(Color.inkPrimary)
			Text(title)
				.font(.system(size: 15, weight: .bold))
				.foregroundStyle(Color.inkPrimary)
			Spacer(minLength: 0)
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
