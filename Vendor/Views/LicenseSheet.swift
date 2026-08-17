//
//  LicenseSheet.swift
//  Vendor
//
//  Read-only viewer for one bundled licence file, opened from Settings' Open
//  Source list. Same floating-panel shell as GuideDetailSheet, stacked over it
//  rather than replacing it, since the licence text is long enough to want the
//  full pane rather than a popover squeezed into Settings' own scroll view.
//
//  The text itself is the one thing here that must never go through
//  `Localizer`: a licence translated into Spanish is not the licence that
//  was granted, which is also why GuideContent's copy of these same three
//  files is read the same way instead of typed into the string table.
//

import SwiftUI

struct LicenseSheet: View {
	let license: LicenseFile
	/// Called by the close button and by a tap outside the panel.
	var dismiss: () -> Void

	/// Not read directly — its presence keeps this view subscribed to
	/// `Localizer.shared`, so the close button's label and the missing-file
	/// fallback below redraw if the language flips while this is open. The
	/// licence text itself is deliberately never run through `t(...)`.
	@ObservedObject private var localizer = Localizer.shared

	var body: some View {
		ZStack {
			Color.clear
				.ignoresSafeArea()
				.contentShape(Rectangle())
				.onTapGesture(perform: dismiss)

			panel
				.padding(.horizontal, 26)
				.padding(.vertical, 100)
		}
		.ignoresSafeArea(edges: .bottom)
	}

	private var panel: some View {
		ZStack(alignment: .topTrailing) {
			ScrollView {
				VStack(alignment: .leading, spacing: 14) {
					header
					Text(licenseText)
						.font(.system(size: 12, design: .monospaced))
						.foregroundStyle(Color.inkSecondary)
						.lineSpacing(3)
						.fixedSize(horizontal: false, vertical: true)
				}
				.padding(.horizontal, 18)
				.padding(.top, 22)
				.padding(.bottom, 28)
			}
			.scrollBounceBehaviorCompat()
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

			Button(action: dismiss) {
				Image(systemName: "xmark")
					.font(.system(size: 13, weight: .bold))
					.foregroundStyle(Color.inkPrimary)
					.glassCircle(size: 34)
			}
			.padding(.top, 14)
			.padding(.trailing, 14)
			.accessibilityLabel(t("common.close"))
		}
		.background {
			ZStack {
				RoundedRectangle(cornerRadius: 28, style: .continuous)
					.fill(.ultraThinMaterial)
				RoundedRectangle(cornerRadius: 28, style: .continuous)
					.fill(
						LinearGradient(
							colors: [Color.brand.opacity(0.14), Color.mint.opacity(0.08)],
							startPoint: .topLeading, endPoint: .bottomTrailing
						)
					)
				RoundedRectangle(cornerRadius: 28, style: .continuous)
					.strokeBorder(
						LinearGradient(
							colors: [.white.opacity(0.30), .white.opacity(0.06), Color.mint.opacity(0.20)],
							startPoint: .topLeading, endPoint: .bottomTrailing
						),
						lineWidth: 1
					)
			}
		}
		.clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
		.shadow(color: .black.opacity(0.45), radius: 28, y: 14)
		.shadow(color: Color.brand.opacity(0.22), radius: 34, y: 18)
	}

	private var header: some View {
		VStack(alignment: .leading, spacing: 8) {
			GlyphTile(systemName: "doc.text", size: 46)

			Text(license.displayName)
				.font(.system(size: 22, weight: .bold))
				.foregroundStyle(Color.inkPrimary)

			Text(license.licence)
				.font(.system(size: 12, weight: .medium))
				.foregroundStyle(Color.inkSecondary)

			Rectangle()
				.fill(LinearGradient.actionFlow)
				.frame(height: 2)
				.clipShape(Capsule())
				.padding(.top, 2)
		}
		.padding(.trailing, 44) // clears the close button
	}

	private var licenseText: String {
		guard let url = Bundle.main.url(forResource: license.id, withExtension: "txt"),
			  let text = try? String(contentsOf: url, encoding: .utf8)
		else {
			return "\(license.displayName): \(t("settings.licenseMissing"))"
		}
		return text.trimmingCharacters(in: .whitespacesAndNewlines)
	}
}
