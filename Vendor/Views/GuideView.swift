//
//  GuideView.swift
//  Vendor
//

import SwiftUI

struct GuideView: View {
	@State private var query = ""
	@State private var opened: GuideEntry?

	private var filtered: [GuideEntry] {
		guard !query.isEmpty else { return GuideContent.all }
		return GuideContent.all.filter {
			$0.title.localizedCaseInsensitiveContains(query)
			|| $0.detail.localizedCaseInsensitiveContains(query)
		}
	}

	var body: some View {
		Screen(t("tab.guide")) {
			searchField
			VStack(spacing: 8) {
				ForEach(filtered) { guide in
					Button { opened = guide } label: {
						row(for: guide)
					}
					.buttonStyle(.plain)
				}
			}
		}
		.sheet(item: $opened) { guide in
			GuideDetailSheet(guide: guide)
		}
	}

	private var searchField: some View {
		HStack(spacing: 8) {
			Image(systemName: "magnifyingglass")
				.font(.system(size: 13, weight: .semibold))
				.foregroundStyle(Color.inkSecondary)
			TextField("Search guides...", text: $query)
				.font(.system(size: 14))
				.foregroundStyle(Color.inkPrimary)
				.autocorrectionDisabled()
		}
		.padding(.horizontal, 14)
		.padding(.vertical, 11)
		.background(.ultraThinMaterial)
		.clipShape(Capsule())
		.overlay(Capsule().strokeBorder(Color.white.opacity(0.14), lineWidth: 1))
		.shadow(color: .black.opacity(0.10), radius: 6, x: 0, y: 2)
	}

	private func row(for guide: GuideEntry) -> some View {
		HStack(spacing: 12) {
			GlyphTile(systemName: guide.glyph, size: 42)

			VStack(alignment: .leading, spacing: 3) {
				Text(guide.title)
					.font(.system(size: 15, weight: .semibold))
					.foregroundStyle(Color.inkPrimary)
					.multilineTextAlignment(.leading)
				Text(guide.detail)
					.font(.system(size: 12))
					.foregroundStyle(Color.inkSecondary)
					.multilineTextAlignment(.leading)
					.fixedSize(horizontal: false, vertical: true)
			}

			Spacer(minLength: 8)

			Image(systemName: "chevron.right")
				.font(.system(size: 13, weight: .semibold))
				.foregroundStyle(Color.inkSecondary)
		}
		.card(padding: 11)
	}
}
