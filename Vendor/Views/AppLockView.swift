//
//  AppLockView.swift
//  Vendor
//
//  Opaque on purpose — every other panel in this app is a blur over content
//  still readable underneath, but this one exists specifically to make sure
//  nothing underneath is readable. No `Screen`, no `contentBlur`, just the
//  aurora and nothing else.
//

import SwiftUI

struct AppLockView: View {
	@ObservedObject private var lock = AppLock.shared
	/// Not read directly — its presence keeps this view subscribed to
	/// `Localizer.shared`, so every `t(...)` call below redraws when the
	/// language flips.
	@ObservedObject private var localizer = Localizer.shared
	@State private var authenticating = false

	var body: some View {
		VStack(spacing: 18) {
			Spacer()

			GlyphTile(systemName: "faceid", size: 64)

			VStack(spacing: 6) {
				Text(t("lock.title"))
					.font(.system(size: 20, weight: .bold))
					.foregroundStyle(Color.inkPrimary)
				Text(t("lock.detail"))
					.font(.system(size: 13))
					.foregroundStyle(Color.inkSecondary)
					.multilineTextAlignment(.center)
					.fixedSize(horizontal: false, vertical: true)
					.padding(.horizontal, 40)
			}

			Spacer()

			Button {
				attempt()
			} label: {
				HStack(spacing: 8) {
					if authenticating {
						ProgressView().tint(.white)
					} else {
						Image(systemName: "faceid")
					}
					Text(t("lock.unlock"))
				}
				.font(.system(size: 15, weight: .semibold))
				.foregroundStyle(.white)
				.frame(maxWidth: .infinity)
				.padding(.vertical, 14)
				.background(Capsule().fill(LinearGradient.brand))
			}
			.buttonStyle(.plain)
			.padding(.horizontal, 40)
			.padding(.bottom, 60)
			.disabled(authenticating)
		}
		.frame(maxWidth: .infinity, maxHeight: .infinity)
		.background(Color.canvas)
		.auroraBackground()
		// The one screen in the app that must not be dismissible by tapping
		// past it — no background tap-to-close, no swipe, nothing but a
		// successful authenticate() clears `isLocked`.
		.task { attempt() }
	}

	private func attempt() {
		guard !authenticating else { return }
		authenticating = true
		Task {
			await lock.authenticate()
			authenticating = false
		}
	}
}
