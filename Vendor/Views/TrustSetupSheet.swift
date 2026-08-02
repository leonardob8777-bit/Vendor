//
//  TrustSetupSheet.swift
//  Vendor
//
//  One-time setup shown before the first install.
//
//  iOS will not fetch an install manifest from a host it does not trust, and
//  Vendor serves that manifest to itself. So the device has to accept Vendor's
//  own authority once. It is two trips to Settings, and skipping the
//  explanation would leave the user staring at a certificate prompt with no
//  idea why.
//

import SwiftUI

struct TrustSetupSheet: View {
	var onClose: () -> Void

	@State private var installer = Installer.shared
	@State private var failure: String?

	var body: some View {
		ZStack {
			// No dimming layer, for the reason spelled out in GuideDetailSheet:
			// a veil across the whole screen darkens the strip beside the
			// Dynamic Island too, where it reads as a black sheet laid over the
			// display rather than as depth.
			Color.clear
				.ignoresSafeArea()
				.contentShape(Rectangle())
				.onTapGesture(perform: onClose)

			panel
				.padding(.horizontal, 20)
		}
	}

	private var panel: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: 16) {
				header

				step(1, t("trust.step1"))
				step(2, t("trust.step2"))
				step(3, t("trust.step3"))

				Text(t("trust.why"))
					.font(.system(size: 11))
					.foregroundStyle(Color.inkSecondary)
					.fixedSize(horizontal: false, vertical: true)
					.padding(.top, 2)

				if let failure {
					Text(failure)
						.font(.system(size: 12))
						.foregroundStyle(Color.bad)
						.fixedSize(horizontal: false, vertical: true)
				}

				actions
			}
			.padding(20)
		}
		.frame(maxHeight: 520)
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
	}

	private var header: some View {
		VStack(alignment: .leading, spacing: 6) {
			GlyphTile(systemName: "checkmark.shield", size: 44)
			Text(t("trust.title"))
				.font(.system(size: 19, weight: .bold))
				.foregroundStyle(Color.inkPrimary)
			Text(t("trust.detail"))
				.font(.system(size: 13))
				.foregroundStyle(Color.inkSecondary)
				.fixedSize(horizontal: false, vertical: true)
		}
	}

	private func step(_ number: Int, _ text: String) -> some View {
		HStack(alignment: .top, spacing: 10) {
			Text("\(number)")
				.font(.system(size: 12, weight: .bold))
				.foregroundStyle(.white)
				.frame(width: 22, height: 22)
				.background(Circle().fill(LinearGradient.actionFlow))

			Text(text)
				.font(.system(size: 13))
				.foregroundStyle(Color.inkPrimary)
				.fixedSize(horizontal: false, vertical: true)

			Spacer(minLength: 0)
		}
	}

	private var actions: some View {
		VStack(spacing: 10) {
			Button {
				openAuthority()
			} label: {
				Text(t("trust.download"))
					.font(.system(size: 15, weight: .semibold))
					.foregroundStyle(.white)
					.frame(maxWidth: .infinity)
					.padding(.vertical, 12)
					.background(Capsule().fill(LinearGradient.actionFlow))
					.shadow(color: Color.brand.opacity(0.4), radius: 10, y: 4)
			}

			// Trusting happens in Settings, out of the app's sight; the only
			// honest thing is to let the user say when they are done.
			Button {
				installer.authorityInstalled = true
				onClose()
			} label: {
				Text(t("trust.done"))
					.font(.system(size: 14, weight: .medium))
					.foregroundStyle(Color.brand)
					.frame(maxWidth: .infinity)
					.padding(.vertical, 10)
					.background(Capsule().fill(Color.brandSoft))
			}

			Button(action: onClose) {
				Text(t("trust.later"))
					.font(.system(size: 13))
					.foregroundStyle(Color.inkSecondary)
			}
		}
	}

	private func openAuthority() {
		do {
			let file = try installer.authorityFile()
			ShareSheet.present(items: [file])
		} catch {
			failure = error.localizedDescription
		}
	}
}
