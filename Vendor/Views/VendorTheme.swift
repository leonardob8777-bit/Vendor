//
//  VendorTheme.swift
//  Vendor
//
//  Design system: palette, surfaces and reusable components.
//

import SwiftUI
import UIKit

// MARK: - Palette

private func adaptive(light: UInt32, dark: UInt32) -> Color {
	Color(uiColor: UIColor { traits in
		let hex = traits.userInterfaceStyle == .dark ? dark : light
		return UIColor(
			red:   CGFloat((hex >> 16) & 0xFF) / 255,
			green: CGFloat((hex >> 8)  & 0xFF) / 255,
			blue:  CGFloat( hex        & 0xFF) / 255,
			alpha: 1
		)
	})
}

extension Color {
	static let brand      = adaptive(light: 0x6C5CE7, dark: 0x8B7CF6)
	static let brandDeep  = adaptive(light: 0x5B4CE0, dark: 0x6C5CE7)
	static let brandSoft  = adaptive(light: 0xEDEAFD, dark: 0x272138)

	static let canvas     = adaptive(light: 0xF2F2F7, dark: 0x0D0D12)
	static let surface    = adaptive(light: 0xFFFFFF, dark: 0x1A1A22)
	static let hairline   = adaptive(light: 0xEDEDF2, dark: 0x2A2A34)

	static let inkPrimary   = adaptive(light: 0x1B1B2F, dark: 0xF5F5FA)
	static let inkSecondary = adaptive(light: 0x8A8A99, dark: 0x9A9AAA)

	static let ok      = adaptive(light: 0x16A34A, dark: 0x4ADE80)
	static let warn    = adaptive(light: 0xD97706, dark: 0xFBBF24)
	static let bad     = adaptive(light: 0xDC2626, dark: 0xF87171)
	/// Stronger red reserved for destructive surfaces (swipe-to-delete).
	static let destructive = adaptive(light: 0xE03131, dark: 0xD32F35)

	/// Telegram brand blue, for the channel button.
	static let telegram     = adaptive(light: 0x229ED9, dark: 0x2AABEE)
	static let telegramDeep = adaptive(light: 0x1B8FC7, dark: 0x1F96D6)

	/// Badge accents on the profile card.
	static let gold      = adaptive(light: 0xC9971A, dark: 0xE0A81C)
	static let goldDeep  = adaptive(light: 0xE8B62C, dark: 0xF5C93F)
	static let live      = adaptive(light: 0xD32F35, dark: 0xE03B41)
	static let liveDeep  = adaptive(light: 0xE85A4F, dark: 0xF2665C)

	/// Glow under the Install control, picked from the middle of its gradient.
	static let installGlow = adaptive(light: 0xB23AE0, dark: 0xC24BEE)

	/// Secondary accent used on the certificate import flow.
	static let mint      = adaptive(light: 0x2BB98A, dark: 0x4FD3A6)
	static let mintDeep  = adaptive(light: 0x35C4B0, dark: 0x53D8C4)
	static let mintSoft  = adaptive(light: 0xE4F7EF, dark: 0x123028)

	static let okSoft   = adaptive(light: 0xE7F8EE, dark: 0x14301F)
	static let warnSoft = adaptive(light: 0xFEF3E2, dark: 0x33240B)
	static let badSoft  = adaptive(light: 0xFDECEC, dark: 0x331616)
}

extension LinearGradient {
	static var brand: LinearGradient {
		LinearGradient(
			colors: [.brand, .brandDeep],
			startPoint: .topLeading,
			endPoint: .bottomTrailing
		)
	}

	/// First step of any app flow — fetching. Plain green.
	static var actionGet: LinearGradient {
		LinearGradient(
			colors: [.mint, .ok],
			startPoint: .topLeading,
			endPoint: .bottomTrailing
		)
	}

	/// Install — the last step, and the only one that puts the app on the phone.
	/// Deliberately nowhere near the green of Get: the two used to share a
	/// gradient and read as the same button pressed twice. Violet into magenta
	/// also stays clear of the mint→purple sweep that Sign uses.
	static var actionInstall: LinearGradient {
		LinearGradient(
			colors: [
				Color(red: 0.427, green: 0.290, blue: 1.000),
				Color(red: 0.651, green: 0.231, blue: 0.961),
				Color(red: 0.878, green: 0.224, blue: 0.608),
			],
			startPoint: .leading,
			endPoint: .trailing
		)
	}

	/// Every step after fetching — unpacking, signing, installing. Travels
	/// from the green of "got it" to the purple of the brand, so the sweep
	/// itself reads as progress through the pipeline.
	static var actionFlow: LinearGradient {
		LinearGradient(
			colors: [.mint, .brand, .brandDeep],
			startPoint: .leading,
			endPoint: .trailing
		)
	}
}

// MARK: - Surfaces

/// Frosted panel used by every card in the app.
///
/// This is a hand-rolled glass, not Apple's Liquid Glass: it stacks a system
/// blur material, a faint purple→green wash and a rim light. `.ultraThinMaterial`
/// has shipped since iOS 15, so this renders identically on phones that will
/// never see iOS 26.
private struct CardSurface: ViewModifier {
	@Environment(\.colorScheme) private var scheme

	var padding: CGFloat
	var radius: CGFloat = 18
	/// Optional status colour washed into the top-right corner.
	var glow: Color? = nil

	private var shape: RoundedRectangle {
		RoundedRectangle(cornerRadius: radius, style: .continuous)
	}

	/// Light mode runs dark text over the panel, so the tint is pulled back.
	private var strength: Double { scheme == .dark ? 1.0 : 0.62 }

	func body(content: Content) -> some View {
		content
			.padding(padding)
			.frame(maxWidth: .infinity, alignment: .leading)
			.background {
				ZStack {
					// 1. The blur itself — this is what makes it glass.
					shape.fill(.ultraThinMaterial)

					// 2. Barely-there brand wash so the panel is never grey.
					shape.fill(
						LinearGradient(
							colors: [
								Color.brand.opacity(0.11 * strength),
								Color.mint.opacity(0.06 * strength),
							],
							startPoint: .topLeading,
							endPoint: .bottomTrailing
						)
					)

					// 2b. Status bloom, when the card reports health.
					if let glow {
						shape.fill(
							RadialGradient(
								colors: [
									glow.opacity(0.42 * strength),
									glow.opacity(0.14 * strength),
									.clear,
								],
								center: .topTrailing,
								startRadius: 0,
								endRadius: 210
							)
						)
					}

					// 3. Rim light: bright along the top-left edge, brand-tinted
					//    along the bottom-right, so the panel reads as a solid
					//    pane catching light rather than a flat tint.
					shape.strokeBorder(
						LinearGradient(
							colors: [
								Color.white.opacity(scheme == .dark ? 0.22 : 0.85),
								Color.white.opacity(scheme == .dark ? 0.04 : 0.25),
								Color.mint.opacity(0.16 * strength),
							],
							startPoint: .topLeading,
							endPoint: .bottomTrailing
						),
						lineWidth: 1
					)
				}
			}
			.clipShape(shape)
			.modifier(Lift())
	}
}

/// Lifts a panel off the canvas.
///
/// Dark mode needs nothing clever: the glass is lighter than what sits behind
/// it, so its edge shows on its own. Light mode is the hard case — white glass
/// on a near-white canvas — where a single soft shadow reads as a smudge
/// instead of an edge. Two stacked casts fix it the way real light does: a wide
/// diffuse one for depth, plus a tight contact shadow right under the rim,
/// which is what the eye actually reads as a boundary. Both stay under 10%
/// black, so the card gains separation without looking heavy.
private struct Lift: ViewModifier {
	@Environment(\.colorScheme) private var scheme

	func body(content: Content) -> some View {
		if scheme == .dark {
			content.shadow(color: .black.opacity(0.30), radius: 12, x: 0, y: 4)
		} else {
			content
				.shadow(color: .black.opacity(0.09), radius: 16, x: 0, y: 6)
				.shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 1)
		}
	}
}

extension View {
	func card(padding: CGFloat = 16, radius: CGFloat = 18) -> some View {
		modifier(CardSurface(padding: padding, radius: radius))
	}

	/// A card that carries a status colour bleeding out of its top-right
	/// corner — green when healthy, red when not.
	func statusCard(padding: CGFloat = 16, radius: CGFloat = 18, glow: Color) -> some View {
		modifier(CardSurface(padding: padding, radius: radius, glow: glow))
	}

	/// Frosted circle, for the round toolbar buttons.
	func glassCircle(size: CGFloat) -> some View {
		frame(width: size, height: size)
			.background(.ultraThinMaterial, in: Circle())
			.overlay(Circle().strokeBorder(Color.white.opacity(0.16), lineWidth: 1))
			.shadow(color: .black.opacity(0.16), radius: 6, y: 2)
	}

}


// MARK: - Components

struct Badge: View {
	enum Tone { case brand, ok, warn, bad, neutral }

	let text: String
	var systemImage: String?
	var tone: Tone = .neutral

	private var fg: Color {
		switch tone {
		case .brand: return .brand
		case .ok:    return .ok
		case .warn:  return .warn
		case .bad:   return .bad
		case .neutral: return .inkSecondary
		}
	}

	private var bg: Color {
		switch tone {
		case .brand: return .brandSoft
		case .ok:    return .okSoft
		case .warn:  return .warnSoft
		case .bad:   return .badSoft
		case .neutral: return .hairline
		}
	}

	var body: some View {
		HStack(spacing: 4) {
			if let systemImage {
				Image(systemName: systemImage).font(.system(size: 10, weight: .bold))
			}
			Text(text).font(.system(size: 12, weight: .semibold))
		}
		.foregroundStyle(fg)
		.padding(.horizontal, 9)
		.padding(.vertical, 4)
		.background(bg)
		.clipShape(Capsule())
	}
}

/// Background for the Install control.
///
/// Install is the only action that actually puts the app on the phone, so it is
/// the one button in the app allowed to show off: its own violet→magenta
/// gradient, a coloured glow underneath, and a highlight that sweeps across
/// every few seconds the way light crosses a polished surface. The sweep is
/// what makes the eye come back to it — but it travels far wider than the pill,
/// so it is off-screen for most of the cycle rather than blinking non-stop.
struct InstallBackground: View {
	@Environment(\.accessibilityReduceMotion) private var reduceMotion
	@State private var swept = false

	var body: some View {
		Capsule()
			.fill(LinearGradient.actionInstall)
			.overlay {
				if !reduceMotion {
					GeometryReader { geo in
						LinearGradient(
							colors: [.clear, .white.opacity(0.55), .clear],
							startPoint: .leading,
							endPoint: .trailing
						)
						// Tall enough that the tilt still covers the pill top
						// to bottom, and blurred so it reads as a shine rather
						// than a stripe.
						.frame(width: geo.size.width * 0.34, height: geo.size.height * 2.4)
						.blur(radius: 3)
						.rotationEffect(.degrees(20))
						.offset(
							x: swept ? geo.size.width * 1.25 : -geo.size.width * 0.6,
							y: -geo.size.height * 0.7
						)
					}
					.allowsHitTesting(false)
				}
			}
			.clipShape(Capsule())
			.onAppear {
				guard !reduceMotion else { return }
				// A frame late, so SwiftUI has a settled value to animate from.
				DispatchQueue.main.async {
					withAnimation(.linear(duration: 2.6).repeatForever(autoreverses: false)) {
						swept = true
					}
				}
			}
	}
}

struct SectionLabel: View {
	let text: String
	var body: some View {
		Text(text)
			.font(.system(size: 13, weight: .semibold))
			.foregroundStyle(Color.inkSecondary)
			.frame(maxWidth: .infinity, alignment: .leading)
	}
}
