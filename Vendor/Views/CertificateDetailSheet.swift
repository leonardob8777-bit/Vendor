//
//  CertificateDetailSheet.swift
//  Vendor
//
//  What a row on the Certificates list stands for, opened up. Same floating
//  panel every other detail window in the app uses — GuideDetailSheet,
//  TrustSetupSheet — so a certificate reads as one more thing you can look
//  inside of, not a screen of its own.
//

import SwiftUI
import UIKit

struct CertificateDetailSheet: View {
	let certificate: StoredCertificate
	/// Whether this is the certificate Home is currently signing with —
	/// decided by `CertificatesView`, which already has to compute it for the
	/// row's own badge, so it is handed down rather than recomputed here.
	let isLead: Bool
	let mood: FaceGlyph.Mood
	let tint: Color

	var onDelete: () -> Void
	/// Called by the close button and by a tap outside the panel.
	var dismiss: () -> Void

	/// Not read directly — its presence keeps this view subscribed to
	/// `Localizer.shared`, so every `t(...)` call below redraws when the
	/// language flips.
	@ObservedObject private var localizer = Localizer.shared

	private var health: StoredCertificate.Health { certificate.health() }

	/// Device count and kind of trust never made it into `StoredCertificate` —
	/// only the fields the Home countdown needs did. Reading the profile again
	/// here costs one small plist parse and means nothing else has to carry
	/// data the list screen never asked for.
	///
	/// Read once into a stored property rather than a computed one: this file
	/// is read from three separate places below, and re-parsing the plist for
	/// each one would multiply for no reason.
	private let profile: ProvisioningProfile?

	/// Keyed on this certificate's own id rather than one app-wide switch, so
	/// turning notifications off for a certificate that is about to be
	/// replaced does not silently mute the next one imported after it.
	/// Defaults to on: the point of this feature is that it works without
	/// anyone having to find the setting first.
	@AppStorage private var notifyEnabled: Bool
	@State private var confirmingExport = false
	@State private var passwordCopied = false

	init(
		certificate: StoredCertificate,
		isLead: Bool,
		mood: FaceGlyph.Mood,
		tint: Color,
		onDelete: @escaping () -> Void,
		dismiss: @escaping () -> Void
	) {
		self.certificate = certificate
		self.isLead = isLead
		self.mood = mood
		self.tint = tint
		self.onDelete = onDelete
		self.dismiss = dismiss
		self.profile = ProvisioningProfile.read(at: CertificateStore.shared.provisionURL(for: certificate.id))
		self._notifyEnabled = AppStorage(wrappedValue: true, "certNotify.\(certificate.id.uuidString)")
	}

	var body: some View {
		ZStack {
			Color.clear
				.ignoresSafeArea()
				.contentShape(Rectangle())
				.onTapGesture(perform: dismiss)

			panel
				.padding(.horizontal, 26)
				.padding(.vertical, 100)
		}
		// See AppDetailSheet: hiding the tab bar pulls its inset out of the
		// bottom of the safe area partway through the opening, and a panel
		// measured against it would settle downwards as that happens.
		.ignoresSafeArea(edges: .bottom)
		// The toggle already flipped and redrew by the time this fires — this
		// only has to make the notifier agree with what is now on screen.
		// Scoped to this one certificate rather than a full store resync,
		// which would also be correct but means walking every certificate to
		// react to one switch.
		.onChange(of: notifyEnabled) { _ in
			CertificateExpiryNotifier.apply(to: certificate)
		}
	}

	private var panel: some View {
		ZStack(alignment: .topTrailing) {
			ScrollView {
				VStack(alignment: .leading, spacing: 16) {
					header
					facts
					notifyToggle

					if case .rejected(let reason) = health {
						CalloutRow(text: "\(t("certs.rejectedReason")): \(reason)")
					}
					if profile == nil {
						CalloutRow(text: t("certs.profileUnreadable"))
					}

					exportRow
					deleteButton
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
		.background {
			ZStack {
				RoundedRectangle(cornerRadius: 28, style: .continuous)
					.fill(.ultraThinMaterial)
				RoundedRectangle(cornerRadius: 28, style: .continuous)
					.fill(
						LinearGradient(
							colors: [Color.brand.opacity(0.13), Color.mint.opacity(0.07)],
							startPoint: .topLeading, endPoint: .bottomTrailing
						)
					)
				RoundedRectangle(cornerRadius: 28, style: .continuous)
					.strokeBorder(
						LinearGradient(
							colors: [.white.opacity(0.28), .white.opacity(0.05), Color.mint.opacity(0.18)],
							startPoint: .topLeading, endPoint: .bottomTrailing
						),
						lineWidth: 1
					)
			}
		}
		.clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
		.shadow(color: .black.opacity(0.45), radius: 30, y: 16)
		.shadow(color: Color.brand.opacity(0.20), radius: 36, y: 20)
	}

	// MARK: Header

	private var header: some View {
		VStack(alignment: .leading, spacing: 10) {
			HStack(spacing: 12) {
				FaceGlyph(mood: mood, tint: tint, size: 48)
				VStack(alignment: .leading, spacing: 4) {
					Text(certificate.name)
						.font(.system(size: 20, weight: .bold))
						.foregroundStyle(Color.inkPrimary)
						.lineLimit(2)
					if isLead {
						Badge(text: t("certs.lead"), tone: .brand)
					}
				}
				Spacer(minLength: 0)
			}

			// Only where the badge above is actually true — this is what
			// "Main" means, and it belongs beside the one certificate it
			// currently describes, not as a standing banner on the list.
			if isLead {
				Text(t("certs.leadNote"))
					.font(.system(size: 12))
					.foregroundStyle(Color.inkSecondary)
					.fixedSize(horizontal: false, vertical: true)
			}
		}
		.padding(.trailing, 40) // clears the close button
	}

	// MARK: Facts

	private var facts: some View {
		VStack(alignment: .leading, spacing: 0) {
			Text(t("certs.inside"))
				.font(.system(size: 11, weight: .medium))
				.foregroundStyle(Color.inkSecondary)
				.padding(.bottom, 8)

			VStack(spacing: 10) {
				fact(t("certs.team"), certificate.issuer ?? t("certs.unknownTeam"))
				fact(t("certs.type"), typeLabel)
				if let worksOn {
					fact(t("certs.worksOn"), worksOn)
				}
				expiryFact
				fact(t("certs.importedLabel"), formatted(certificate.importedAt))
			}
			.padding(14)
			.background(.ultraThinMaterial)
			.clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

			if worksOn != nil, !(profile?.provisionsAllDevices ?? true) {
				Text(t("certs.deviceNote"))
					.font(.system(size: 11))
					.foregroundStyle(Color.inkSecondary)
					.fixedSize(horizontal: false, vertical: true)
					.padding(.top, 8)
			}
		}
	}

	// MARK: Expiry notifications

	/// Nothing to warn about without a date, so the row does not offer a
	/// switch that would never do anything — matches `CertificateExpiryNotifier`,
	/// which skips a certificate with no `expiresAt` the same way.
	@ViewBuilder
	private var notifyToggle: some View {
		if certificate.expiresAt != nil {
			HStack(spacing: 10) {
				Image(systemName: notifyEnabled ? "bell.fill" : "bell.slash")
					.font(.system(size: 13, weight: .light))
					.foregroundStyle(notifyEnabled ? Color.brand : Color.inkSecondary)
					.frame(width: 18)

				VStack(alignment: .leading, spacing: 1) {
					Text(t("certs.notifyToggle"))
						.font(.system(size: 12.5, weight: .medium))
						.foregroundStyle(Color.inkPrimary)
					Text(t("certs.notifyToggleNote"))
						.font(.system(size: 10))
						.foregroundStyle(Color.inkSecondary)
						.fixedSize(horizontal: false, vertical: true)
				}

				Spacer(minLength: 0)

				Toggle("", isOn: $notifyEnabled)
					.labelsHidden()
					.tint(Color.brand)
					.accessibilityLabel(t("certs.notifyToggle"))
			}
			.padding(9)
			.background(.ultraThinMaterial)
			.clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
		}
	}

	private func fact(_ label: String, _ value: String) -> some View {
		HStack(alignment: .top, spacing: 12) {
			Text(label)
				.font(.system(size: 13))
				.foregroundStyle(Color.inkSecondary)
			Spacer(minLength: 8)
			Text(value)
				.font(.system(size: 13, weight: .semibold))
				.foregroundStyle(Color.inkPrimary)
				.multilineTextAlignment(.trailing)
		}
	}

	@ViewBuilder
	private var expiryFact: some View {
		if let expiresAt = certificate.expiresAt {
			if expiresAt < Date() {
				fact(t("certs.expiredOnLabel"), formatted(expiresAt))
			} else {
				fact(t("certs.expiresLabel"), formatted(expiresAt))
			}
		} else {
			fact(t("certs.expiresLabel"), t("certs.noExpiry"))
		}
	}

	/// In the language picked in Vendor, not the phone's — see `HomeView`,
	/// which hit the same mismatch first.
	private func formatted(_ date: Date) -> String {
		date.formatted(
			Date.FormatStyle(date: .abbreviated, time: .omitted)
				.locale(Localizer.shared.language.locale)
		)
	}

	private var typeLabel: String {
		switch certificate.kind {
		case .development:  return t("certs.groupDeveloper")
		case .distribution: return t("certs.groupDistribution")
		case .enterprise:   return t("certs.groupEnterprise")
		case nil:            return t("certs.groupOther")
		}
	}

	private var worksOn: String? {
		guard let profile else { return nil }
		if profile.provisionsAllDevices { return t("certs.allDevices") }
		if profile.devices.count == 1 { return t("certs.deviceOne") }
		return String(format: t("certs.deviceCount"), profile.devices.count)
	}

	// MARK: Chrome

	private var closeButton: some View {
		Button(action: dismiss) {
			Image(systemName: "xmark")
				.font(.system(size: 13, weight: .bold))
				.foregroundStyle(Color.inkPrimary)
				.glassCircle(size: 34)
		}
		.accessibilityLabel(t("common.close"))
	}

	// MARK: Exporting

	/// Two actions side by side rather than export alone: a `.p12` shared
	/// without its password reaching the other end some other way is just a
	/// file nobody can open, so the means to relay the second half sits right
	/// next to the button that shares the first.
	private var exportRow: some View {
		HStack(spacing: 10) {
			Button {
				Haptics.tap()
				confirmingExport = true
			} label: {
				HStack(spacing: 8) {
					Image(systemName: "square.and.arrow.up")
						.font(.system(size: 13, weight: .medium))
					Text(t("certs.export"))
						.font(.system(size: 13, weight: .semibold))
				}
				.foregroundStyle(Color.brand)
				.frame(maxWidth: .infinity)
				.padding(.vertical, 11)
				.background(Capsule().fill(Color.brandSoft))
			}

			Button(action: copyPassword) {
				Image(systemName: passwordCopied ? "checkmark" : "doc.on.doc")
					.font(.system(size: 13, weight: .medium))
					.foregroundStyle(passwordCopied ? Color.ok : Color.inkSecondary)
					.frame(width: 42, height: 42)
					.background(.ultraThinMaterial)
					.clipShape(Circle())
			}
			.accessibilityLabel(t("certs.copyPassword"))
		}
		.confirmationDialog(
			t("certs.exportConfirm"),
			isPresented: $confirmingExport,
			titleVisibility: .visible
		) {
			Button(t("certs.export")) { export() }
		} message: {
			Text(t("certs.exportConfirmDetail"))
		}
	}

	private func export() {
		Haptics.tap()
		ShareSheet.present(items: [
			CertificateStore.shared.p12URL(for: certificate.id),
			CertificateStore.shared.provisionURL(for: certificate.id),
		])
	}

	private func copyPassword() {
		Haptics.tap()
		UIPasteboard.general.string = certificate.password
		withAnimation(.easeInOut(duration: 0.2)) { passwordCopied = true }
		Task {
			try? await Task.sleep(nanoseconds: 2_000_000_000)
			withAnimation(.easeInOut(duration: 0.2)) { passwordCopied = false }
		}
	}

	private var deleteButton: some View {
		Button(action: onDelete) {
			HStack(spacing: 8) {
				Image(systemName: "trash")
					.font(.system(size: 14, weight: .medium))
				Text(t("common.delete"))
					.font(.system(size: 14, weight: .semibold))
			}
			.foregroundStyle(Color.bad)
			.frame(maxWidth: .infinity)
			.padding(.vertical, 11)
			.background(Capsule().fill(Color.badSoft))
		}
		.padding(.top, 4)
	}
}
