//
//  InstallRing.swift
//  Vendor
//
//  App icon wrapped in a progress ring. The ring's colour sweeps red →
//  orange → green as it fills, so the colour alone says how far along the
//  install is. Behind both the icon and the ring sits a soft halo tinted the
//  same way, echoing the mark on the Profile screen.
//

import SwiftUI

struct InstallRing: View {
	/// 0…1.
	let progress: Double
	let iconURL: URL?
	var diameter: CGFloat = 168
	var failed: Bool = false

	@Environment(\.accessibilityReduceMotion) private var reduceMotion
	@State private var breathing = false

	private var thickness: CGFloat { diameter * 0.055 }

	private static let red    = Color(red: 0.94, green: 0.27, blue: 0.27)
	private static let orange = Color(red: 0.98, green: 0.58, blue: 0.13)
	private static let green  = Color(red: 0.18, green: 0.83, blue: 0.45)

	/// Position on the red → orange → green scale, weighted so green takes
	/// over early and holds for most of the run.
	private static func scale(_ t: Double) -> Color {
		let t = min(max(t, 0), 1)
		if t < 0.22 {
			return blend(red, orange, t / 0.22)
		}
		return blend(orange, green, min((t - 0.22) / 0.28, 1))
	}

	private static func blend(_ a: Color, _ b: Color, _ amount: Double) -> Color {
		let k = min(max(amount, 0), 1)
		let ca = UIColor(a).cgColor.components ?? [0, 0, 0, 1]
		let cb = UIColor(b).cgColor.components ?? [0, 0, 0, 1]
		return Color(
			red:   Double(ca[0]) + (Double(cb[0]) - Double(ca[0])) * k,
			green: Double(ca[1]) + (Double(cb[1]) - Double(ca[1])) * k,
			blue:  Double(ca[2]) + (Double(cb[2]) - Double(ca[2])) * k
		)
	}

	/// Colour at the leading edge of the arc.
	private var headColour: Color { failed ? .bad : Self.scale(progress) }
	/// Colour where the arc began. It trails behind the head, and catches up
	/// as the ring closes — so at 100% both ends are green and the join is
	/// invisible instead of a red-against-green stripe.
	private var tailColour: Color { failed ? .bad : Self.scale(progress - 0.30) }

	/// Solid colour used by the halo and glow.
	private var tone: Color { headColour }

	/// The gradient spans only the drawn portion, so the round cap at the
	/// start can never pick up a colour from the far end of the circle.
	private var sweep: AngularGradient {
		AngularGradient(
			colors: [tailColour, headColour],
			center: .center,
			startAngle: .degrees(0),
			endAngle: .degrees(360 * max(progress, 0.02))
		)
	}

	var body: some View {
		ZStack {
			halo
			track
			arc
			icon
		}
		.frame(width: diameter * 1.5, height: diameter * 1.5)
		.onAppear {
			guard !reduceMotion else { return }
			DispatchQueue.main.async {
				withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true)) {
					breathing = true
				}
			}
		}
	}

	// MARK: Layers

	/// Diffused light behind everything, taking the ring's current colour.
	private var halo: some View {
		Circle()
			.fill(
				RadialGradient(
					colors: [tone.opacity(0.55), tone.opacity(0.12), .clear],
					center: .center,
					startRadius: 0,
					endRadius: diameter * 0.82
				)
			)
			.frame(width: diameter * 1.5, height: diameter * 1.5)
			.blur(radius: 14)
			.scaleEffect(breathing ? 1.06 : 0.92)
			.animation(.easeInOut(duration: 0.6), value: tone)
	}

	private var track: some View {
		Circle()
			.stroke(Color.inkSecondary.opacity(0.18), lineWidth: thickness)
			.frame(width: diameter, height: diameter)
	}

	private var arc: some View {
		Circle()
			.trim(from: 0, to: max(progress, 0.001))
			.stroke(sweep, style: StrokeStyle(lineWidth: thickness, lineCap: .round))
			.rotationEffect(.degrees(-90))
			.frame(width: diameter, height: diameter)
			.shadow(color: tone.opacity(0.75), radius: 10)
			.animation(.easeInOut(duration: 0.35), value: progress)
	}

	private var icon: some View {
		CachedImage(url: iconURL) {
			ZStack {
				Rectangle().fill(.ultraThinMaterial)
				Image(systemName: "app.dashed")
					.font(.system(size: diameter * 0.22, weight: .light))
					.foregroundStyle(tone)
			}
		}
		.frame(width: diameter * 0.62, height: diameter * 0.62)
		.clipShape(RoundedRectangle(cornerRadius: diameter * 0.155, style: .continuous))
		.shadow(color: .black.opacity(0.35), radius: 12, y: 5)
	}
}
