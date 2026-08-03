//
//  CertificateAura.swift
//  Vendor
//
//  The light a certificate gives off.
//
//  The ring used to draw an arc of its remaining life, which sounds useful and
//  is not: a year-long certificate sits at nine tenths full for ten months, so
//  the arc says the same thing every day until the week it matters. The number
//  in the middle already carries the fact. So the ring stops reporting and
//  starts lighting — and the colour is what carries the time.
//
//  Keyed to the share of its own life a certificate has left, continuously, so
//  the colour drifts a little every day rather than jumping the morning a day
//  count crosses a threshold. Nothing here reads a day count or a date.
//

import SwiftUI

/// A pair of tones — one lit, one deep — blended wherever a certificate's
/// health is shown.
struct CertificateAura {
	/// The lit tone. Sits in the corner of the card and in the ring's highlight.
	let bright: Color
	/// The darker companion the bright tone falls away into.
	let deep: Color
	/// The palest of the three, for the travelling highlight on the rim.
	///
	/// Not white, which is what a specular highlight would really be. A white
	/// segment moving along a green outline does not read as light crossing the
	/// line — it reads as the line being cut and rejoining behind it. Keeping the
	/// hue and dropping almost all the saturation leaves the outline one
	/// unbroken colour that simply swells where the light is.
	let glint: Color

	/// Green, through gold, to red.
	///
	/// Hue travels rather than the app picking one of three fixed colours, which
	/// is what makes the change read as time passing. The waypoint at gold is
	/// deliberate: a straight run from green to red passes through a sickly
	/// yellow-green at the halfway mark, and the midpoint is exactly where the
	/// certificate should look like it is on the turn.
	init(life: Double) {
		let l = min(max(life, 0), 1)
		let hue = l >= 0.5
			? 0.12 + (l - 0.5) * 2 * (0.34 - 0.12)   // gold → green
			: l * 2 * 0.12                            // red  → gold

		// The same hue twice, once pale and once saturated: at the green end
		// that is light green over green, which is the pairing being after.
		bright = Color(hue: hue, saturation: 0.52, brightness: 1.00)
		deep   = Color(hue: max(hue - 0.03, 0), saturation: 0.94, brightness: 0.68)
		glint  = Color(hue: hue, saturation: 0.20, brightness: 1.00)
	}

	private init(bright: Color, deep: Color, glint: Color) {
		self.bright = bright
		self.deep = deep
		self.glint = glint
	}

	/// Revoked, or past its date.
	///
	/// Not the tail of the living scale — that ends at a plain red, and a dead
	/// certificate should not look like one that merely ran late. Wine under the
	/// red gives it weight.
	static let dead = CertificateAura(
		bright: Color(hue: 0.995, saturation: 0.80, brightness: 0.98),
		deep:   Color(hue: 0.962, saturation: 0.96, brightness: 0.36),
		glint:  Color(hue: 0.995, saturation: 0.28, brightness: 1.00)
	)

	/// The two tones swept round a circle. One pass, not a repeat: alternating
	/// them twice turns a ring into a barber's pole.
	var sweep: AngularGradient {
		AngularGradient(colors: [bright, deep, bright], center: .center)
	}
}

extension CertificateAura {
	init(health: StoredCertificate.Health, lifetimeDays: Int) {
		switch health {
		case .valid(let days), .expiring(let days):
			self.init(life: Double(days) / Double(max(lifetimeDays, 1)))
		case .expired, .rejected:
			self = .dead
		}
	}

	init(_ certificate: StoredCertificate) {
		self.init(health: certificate.health(), lifetimeDays: certificate.lifetimeDays)
	}
}
