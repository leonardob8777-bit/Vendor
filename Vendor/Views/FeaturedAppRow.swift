//
//  FeaturedAppRow.swift
//  Vendor
//
//  Pinned row for a highlighted app: a status glow in the corner and the
//  site's own chip beside the name.
//

import SwiftUI

struct FeaturedAppRow: View {
	let app: FeaturedApp
	var onOpen: () -> Void

	var body: some View {
		Button(action: onOpen) { card }
			.buttonStyle(.plain)
	}

	// MARK: Card

	private var card: some View {
		HStack(spacing: 12) {
			icon

			VStack(alignment: .leading, spacing: 4) {
				// Chip sits on the name line, the way the website places it.
				HStack(spacing: 6) {
					Text(app.name)
						.font(.system(size: 16, weight: .bold))
						.foregroundStyle(Color.inkPrimary)
						.fixedSize()

					ForEach(Array(app.badges.enumerated()), id: \.offset) { _, badge in
						SiteBadge(text: badge.text, kind: badge.kind)
					}
				}

				Text(app.developer)
					.font(.system(size: 11))
					.foregroundStyle(Color.inkSecondary)

				Text(app.summary)
					.font(.system(size: 11))
					.foregroundStyle(Color.inkSecondary)
					.lineLimit(2)
					.fixedSize(horizontal: false, vertical: true)
			}

			Spacer(minLength: 8)

			VStack(alignment: .trailing, spacing: 5) {
				GetButton(
					id: app.id,
					downloadURL: app.downloadURL,
					fileName: app.downloadURL.lastPathComponent,
					bundledFile: app.bundledFile
				)

				HStack(spacing: 4) {
					if let version = app.version {
						Text(version)
						Text("·")
					}
					if let size = app.displaySize {
						Text(size)
					}
				}
				.font(.system(size: 10))
				.foregroundStyle(Color.inkSecondary)
				.lineLimit(1)
			}
		}
		.statusCard(padding: 12, glow: app.glow)
	}

	private var icon: some View {
		Group {
			// Bundled artwork wins: it is already on disk, so the row never
			// shows a placeholder while a download it does not need finishes.
			if let asset = app.iconAsset {
				Image(asset)
					.resizable()
					.aspectRatio(contentMode: .fill)
			} else {
				CachedImage(url: app.iconURL) {
					ZStack {
						app.glow.opacity(0.16)
						Image(systemName: "wrench.and.screwdriver")
							.font(.system(size: 20, weight: .light))
							.foregroundStyle(app.glow)
					}
				}
			}
		}
		.frame(width: 52, height: 52)
		.clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
		.overlay(
			RoundedRectangle(cornerRadius: 13, style: .continuous)
				.strokeBorder(app.glow.opacity(0.35), lineWidth: 1)
		)
	}
}
