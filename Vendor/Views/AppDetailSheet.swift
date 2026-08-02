//
//  AppDetailSheet.swift
//  Vendor
//
//  Store-style detail page: hero, facts row, screenshots, description and
//  release notes. Presented as a floating panel over the blurred list.
//

import SwiftUI

/// The subset of an app the detail page needs, so both feed apps and pinned
/// ones can share the screen.
struct AppDetail: Identifiable {
	let id: String
	let name: String
	let developer: String?
	let subtitle: String?
	let description: String?
	let version: String?
	let size: String?
	let released: String?
	let releaseNotes: String?
	let iconURL: URL?
	/// Bundled artwork, when the app ships its icon with Vendor.
	var iconAsset: String? = nil
	/// Package shipped inside Vendor, when there is one.
	var bundledFile: String? = nil
	let screenshots: [URL]
	let badges: [(text: String, kind: SiteBadge.Kind)]
	let downloadURL: URL?
	let fileName: String

	init(_ app: SourceApp) {
		id = app.bundleIdentifier
		name = app.name
		developer = app.developerName
		subtitle = app.subtitle
		description = app.localizedDescription
		version = app.displayVersion
		size = app.displaySize
		released = app.releasedOn
		releaseNotes = app.releaseNotes
		iconURL = app.iconLink
		screenshots = app.screenshotLinks
		badges = []
		downloadURL = app.downloadLink
		fileName = app.suggestedFileName
	}

	init(_ app: FeaturedApp) {
		id = app.id
		name = app.name
		developer = app.developer
		subtitle = nil
		description = app.summary
		version = app.version
		size = app.displaySize
		released = nil
		releaseNotes = nil
		iconURL = app.iconURL
		iconAsset = app.iconAsset
		bundledFile = app.bundledFile
		screenshots = []
		badges = app.badges
		downloadURL = app.downloadURL
		fileName = app.downloadURL.lastPathComponent
	}
}

struct AppDetailSheet: View {
	let detail: AppDetail
	var onClose: () -> Void

	var body: some View {
		ZStack {
			// No dimming layer, for the reason spelled out in GuideDetailSheet:
			// a veil across the whole screen darkens the strip beside the
			// Dynamic Island too, where it reads as a black sheet laid over the
			// display rather than as depth.
			Color.clear
				.ignoresSafeArea()
				.contentShape(Rectangle())
				.onTapGesture(perform: onClose)

			// Same margins as the guide pane, so the floating windows are one
			// size across the app rather than each its own.
			panel
				.padding(.horizontal, 26)
				.padding(.vertical, 100)
		}
	}

	private var panel: some View {
		ZStack(alignment: .topTrailing) {
			ScrollView {
				VStack(alignment: .leading, spacing: 18) {
					hero
					facts
					if !detail.screenshots.isEmpty { screenshots }
					if let description = detail.description { section(t("apps.about"), body: description) }
					if let notes = detail.releaseNotes { section(t("apps.whatsNew"), body: notes) }
				}
				.padding(.horizontal, 18)
				.padding(.top, 22)
				.padding(.bottom, 26)
			}
			.scrollBounceBehavior(.basedOnSize)
			// Same fade as the guide pane: a description cut in half against the
			// border reads as clipped rather than as scrollable.
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

			Button(action: onClose) {
				Image(systemName: "xmark")
					.font(.system(size: 13, weight: .bold))
					.foregroundStyle(Color.inkPrimary)
					.glassCircle(size: 34)
			}
			.padding(.top, 14)
			.padding(.trailing, 14)
		}
		.background {
			ZStack {
				RoundedRectangle(cornerRadius: 28, style: .continuous)
					.fill(.ultraThinMaterial)
				RoundedRectangle(cornerRadius: 28, style: .continuous)
					.fill(
						LinearGradient(
							colors: [Color.brand.opacity(0.13), Color.mint.opacity(0.07)],
							startPoint: .topLeading, endPoint: .bottomTrailing
						)
					)
				RoundedRectangle(cornerRadius: 28, style: .continuous)
					.strokeBorder(
						LinearGradient(
							colors: [.white.opacity(0.28), .white.opacity(0.05), Color.mint.opacity(0.18)],
							startPoint: .topLeading, endPoint: .bottomTrailing
						),
						lineWidth: 1
					)
			}
		}
		.clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
		.shadow(color: .black.opacity(0.45), radius: 30, y: 16)
		.shadow(color: Color.brand.opacity(0.20), radius: 36, y: 20)
	}

	// MARK: Hero

	private var hero: some View {
		HStack(alignment: .top, spacing: 14) {
			Group {
				if let asset = detail.iconAsset {
					Image(asset)
						.resizable()
						.aspectRatio(contentMode: .fill)
				} else {
					AsyncImage(url: detail.iconURL) { phase in
						switch phase {
						case .success(let image):
							image.resizable().aspectRatio(contentMode: .fill)
						default:
							ZStack {
								Color.brandSoft
								Image(systemName: "square.dashed")
									.font(.system(size: 22, weight: .light))
									.foregroundStyle(Color.brand)
							}
						}
					}
				}
			}
			.frame(width: 82, height: 82)
			.clipShape(RoundedRectangle(cornerRadius: 19, style: .continuous))
			.shadow(color: .black.opacity(0.3), radius: 8, y: 3)

			VStack(alignment: .leading, spacing: 6) {
				Text(detail.name)
					.font(.system(size: 21, weight: .bold))
					.foregroundStyle(Color.inkPrimary)
					.lineLimit(2)
					.fixedSize(horizontal: false, vertical: true)

				if let developer = detail.developer {
					Text(developer)
						.font(.system(size: 12))
						.foregroundStyle(Color.inkSecondary)
						.lineLimit(1)
				}

				if !detail.badges.isEmpty {
					HStack(spacing: 6) {
						ForEach(Array(detail.badges.enumerated()), id: \.offset) { _, badge in
							SiteBadge(text: badge.text, kind: badge.kind)
						}
					}
				}

				// The same control the list rows use, rather than a plain Get
				// button of this screen's own: it already carries the download
				// ring, the hand-off to the IPA tab once the package is on the
				// shelf, and the alert when a fetch dies. A button here that only
				// started the download would look like nothing had happened.
				GetButton(
					id: detail.id,
					downloadURL: detail.downloadURL,
					fileName: detail.fileName,
					bundledFile: detail.bundledFile
				)
				.padding(.top, 2)
			}

			Spacer(minLength: 0)
		}
		.padding(.trailing, 40) // clears the close button
	}

	// MARK: Facts

	private var facts: some View {
		HStack(spacing: 0) {
			fact(t("apps.version"), detail.version ?? "—")
			divider
			fact(t("apps.size"), detail.size ?? "—")
			divider
			fact(t("apps.released"), detail.released ?? "—")
		}
		.padding(.vertical, 12)
		.frame(maxWidth: .infinity)
		.background(.ultraThinMaterial)
		.clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
	}

	private func fact(_ label: String, _ value: String) -> some View {
		VStack(spacing: 3) {
			Text(label.uppercased())
				.font(.system(size: 9, weight: .semibold))
				.kerning(0.5)
				.foregroundStyle(Color.inkSecondary)
			Text(value)
				.font(.system(size: 13, weight: .semibold))
				.foregroundStyle(Color.inkPrimary)
				.lineLimit(1)
				.minimumScaleFactor(0.7)
		}
		.frame(maxWidth: .infinity)
	}

	private var divider: some View {
		Rectangle()
			.fill(Color.inkSecondary.opacity(0.22))
			.frame(width: 1, height: 26)
	}

	// MARK: Screenshots

	private var screenshots: some View {
		VStack(alignment: .leading, spacing: 8) {
			heading(t("apps.preview"))
			ScrollView(.horizontal, showsIndicators: false) {
				HStack(spacing: 10) {
					ForEach(detail.screenshots, id: \.absoluteString) { url in
						// Height is fixed, width follows each image's own shape:
						// feeds mix portrait and landscape captures, and forcing
						// one frame on both crops or turns them.
						AsyncImage(url: url) { phase in
							switch phase {
							case .success(let image):
								image
									.resizable()
									.aspectRatio(contentMode: .fit)
									.frame(height: 260)
							case .failure:
								Color.inkSecondary.opacity(0.12)
									.frame(width: 140, height: 260)
							default:
								ZStack {
									Color.inkSecondary.opacity(0.10)
									ProgressView()
								}
								.frame(width: 140, height: 260)
							}
						}
						.clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
						.overlay(
							RoundedRectangle(cornerRadius: 14, style: .continuous)
								.strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
						)
					}
				}
			}
			// Lets the strip run to the panel edges while the text stays inset.
			.padding(.horizontal, -18)
			.padding(.leading, 18)
		}
	}

	// MARK: Text sections

	private func section(_ title: String, body text: String) -> some View {
		VStack(alignment: .leading, spacing: 7) {
			heading(title)
			Text(text)
				.font(.system(size: 13))
				.foregroundStyle(Color.inkSecondary)
				.lineSpacing(3)
				.fixedSize(horizontal: false, vertical: true)
		}
	}

	private func heading(_ text: String) -> some View {
		Text(text)
			.font(.system(size: 16, weight: .semibold))
			.foregroundStyle(Color.inkPrimary)
	}
}
