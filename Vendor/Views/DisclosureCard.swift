//
//  DisclosureCard.swift
//  Vendor
//
//  A section that stays folded away until it is asked for. Used for controls
//  that matter to a few people and would otherwise crowd the screen for
//  everyone else.
//
//  Not SwiftUI's `DisclosureGroup`: that draws a system chevron and an
//  indentation of its own that neither matches the cards around it nor can be
//  restyled far enough to.
//

import SwiftUI

struct DisclosureCard<Content: View>: View {
	let title: String
	var glyph: String = "slider.horizontal.3"
	/// Shown beside the title when folded, for a section to say it holds
	/// something without being opened.
	var badge: String?
	@Binding var isOpen: Bool
	@ViewBuilder var content: () -> Content

	var body: some View {
		VStack(alignment: .leading, spacing: 10) {
			Button {
				Haptics.tap()
				withAnimation(.easeInOut(duration: 0.22)) { isOpen.toggle() }
			} label: {
				HStack(spacing: 9) {
					Image(systemName: glyph)
						.font(.system(size: 12, weight: .semibold))
						.foregroundStyle(Color.brand)

					Text(title)
						.font(.system(size: 12, weight: .semibold))
						.foregroundStyle(Color.inkPrimary)

					if let badge, !isOpen {
						Badge(text: badge, tone: .brand)
					}

					Spacer(minLength: 0)

					Image(systemName: "chevron.down")
						.font(.system(size: 11, weight: .bold))
						.foregroundStyle(Color.inkSecondary)
						.rotationEffect(.degrees(isOpen ? 0 : -90))
				}
				.contentShape(Rectangle())
			}
			.buttonStyle(.plain)

			if isOpen {
				content()
					// Fades and slides from under the header rather than simply
					// appearing, so a tall section does not shove the rest of the
					// card down in one jump.
					.transition(.opacity.combined(with: .move(edge: .top)))
			}
		}
		.padding(11)
		.background(.ultraThinMaterial)
		.clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
		.overlay(
			RoundedRectangle(cornerRadius: 13, style: .continuous)
				.strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
		)
		.clipped()
	}
}
