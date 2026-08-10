//
//  GuideDetailSheet.swift
//  Vendor
//
//  Floating help panel, laid over the guide list rather than presented as a
//  sheet — the caller blurs what is behind, so the panel reads as hovering
//  above the screen instead of covering it.
//
//  Every guide gets the same pane at the same size, whatever the length of
//  what is inside it: the generous margins are what make it read as floating,
//  and the content scrolls within them.
//

import SwiftUI

struct GuideDetailSheet: View {
	let guide: GuideEntry
	/// Called by the close button and by a tap outside the panel.
	var dismiss: () -> Void

	/// Not read directly — its presence keeps this view subscribed to
	/// `Localizer.shared`, so every `t(...)` call below redraws when the
	/// language flips.
	@ObservedObject private var localizer = Localizer.shared

	var body: some View {
		ZStack {
			// Deliberately no dimming layer. A veil over the whole screen also
			// covers the strip beside the Dynamic Island, where there is nothing
			// but backdrop to dim — so opening a guide darkened that strip by a
			// flat 18% and it read as a black sheet laid over the top of the
			// display. The blurred content behind and the pane's own material
			// separate the two planes on their own.
			// Tapping away closes it, the same as the app, language and trust
			// windows. This one only had its X button, so the same gesture did
			// nothing here and worked everywhere else.
			Color.clear
				.ignoresSafeArea()
				.contentShape(Rectangle())
				.onTapGesture(perform: dismiss)

			panel
				.padding(.horizontal, 26)
				.padding(.vertical, 100)
		}
		// See `AppDetailSheet`: the tab bar's inset leaves the bottom of the
		// safe area partway through the opening, and a panel measured against it
		// settles downwards afterwards. Every floating window ignores the bottom
		// edge for that reason, and they stay the same size as each other by
		// doing it together.
		.ignoresSafeArea(edges: .bottom)
	}

	/// The floating pane itself.
	private var panel: some View {
		ZStack(alignment: .topTrailing) {
			ScrollView {
				VStack(alignment: .leading, spacing: 16) {
					header

					// Indexed rather than by the block's own id, which is built
					// from its text: two headings reading the same thing — and
					// "Steps" is an obvious candidate — would hand ForEach a
					// repeated id. Position cannot collide.
					ForEach(Array(guide.blocks.enumerated()), id: \.offset) { _, block in
						view(for: block)
					}
				}
				.padding(.horizontal, 18)
				.padding(.top, 22)
				.padding(.bottom, 28)
			}
			// A guide short enough to fit shouldn't rubber-band as though there
			// were more below it.
			.scrollBounceBehaviorCompat()
			// Long guides run past the bottom edge, and a line of text sliced
			// in half by the pane's border reads as clipped rather than
			// scrollable. Fading the last stretch says there is more below.
			.mask(
				LinearGradient(
					stops: [
						.init(color: .black, location: 0),
						.init(color: .black, location: 0.90),
						.init(color: .black.opacity(0), location: 1),
					],
					startPoint: .top,
					endPoint: .bottom
				)
			)

			closeButton
				.padding(.top, 14)
				.padding(.trailing, 14)
		}
		.background {
			ZStack {
				RoundedRectangle(cornerRadius: 28, style: .continuous)
					.fill(.ultraThinMaterial)

				// A hint of brand colour so the pane is never a grey slab.
				RoundedRectangle(cornerRadius: 28, style: .continuous)
					.fill(
						LinearGradient(
							colors: [Color.brand.opacity(0.14), Color.mint.opacity(0.08)],
							startPoint: .topLeading,
							endPoint: .bottomTrailing
						)
					)

				RoundedRectangle(cornerRadius: 28, style: .continuous)
					.strokeBorder(
						LinearGradient(
							colors: [.white.opacity(0.30), .white.opacity(0.06), Color.mint.opacity(0.20)],
							startPoint: .topLeading,
							endPoint: .bottomTrailing
						),
						lineWidth: 1
					)
			}
		}
		.clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
		.shadow(color: .black.opacity(0.45), radius: 28, y: 14)
		.shadow(color: Color.brand.opacity(0.22), radius: 34, y: 18)
	}

	// MARK: Chrome

	private var closeButton: some View {
		Button { dismiss() } label: {
			Image(systemName: "xmark")
				.font(.system(size: 13, weight: .bold))
				.foregroundStyle(Color.inkPrimary)
				.glassCircle(size: 34)
		}
		.accessibilityLabel(t("common.close"))
	}

	private var header: some View {
		VStack(alignment: .leading, spacing: 12) {
			GlyphTile(systemName: guide.glyph, size: 52)

			Text(guide.title)
				.font(.system(size: 25, weight: .bold))
				.foregroundStyle(Color.inkPrimary)
				.fixedSize(horizontal: false, vertical: true)

			Text(guide.detail)
				.font(.system(size: 14))
				.foregroundStyle(Color.inkSecondary)
				.fixedSize(horizontal: false, vertical: true)

			Rectangle()
				.fill(LinearGradient.actionFlow)
				.frame(height: 2)
				.clipShape(Capsule())
				.padding(.top, 2)
		}
		.padding(.trailing, 44) // clears the close button
	}

	// MARK: Blocks

	@ViewBuilder
	private func view(for block: GuideBlock) -> some View {
		switch block {
		case .heading(let text):
			Text(text)
				.font(.system(size: 17, weight: .semibold))
				.foregroundStyle(Color.inkPrimary)
				.fixedSize(horizontal: false, vertical: true)
				.padding(.top, 6)

		case .paragraph(let text):
			Text(text)
				.font(.system(size: 14))
				.foregroundStyle(Color.inkSecondary)
				.lineSpacing(3)
				.fixedSize(horizontal: false, vertical: true)

		case .steps(let items):
			VStack(alignment: .leading, spacing: 10) {
				ForEach(Array(items.enumerated()), id: \.offset) { index, text in
					HStack(alignment: .top, spacing: 12) {
						Text("\(index + 1)")
							.font(.system(size: 12, weight: .bold))
							.foregroundStyle(.white)
							.frame(width: 22, height: 22)
							.background(Circle().fill(LinearGradient.actionFlow))

						Text(text)
							.font(.system(size: 14))
							.foregroundStyle(Color.inkPrimary)
							.lineSpacing(3)
							.fixedSize(horizontal: false, vertical: true)
					}
				}
			}
			.padding(14)
			.frame(maxWidth: .infinity, alignment: .leading)
			.background(.ultraThinMaterial)
			.clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

		case .note(let text):
			callout(text, glyph: "info.circle", tint: .brand)

		case .warning(let text):
			callout(text, glyph: "exclamationmark.triangle", tint: .warn)
		}
	}

	private func callout(_ text: String, glyph: String, tint: Color) -> some View {
		HStack(alignment: .top, spacing: 10) {
			Image(systemName: glyph)
				.font(.system(size: 14, weight: .semibold))
				.foregroundStyle(tint)
			Text(text)
				.font(.system(size: 13))
				.foregroundStyle(Color.inkPrimary)
				.lineSpacing(2)
				.fixedSize(horizontal: false, vertical: true)
		}
		.padding(13)
		.frame(maxWidth: .infinity, alignment: .leading)
		.background(tint.opacity(0.10))
		.overlay(alignment: .leading) {
			Rectangle().fill(tint).frame(width: 3)
		}
		.clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
	}
}
