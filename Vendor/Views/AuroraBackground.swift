//
//  AuroraBackground.swift
//  Vendor
//
//  Slow drifting glow used behind every screen. It reads the current colour
//  scheme and re-tunes itself: vivid over a near-black base in dark mode,
//  a pale wash over the light canvas otherwise, so text contrast is kept.
//
//  The colour is a mesh, not a pile of circles. An earlier version stacked four
//  radial gradients, and no matter how soft each one was they still read as
//  four separate discs: a radial gradient's alpha ramp ends with a corner in
//  it, and the eye finds that edge every time. A MeshGradient interpolates
//  between control points across the whole surface instead, so the greens and
//  violets bleed into one another and there is no circle to find.
//
//  Drifting it is a matter of walking the control points, which is one shader
//  pass per frame rather than a Gaussian blur over the full screen.
//

import SwiftUI

struct AuroraBackground: View {
	@Environment(\.colorScheme) private var scheme
	@Environment(\.accessibilityReduceMotion) private var reduceMotion

	/// Light mode only hints at the glow so the dark text on cards keeps its
	/// contrast. Dark mode needs no holding back — its mesh is authored dark,
	/// with the shade baked into the colours rather than dialled in here.
	private var glowOpacity: Double { scheme == .dark ? 0.95 : 0.34 }

	var body: some View {
		ZStack {
			Color.canvas

			Group {
				if #available(iOS 18, *) {
					AuroraMesh(animated: !reduceMotion, scheme: scheme)
				} else {
					AuroraBlobs(animated: !reduceMotion)
				}
			}
			.opacity(glowOpacity)
		}
		.ignoresSafeArea()
	}
}

// MARK: - Mesh

/// The aurora as a 3×3 colour mesh whose inner control points drift.
///
/// The corners are pinned: pulling them inwards would let the canvas show
/// through at the edges of the screen. Everything else wanders on its own
/// period, so the field never repeats a pose you have already seen.
@available(iOS 18, *)
private struct AuroraMesh: View {
	let animated: Bool
	let scheme: ColorScheme

	/// Slow enough that the movement is felt rather than watched, so a low
	/// frame rate is invisible and costs a fraction of a redraw at 60.
	private static let frameInterval = 1.0 / 20.0

	var body: some View {
		TimelineView(.animation(minimumInterval: Self.frameInterval, paused: !animated)) { timeline in
			let t = animated ? timeline.date.timeIntervalSinceReferenceDate : 0
			MeshGradient(
				width: 3,
				height: 3,
				points: Self.points(at: t),
				colors: scheme == .dark ? Self.darkColors : Self.lightColors
			)
		}
	}

	/// Control points at time `t`. Edge midpoints slide along their own edge
	/// only; the centre is free to roam.
	private static func points(at t: TimeInterval) -> [SIMD2<Float>] {
		func drift(_ period: Double, _ phase: Double, _ amount: Float) -> Float {
			amount * Float(sin(t / period + phase))
		}

		return [
			SIMD2(0, 0),
			SIMD2(0.5 + drift(17, 0.0, 0.16), 0),
			SIMD2(1, 0),

			SIMD2(0, 0.5 + drift(21, 1.1, 0.17)),
			SIMD2(0.5 + drift(13, 2.4, 0.20), 0.5 + drift(19, 0.6, 0.18)),
			SIMD2(1, 0.5 + drift(24, 3.2, 0.17)),

			SIMD2(0, 1),
			SIMD2(0.5 + drift(15, 4.0, 0.16), 1),
			SIMD2(1, 1),
		]
	}

	/// Green in the top-left, violet in the bottom-right, blue carrying the
	/// journey between them — the same sweep the app's gradients use.
	///
	/// Every colour here is already dark, and the near-blacks are control
	/// points of their own rather than a dimming pass over the whole thing.
	/// That is what keeps the depth the old blobs had — glow against shadow —
	/// now that the mesh covers the screen edge to edge instead of leaving the
	/// canvas bare between four discs.
	private static let darkColors: [Color] = [
		Color(red: 0.055, green: 0.357, blue: 0.243),
		Color(red: 0.027, green: 0.102, blue: 0.125),
		Color(red: 0.059, green: 0.180, blue: 0.420),

		Color(red: 0.031, green: 0.075, blue: 0.102),
		Color(red: 0.118, green: 0.141, blue: 0.439),
		Color(red: 0.208, green: 0.125, blue: 0.549),

		Color(red: 0.078, green: 0.125, blue: 0.369),
		Color(red: 0.043, green: 0.039, blue: 0.110),
		Color(red: 0.290, green: 0.118, blue: 0.588),
	]

	/// Same hues, pulled towards white: over the light canvas these sit under
	/// dark text, so they have to stay a wash.
	private static let lightColors: [Color] = [
		Color(red: 0.44, green: 0.92, blue: 0.76),
		Color(red: 0.47, green: 0.83, blue: 0.92),
		Color(red: 0.53, green: 0.72, blue: 0.97),

		Color(red: 0.45, green: 0.87, blue: 0.85),
		Color(red: 0.60, green: 0.63, blue: 0.95),
		Color(red: 0.69, green: 0.58, blue: 0.96),

		Color(red: 0.52, green: 0.70, blue: 0.96),
		Color(red: 0.72, green: 0.57, blue: 0.96),
		Color(red: 0.80, green: 0.62, blue: 0.97),
	]
}

// MARK: - Fallback

/// Pre-iOS 18 path: drifting blobs, kept because MeshGradient does not exist
/// there. They are drawn wide enough to overlap heavily and with a falloff that
/// eases out instead of ending on a straight ramp, which is what stopped them
/// reading as separate discs.
private struct AuroraBlobs: View {
	let animated: Bool

	private struct Spec {
		let color: Color
		let from: UnitPoint
		let to: UnitPoint
		let size: CGFloat     // fraction of the smaller screen edge
		let period: Double
	}

	private let specs: [Spec] = [
		.init(color: Color(red: 0.16, green: 0.85, blue: 0.55),
			  from: .init(x: 0.05, y: 0.28), to: .init(x: 0.36, y: 0.54), size: 1.70, period: 19),
		.init(color: Color(red: 0.20, green: 0.72, blue: 0.98),
			  from: .init(x: 0.44, y: 0.16), to: .init(x: 0.12, y: 0.44), size: 1.85, period: 24),
		.init(color: Color(red: 0.36, green: 0.44, blue: 0.98),
			  from: .init(x: 0.80, y: 0.48), to: .init(x: 0.96, y: 0.26), size: 1.65, period: 27),
		.init(color: Color(red: 0.58, green: 0.32, blue: 0.98),
			  from: .init(x: 0.88, y: 0.70), to: .init(x: 0.56, y: 0.88), size: 1.60, period: 22),
	]

	var body: some View {
		GeometryReader { geo in
			let unit = min(geo.size.width, geo.size.height)
			ZStack {
				ForEach(Array(specs.enumerated()), id: \.offset) { _, spec in
					AuroraBlob(
						color: spec.color,
						from: CGPoint(x: geo.size.width * spec.from.x, y: geo.size.height * spec.from.y),
						to:   CGPoint(x: geo.size.width * spec.to.x,   y: geo.size.height * spec.to.y),
						diameter: unit * spec.size,
						period: spec.period,
						animated: animated
					)
				}
			}
			.compositingGroup()
			.blur(radius: 60)
			.clipped()
		}
	}
}

/// A single glowing blob that drifts between two points forever.
private struct AuroraBlob: View {
	let color: Color
	let from: CGPoint
	let to: CGPoint
	let diameter: CGFloat
	let period: Double
	let animated: Bool

	@State private var moved = false

	var body: some View {
		Circle()
			.fill(
				RadialGradient(
					// An eased falloff rather than a straight line to zero: the
					// linear ramp put a visible crease where the blob ended.
					stops: [
						.init(color: color, location: 0),
						.init(color: color.opacity(0.72), location: 0.32),
						.init(color: color.opacity(0.36), location: 0.56),
						.init(color: color.opacity(0.12), location: 0.78),
						.init(color: color.opacity(0), location: 1),
					],
					center: .center,
					startRadius: 0,
					endRadius: diameter * 0.5
				)
			)
			.frame(width: diameter, height: diameter)
			.scaleEffect(moved ? 1.10 : 0.94)
			.position(moved ? to : from)
			.blendMode(.plusLighter)
			.onAppear {
				guard animated else { return }
				// Kicked off a frame late so SwiftUI has a settled starting
				// value to animate away from; otherwise the repeat never runs.
				DispatchQueue.main.async {
					withAnimation(
						.easeInOut(duration: period).repeatForever(autoreverses: true)
					) {
						moved = true
					}
				}
			}
	}
}

extension View {
	/// Places the drifting aurora behind this view.
	func auroraBackground() -> some View {
		background(AuroraBackground())
	}
}
