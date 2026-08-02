//
//  GuideDetailSheet.swift
//  Vendor
//
//  Floating help panel. The sheet background is a blur rather than a solid
//  colour, so the screen underneath stays visible through it.
//

import SwiftUI

struct GuideDetailSheet: View {
	@Environment(\.dismiss) private var dismiss
	let guide: GuideEntry

	var body: some View {
		ZStack {
			// Dims what is behind just enough to keep the text readable,
			// while leaving the screen underneath visible.
			Color.black.opacity(0.28)
				.ignoresSafeArea()
				.onTapGesture { dismiss() }

			panel
				.padding(.horizontal, 12)
				.padding(.vertical, 26)
		}
		// A clear sheet background is what actually makes the panel float —
		// a material here would just render as flat grey over dark content.
		.presentationBackground(.clear)
		.presentationDragIndicator(.hidden)
		.presentationDetents([.large])
	}

	/// The floating pane itself.
	private var panel: some View {
		ZStack(alignment: .topTrailing) {
			ScrollView {
				VStack(alignment: .leading, spacing: 16) {
					header

					ForEach(guide.blocks) { block in
						view(for: block)
					}
				}
				.padding(.horizontal, 18)
				.padding(.top, 22)
				.padding(.bottom, 28)
			}

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
		.accessibilityLabel("Close")
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
