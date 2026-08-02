//
//  SiteBadge.swift
//  Vendor
//
//  Port of the status chip used on the Vendor website. Colours, the pulsing
//  dot, the uppercase letter-spaced label and the hairline border all follow
//  that site's `.badge` rules so the two surfaces look like one product.
//

import SwiftUI

struct SiteBadge: View {
	enum Kind {
		case hot, ultra, live, new, popular, verified, epic

		/// Values lifted straight from the site's stylesheet.
		var ink: Color {
			switch self {
			case .hot:      return Color(red: 1.00, green: 0.70, blue: 0.36) // #ffb35c
			case .ultra:    return Color(red: 0.94, green: 0.89, blue: 1.00) // #f0e2ff
			case .live:     return Color(red: 1.00, green: 0.30, blue: 0.30) // #ff4d4d
			case .new:      return Color(red: 0.37, green: 0.92, blue: 0.83) // #5eead4
			case .popular:  return Color(red: 0.94, green: 0.67, blue: 0.99) // #f0abfc
			case .verified: return Color(red: 0.49, green: 0.83, blue: 0.99) // #7dd3fc
			case .epic:     return Color(red: 1.00, green: 0.88, blue: 0.55) // pale gold
			}
		}

		/// The raw hue the fill and border are derived from.
		var base: Color {
			switch self {
			case .hot:      return Color(red: 1.00, green: 0.57, blue: 0.16) // rgb(255,145,40)
			case .ultra:    return Color(red: 0.66, green: 0.33, blue: 0.97)
			case .live:     return Color(red: 1.00, green: 0.30, blue: 0.30)
			case .new:      return Color(red: 0.18, green: 0.83, blue: 0.75)
			case .popular:  return Color(red: 0.91, green: 0.47, blue: 0.98)
			case .verified: return Color(red: 0.22, green: 0.74, blue: 0.97)
			case .epic:     return Color(red: 0.85, green: 0.65, blue: 0.13) // deep gold
			}
		}
	}

	let text: String
	let kind: Kind

	@Environment(\.accessibilityReduceMotion) private var reduceMotion
	@State private var pulsing = false

	var body: some View {
		HStack(spacing: 5) {
			Circle()
				.fill(kind.ink)
				.frame(width: 5, height: 5)
				.shadow(color: kind.base.opacity(0.9), radius: 4)
				.scaleEffect(pulsing ? 1.35 : 0.85)
				.opacity(pulsing ? 1 : 0.6)

			Text(text.uppercased())
				.font(.system(size: 10, weight: .semibold))
				.kerning(0.6)
				.foregroundStyle(kind.ink)
				// A chip is a label, never a paragraph: without this a long
				// name wraps mid-word when the row runs short of space.
				.lineLimit(1)
				.fixedSize(horizontal: true, vertical: false)
		}
		.padding(.leading, 6)
		.padding(.trailing, 8)
		.padding(.vertical, 3)
		.background(Capsule().fill(kind.base.opacity(0.14)))
		.overlay(Capsule().strokeBorder(kind.base.opacity(0.40), lineWidth: 1))
		.onAppear {
			guard !reduceMotion else { return }
			DispatchQueue.main.async {
				withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
					pulsing = true
				}
			}
		}
	}
}
