//
//  Indicators.swift
//  Vendor
//
//  Small animated status marks shared across screens.
//

import SwiftUI

/// Dot that switches on and off, like a recording light.
struct BlinkingDot: View {
	var color: Color = .white
	var size: CGFloat = 9

	@Environment(\.accessibilityReduceMotion) private var reduceMotion
	@State private var lit = false

	var body: some View {
		Circle()
			.fill(color)
			.frame(width: size, height: size)
			.shadow(color: color.opacity(lit ? 0.95 : 0), radius: 5)
			.opacity(lit ? 1 : 0.22)
			.onAppear {
				guard !reduceMotion else { lit = true; return }
				// Put it out before lighting it again. Leaving the screen and
				// coming back runs this a second time with `lit` still true from
				// the first, and animating a value to the value it already holds
				// starts nothing — the dot sat solid from then on.
				lit = false
				DispatchQueue.main.async {
					withAnimation(.easeInOut(duration: 0.75).repeatForever(autoreverses: true)) {
						lit = true
					}
				}
			}
	}
}

/// Amber callout for something that went wrong but did not stop the screen.
///
/// Lived inside `IPAView`. Adding a second caller meant either copying it or
/// giving it a home; the copy is how two versions of the same thing start.
struct CalloutRow: View {
	let text: String

	var body: some View {
		HStack(alignment: .top, spacing: 10) {
			Image(systemName: "exclamationmark.triangle")
				.font(.system(size: 14, weight: .semibold))
				.foregroundStyle(Color.warn)
			Text(text)
				.font(.system(size: 12))
				.foregroundStyle(Color.inkPrimary)
				.fixedSize(horizontal: false, vertical: true)
			Spacer(minLength: 0)
		}
		.padding(12)
		.background(Color.warnSoft)
		.clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
	}
}
