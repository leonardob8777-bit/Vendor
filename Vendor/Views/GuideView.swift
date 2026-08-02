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
			$0.searchText.localizedCaseInsensitiveContains(query)
		}
	}

	var body: some View {
		Screen(t("tab.guide"), contentBlur: opened == nil ? 0 : 16) {
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
		// Not a `.sheet`: a system sheet is presented in its own window, so the
		// screen behind it cannot be blurred. Laying the panel over the content
		// is what lets the guide float above a soft version of the list, the
		// same way the install panel does.
		.animation(.easeInOut(duration: 0.25), value: opened == nil)
		.overlay {
			if let guide = opened {
				GuideDetailSheet(guide: guide) { opened = nil }
					// Opacity only, and the same flat curve as the blur, so
					// the panel and the softening behind it move together. The
					// scale that used to be here grew the pane into place;
					// every floating window fades now instead.
					.transition(.opacity)
			}
		}
		.animation(.easeInOut(duration: 0.25), value: opened?.id)
		// The tab bar belongs to the TabView, so it draws above anything a tab's
		// own content puts on screen — sharp chrome sitting on top of a panel
		// that is meant to be floating clear of the screen. Taking it away for
		// as long as the guide is open is what finishes the effect.
		.toolbar(opened == nil ? .visible : .hidden, for: .tabBar)
	}

	private var searchField: some View {
		HStack(spacing: 8) {
			Image(systemName: "magnifyingglass")
				.font(.system(size: 13, weight: .semibold))
				.foregroundStyle(Color.inkSecondary)
			TextField(t("guide.search"), text: $query)
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
