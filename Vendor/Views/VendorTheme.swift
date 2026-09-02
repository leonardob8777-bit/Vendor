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
	/// A certificate's two-tone light. Takes over from `glow` when present and
	/// lights the rim as well as the corner.
	var aura: CertificateAura? = nil

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
					if let aura {
						// Two radials rather than one: a wide fall-off in the
						// deep tone for the body of the light, and a tight lit
						// core in the corner it appears to come from. A single
						// gradient either reaches far and looks like a stain or
						// stays bright and looks like a sticker.
						shape.fill(
							RadialGradient(
								colors: [
									aura.deep.opacity(0.44 * strength),
									aura.deep.opacity(0.16 * strength),
									.clear,
								],
								center: .topTrailing,
								startRadius: 0,
								endRadius: 250
							)
						)
						shape.fill(
							RadialGradient(
								colors: [
									aura.bright.opacity(0.62 * strength),
									aura.bright.opacity(0.18 * strength),
									.clear,
								],
								center: .topTrailing,
								startRadius: 0,
								endRadius: 105
							)
						)
					} else if let glow {
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
					//
					// A card with an aura gets no hard rim at all. A drawn
					// outline is a line, and a line with a highlight running
					// along it reads as a line breaking and rejoining rather
					// than as something lit — which is exactly how it looked.
					// The glow below is left to describe the edge on its own.
					if aura == nil {
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
			}
			.clipShape(shape)
			// 4. The light around the panel, and the only thing describing its
			//    edge. Drawn after the clip on purpose: inside it, the blur
			//    would be cut off at the very edge it is meant to spill past,
			//    and the card would keep the hard outline this replaces.
			.overlay {
				if let aura {
					RimShine(aura: aura, shape: shape, strength: strength, lineWidth: 4)
						.blur(radius: 8)
						.allowsHitTesting(false)
				}
			}
			.modifier(Lift())
			.modifier(AuraCast(aura: aura, strength: strength))
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

/// The rim of a certificate card, with a glint travelling round it.
///
/// The colour says how much life is left; the movement is what makes it read as
/// a lit object rather than a coloured outline. One highlight, going round once
/// every eight seconds — slow enough to catch out of the corner of the eye and
/// never fast enough to ask to be watched.
///
/// The gradient is rotated as a view and then masked to the rim, rather than an
/// `AngularGradient` given an animated angle. A gradient is a `ShapeStyle`, and
/// SwiftUI does not interpolate between two of them — the angle would jump on
/// each change instead of sweeping. `rotationEffect` is a geometry effect and
/// animates properly. It also leaves the layout frame alone, so the mask stays
/// put over the card's edge while the light turns underneath it.
private struct RimShine: View {
	@Environment(\.accessibilityReduceMotion) private var reduceMotion

	let aura: CertificateAura
	let shape: RoundedRectangle
	let strength: Double
	let lineWidth: CGFloat

	@State private var phase: Double = 0

	private var sweep: AngularGradient {
		AngularGradient(
			// Flat either side of the seam, and the glint parked in the middle,
			// as far from it as it can get.
			//
			// An angular gradient joins its last stop straight onto its first,
			// and matching the two colours is not enough: a gradient that falls
			// to its darkest exactly at the join has a V there, so the rim dims
			// to a notch at one point and brightens away from it on both sides.
			// Travelling round, that notch reads as the outline coming unstuck
			// and sticking back down. Holding one value across the whole join
			// leaves nothing to see.
			stops: [
				.init(color: aura.deep.opacity(0.85 * strength),   location: 0.00),
				.init(color: aura.deep.opacity(0.85 * strength),   location: 0.28),
				.init(color: aura.bright.opacity(1.00 * strength), location: 0.42),
				.init(color: aura.glint.opacity(0.95 * strength),  location: 0.50),
				.init(color: aura.bright.opacity(1.00 * strength), location: 0.58),
				.init(color: aura.deep.opacity(0.85 * strength),   location: 0.72),
				.init(color: aura.deep.opacity(0.85 * strength),   location: 1.00),
			],
			center: .center
		)
	}

	var body: some View {
		sweep
			.rotationEffect(.degrees(phase))
			// A rotated rectangle no longer covers the one it started as, so its
			// corners would fall outside the gradient and the rim would go
			// transparent there. Angles are unchanged by a uniform scale, so
			// oversizing costs nothing but guarantees cover at every rotation.
			.scaleEffect(2.6)
			.mask(shape.strokeBorder(lineWidth: lineWidth))
			.onAppear {
				guard !reduceMotion else { return }
				withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
					phase = 360
				}
			}
	}
}

/// Throws the aura's colour onto the canvas around the card.
///
/// Its own modifier rather than a `.shadow` with a clear colour when there is no
/// aura: a clear shadow still costs an offscreen pass on every card in the app,
/// and only one card in the app has an aura.
private struct AuraCast: ViewModifier {
	let aura: CertificateAura?
	let strength: Double

	func body(content: Content) -> some View {
		if let aura {
			content.shadow(color: aura.deep.opacity(0.42 * strength), radius: 18, y: 4)
		} else {
			content
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

	/// A certificate's card: lit corner, lit rim, and a cast onto the canvas,
	/// all in the colour its remaining life has reached.
	func statusCard(padding: CGFloat = 16, radius: CGFloat = 18, aura: CertificateAura) -> some View {
		modifier(CardSurface(padding: padding, radius: radius, aura: aura))
	}

	/// Frosted circle, for the round toolbar buttons.
	func glassCircle(size: CGFloat) -> some View {
		frame(width: size, height: size)
			.background(.ultraThinMaterial, in: Circle())
			.overlay(Circle().strokeBorder(Color.white.opacity(0.16), lineWidth: 1))
			.shadow(color: .black.opacity(0.16), radius: 6, y: 2)
	}

	/// Frosted background for a floating panel — the app's own alternative to
	/// a system sheet, used by every full-screen detail/settings/picker
	/// overlay. The same nine-file, twenty-line background block this used to
	/// be copy-pasted into, kept here once instead. Not folded into
	/// `CardSurface` above: a card inside a list and the one panel that floats
	/// over a whole screen never wanted the same corner radius or the same
	/// shadow, so this stays its own modifier rather than another `CardSurface`
	/// call.
	func sheetPanelBackground(
		radius: CGFloat = 28,
		tone: SheetPanelTone = .standard,
		brandShadow: Bool = true
	) -> some View {
		modifier(SheetPanelBackground(radius: radius, tone: tone, brandShadow: brandShadow))
	}

}

/// The two washes `sheetPanelBackground` actually ships today — every panel
/// but `GuideDetailSheet` uses `.standard`; that one alone runs `.warm`,
/// fractionally brighter in its wash, rim and shadow. Kept apart rather than
/// quietly folded into one, so consolidating the nine copies of this
/// background did not also silently reach in and re-tune how one of them
/// looks.
enum SheetPanelTone {
	case standard, warm
}

private struct SheetPanelBackground: ViewModifier {
	var radius: CGFloat
	var tone: SheetPanelTone
	/// Off for `LicenseSheet`, the one panel light enough that a second,
	/// coloured cast under the first reads as more shadow than its content
	/// calls for.
	var brandShadow: Bool

	private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: radius, style: .continuous) }

	private var wash: (top: Double, bottom: Double) {
		tone == .warm ? (0.14, 0.08) : (0.13, 0.07)
	}
	private var rim: (top: Double, mid: Double, bottom: Double) {
		tone == .warm ? (0.30, 0.06, 0.20) : (0.28, 0.05, 0.18)
	}
	private var lift: (radius: CGFloat, y: CGFloat) {
		tone == .warm ? (28, 14) : (30, 16)
	}
	private var brandLift: (opacity: Double, radius: CGFloat, y: CGFloat) {
		tone == .warm ? (0.22, 34, 18) : (0.20, 36, 20)
	}

	func body(content: Content) -> some View {
		content
			.background {
				ZStack {
					shape.fill(.ultraThinMaterial)
					shape.fill(
						LinearGradient(
							colors: [Color.brand.opacity(wash.top), Color.mint.opacity(wash.bottom)],
							startPoint: .topLeading, endPoint: .bottomTrailing
						)
					)
					shape.strokeBorder(
						LinearGradient(
							colors: [
								.white.opacity(rim.top),
								.white.opacity(rim.mid),
								Color.mint.opacity(rim.bottom),
							],
							startPoint: .topLeading, endPoint: .bottomTrailing
						),
						lineWidth: 1
					)
				}
			}
			.clipShape(shape)
			.shadow(color: .black.opacity(0.45), radius: lift.radius, y: lift.y)
			.modifier(OptionalBrandShadow(brandShadow: brandShadow ? brandLift : nil))
	}
}

/// A clear shadow still costs an offscreen pass, so this skips drawing one
/// entirely rather than passing an opacity of zero through, the same
/// reasoning `AuraCast` above already applies to a card's status cast.
private struct OptionalBrandShadow: ViewModifier {
	let brandShadow: (opacity: Double, radius: CGFloat, y: CGFloat)?

	func body(content: Content) -> some View {
		if let brandShadow {
			content.shadow(color: Color.brand.opacity(brandShadow.opacity), radius: brandShadow.radius, y: brandShadow.y)
		} else {
			content
		}
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
