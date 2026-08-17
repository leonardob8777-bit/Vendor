//
//  InstallRing.swift
//  Vendor
//
//  App icon wrapped in a progress ring. The ring's colour travels the same
//  road the app's own gradients do — the mint of "got it" through the brand
//  purple of the work into the magenta of Install — so the colour alone says
//  how far along the job is. Behind both the icon and the ring sits a soft halo
//  tinted the same way, echoing the mark on the Profile screen.
//
//  It used to run red → orange → green. That put a healthy job at 8% behind a
//  red ring, which in an app where red means `.bad` everywhere else reads as
//  failure — and it left `failed` with no colour of its own to fail in. Red is
//  now only ever a failure, and the sweep says progress instead of health.
//

import SwiftUI

struct InstallRing: View {
	/// 0…1.
	let progress: Double
	let iconURL: URL?
	var diameter: CGFloat = 168
	var failed: Bool = false

	@Environment(\.accessibilityReduceMotion) private var reduceMotion
	/// Not read directly — its presence keeps this view subscribed to
	/// `Localizer.shared`, so every `t(...)` call below redraws when the
	/// language flips.
	@ObservedObject private var localizer = Localizer.shared
	@State private var breathing = false
	/// Drives the one-shot bloom when the ring closes.
	@State private var landed = false

	private var thickness: CGFloat { diameter * 0.055 }

	// Fixed literals rather than the adaptive palette on purpose: blending
	// needs real components, and `UIColor(dynamicColour).cgColor` resolves
	// against whatever trait collection happens to be current when it is read,
	// which inside a computed property is not reliably the view's own. These
	// are the stops of `LinearGradient.actionFlow` and `.actionInstall`.
	private static let start  = Color(red: 0.169, green: 0.725, blue: 0.541)
	private static let middle = Color(red: 0.427, green: 0.290, blue: 1.000)
	private static let end    = Color(red: 0.878, green: 0.224, blue: 0.608)

	/// Position on the mint → violet → magenta scale, weighted so the purple
	/// arrives early and holds through the long middle of a signing run.
	private static func scale(_ t: Double) -> Color {
		let t = min(max(t, 0), 1)
		if t < 0.28 {
			return blend(start, middle, t / 0.28)
		}
		return blend(middle, end, min((t - 0.28) / 0.62, 1))
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
	/// as the ring closes — so at 100% both ends have arrived and the join is
	/// invisible instead of a mint-against-magenta stripe.
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
			bloom
			arc
			icon
		}
		.frame(width: diameter * 1.5, height: diameter * 1.5)
		// One element, not four unlabelled shapes. VoiceOver read the icon's
		// image and nothing else, so the one number the panel exists to report
		// was the one thing it could not say.
		.accessibilityElement(children: .ignore)
		.accessibilityLabel(t("ipa.ringProgress"))
		.accessibilityValue(failed ? t("ipa.ringStopped") : "\(Int(min(max(progress, 0), 1) * 100))%")
		.onAppear {
			guard !reduceMotion else { return }
			DispatchQueue.main.async {
				withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true)) {
					breathing = true
				}
			}
		}
		.onChange(of: progress) { now in
			// The moment the ring closes is the moment the job landed, and it
			// went by with the arc simply stopping. One ring thrown outwards is
			// enough to mark it — and it is a one-shot, so reduce-motion is the
			// only reason to skip it.
			guard !reduceMotion, !failed, now >= 0.999, !landed else { return }
			landed = true
			withAnimation(.easeOut(duration: 0.85)) { }
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

	/// The ring thrown off when the job lands. Drawn under the arc so it looks
	/// like something the arc gave off rather than something laid over it.
	private var bloom: some View {
		Circle()
			.stroke(tone.opacity(0.9), lineWidth: thickness * 0.7)
			.frame(width: diameter, height: diameter)
			.scaleEffect(landed ? 1.35 : 1)
			.opacity(landed ? 0 : 0.9)
			.animation(.easeOut(duration: 0.85), value: landed)
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
