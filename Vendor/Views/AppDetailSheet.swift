//
//  AppDetailSheet.swift
//  Vendor
//
//  Store-style detail page: hero, facts row, screenshots, description and
//  release notes. Presented as a floating panel over the blurred list.
//

import SwiftUI
import UIKit

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
	/// Listed but not downloadable yet.
	var comingSoon: Bool = false
	let screenshots: [URL]
	let badges: [(text: String, kind: SiteBadge.Kind)]
	let downloadURL: URL?
	let fileName: String

	/// True only when `id` really is the package's bundle identifier. A feed
	/// app's `id` is exactly that; a featured app's is a short slug picked
	/// for this app's own row, and offering to copy it as a "bundle ID"
	/// would hand out something that is not one.
	var showsBundleID: Bool = false

	/// One entry per version the repository still lists, newest first.
	struct HistoryEntry {
		let version: String
		let size: String?
	}
	/// Only ever populated from a feed — a featured app carries a single
	/// version and has nothing to list a history of.
	var history: [HistoryEntry] = []

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
		showsBundleID = true
		history = (app.versions ?? []).compactMap { entry in
			guard let version = entry.version?.trimmingCharacters(in: .whitespacesAndNewlines),
				  !version.isEmpty
			else { return nil }
			return HistoryEntry(version: version, size: Self.displaySize(entry.size))
		}
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
		comingSoon = app.comingSoon
		downloadURL = app.downloadURL
		fileName = app.downloadURL.lastPathComponent
	}

	/// Mirrors `SourceApp.displaySize`, for one entry in `versions` rather
	/// than the app as a whole.
	private static func displaySize(_ bytes: Int64?) -> String? {
		guard let bytes, bytes > 0 else { return nil }
		let f = ByteCountFormatter()
		f.countStyle = .file
		f.allowedUnits = [.useMB, .useGB]
		return f.string(fromByteCount: bytes)
	}
}

struct AppDetailSheet: View {
	let detail: AppDetail
	var onClose: () -> Void

	/// Not read directly — its presence keeps this view subscribed to
	/// `Localizer.shared`, so every `t(...)` call below redraws when the
	/// language flips.
	@ObservedObject private var localizer = Localizer.shared
	@ObservedObject private var downloader = Downloader.shared
	@ObservedObject private var ipaStore = IPAStore.shared

	@State private var descriptionExpanded = false
	@State private var copiedID = false
	@State private var expandedScreenshot: URL?

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
		// Measured against the screen's bottom, not the safe area's.
		//
		// Opening the panel hides the tab bar, which takes its inset out of the
		// bottom — and UIKit slides it away on its own clock, not ours. A panel
		// measured against that inset is laid out once with the bar there and
		// again without it, so it visibly settles downwards after it appears.
		// Ignoring the bottom edge takes the tab bar out of the equation
		// entirely: whatever it does, it cannot move this.
		//
		// Only the bottom. The top still respects the safe area, so the panel
		// keeps clear of the Dynamic Island exactly as before.
		.ignoresSafeArea(edges: .bottom)
		.fullScreenCover(
			isPresented: Binding(
				get: { expandedScreenshot != nil },
				set: { if !$0 { expandedScreenshot = nil } }
			)
		) {
			if let url = expandedScreenshot {
				ScreenshotViewer(url: url) { expandedScreenshot = nil }
			}
		}
	}

	// MARK: Get status

	private var downloadProgress: Double? { downloader.progress[detail.id] }

	/// Mirrors `GetButton`'s own matching rules so the note beneath it never
	/// disagrees with what the button itself is showing.
	private var imported: ImportedIPA? {
		if let match = ipaStore.packages.first(where: { $0.sourceID == detail.id }) { return match }
		let bundledName = detail.bundledFile.map { "\($0).ipa" }
		return ipaStore.packages.first {
			$0.sourceID == nil && ($0.fileName == detail.fileName || $0.fileName == bundledName)
		}
	}

	/// What the note beneath Get says, given where this package actually
	/// stands. The button only has room to answer "what do I do" — this is
	/// "what already happened", which on this screen there is room to say.
	private var statusNoteText: String {
		if downloadProgress != nil { return t("detail.downloading") }
		if let imported { return imported.isSigned ? t("detail.onShelfSigned") : t("detail.onShelf") }
		if detail.downloadURL == nil && detail.bundledFile == nil { return t("detail.noDownload") }
		return t("detail.getNote")
	}

	private var panel: some View {
		ZStack(alignment: .topTrailing) {
			ScrollView {
				VStack(alignment: .leading, spacing: 18) {
					hero
					facts
					bundleIDRow
					if !detail.screenshots.isEmpty { screenshots }
					aboutSection
					if let notes = detail.releaseNotes { section(t("apps.whatsNew"), body: notes) }
					history
				}
				.padding(.horizontal, 18)
				.padding(.top, 22)
				.padding(.bottom, 26)
			}
			.scrollBounceBehaviorCompat()
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

				if detail.comingSoon {
					// Same as the row: nothing to fetch, so nothing that looks
					// like it would. With the room this screen has, it can also
					// say why in words.
					VStack(alignment: .leading, spacing: 5) {
						SiteBadge(text: t("apps.soon"), kind: .soon)
						Text(t("apps.soonDetail"))
							.font(.system(size: 11))
							.foregroundStyle(Color.inkSecondary)
							.fixedSize(horizontal: false, vertical: true)
					}
					.padding(.top, 2)
				} else {
					// The same control the list rows use, rather than a plain Get
					// button of this screen's own: it already carries the download
					// ring, the hand-off to the IPA tab once the package is on the
					// shelf, and the alert when a fetch dies. A button here that
					// only started the download would look like nothing happened.
					GetButton(
						id: detail.id,
						downloadURL: detail.downloadURL,
						fileName: detail.fileName,
						bundledFile: detail.bundledFile
					)
					.padding(.top, 2)

					Text(statusNoteText)
						.font(.system(size: 11))
						.foregroundStyle(Color.inkSecondary)
						.fixedSize(horizontal: false, vertical: true)
						.padding(.top, 2)
				}
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

	// MARK: Bundle ID

	@ViewBuilder
	private var bundleIDRow: some View {
		if detail.showsBundleID {
			Button {
				UIPasteboard.general.string = detail.id
				Haptics.tap()
				withAnimation(.easeInOut(duration: 0.15)) { copiedID = true }
				DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
					withAnimation(.easeInOut(duration: 0.15)) { copiedID = false }
				}
			} label: {
				HStack(spacing: 5) {
					Image(systemName: copiedID ? "checkmark" : "doc.on.doc")
						.font(.system(size: 10, weight: .semibold))
					Text(copiedID ? t("detail.copied") : detail.id)
						.font(.system(size: 11, weight: .medium))
						.lineLimit(1)
						.truncationMode(.middle)
				}
				.foregroundStyle(Color.inkSecondary)
			}
			.buttonStyle(.plain)
			.frame(maxWidth: .infinity, alignment: .center)
			.accessibilityLabel(t("detail.copyID"))
		}
	}

	// MARK: Screenshots

	private var screenshots: some View {
		VStack(alignment: .leading, spacing: 8) {
			heading(t("apps.preview"))
			ScrollView(.horizontal, showsIndicators: false) {
				HStack(spacing: 10) {
					ForEach(Array(detail.screenshots.enumerated()), id: \.offset) { index, url in
						// Height is fixed, width follows each image's own shape:
						// feeds mix portrait and landscape captures, and forcing
						// one frame on both crops or turns them.
						Button {
							Haptics.tap()
							expandedScreenshot = url
						} label: {
							ScreenshotThumbnail(url: url)
								.frame(height: 260)
								.clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
								.overlay(
									RoundedRectangle(cornerRadius: 14, style: .continuous)
										.strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
								)
						}
						.buttonStyle(.plain)
						.accessibilityLabel(
							String(format: t("detail.shot"), index + 1, detail.screenshots.count)
						)
						.accessibilityHint(t("detail.viewShot"))
					}
				}
			}
			// Lets the strip run to the panel edges while the text stays inset.
			.padding(.horizontal, -18)
			.padding(.leading, 18)
		}
	}

	// MARK: Text sections

	/// Description only — release notes go through `section(_:body:)` below
	/// unchanged, since neither the empty state nor the read-more toggle
	/// belongs on those.
	private var aboutSection: some View {
		VStack(alignment: .leading, spacing: 7) {
			heading(t("apps.about"))
			if let description = detail.description,
			   !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
				Text(description)
					.font(.system(size: 13))
					.foregroundStyle(Color.inkSecondary)
					.lineSpacing(3)
					.lineLimit(descriptionExpanded ? nil : 6)
					.fixedSize(horizontal: false, vertical: true)
				// Short feed descriptions never actually reach six lines, so the
				// toggle only appears once there is something left to reveal.
				if description.count > 260 {
					Button {
						withAnimation(.easeInOut(duration: 0.2)) { descriptionExpanded.toggle() }
					} label: {
						Text(descriptionExpanded ? t("detail.readLess") : t("detail.readMore"))
							.font(.system(size: 12, weight: .semibold))
							.foregroundStyle(Color.brand)
					}
					.buttonStyle(.plain)
				}
			} else {
				Text(t("detail.noInfo"))
					.font(.system(size: 13))
					.foregroundStyle(Color.inkSecondary)
					.fixedSize(horizontal: false, vertical: true)
			}
		}
	}

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

	// MARK: Version history

	@ViewBuilder
	private var history: some View {
		// A single entry is just the current version restated, not a history.
		if detail.history.count > 1 {
			VStack(alignment: .leading, spacing: 8) {
				heading(t("detail.history"))
				VStack(spacing: 6) {
					ForEach(Array(detail.history.enumerated()), id: \.offset) { index, entry in
						HStack(spacing: 8) {
							Text(entry.version)
								.font(.system(size: 12, weight: .semibold))
								.foregroundStyle(Color.inkPrimary)
								.lineLimit(1)
							if index == 0 {
								Badge(text: t("detail.latest"), tone: .brand)
							}
							Spacer(minLength: 8)
							if let size = entry.size {
								Text(size)
									.font(.system(size: 11))
									.foregroundStyle(Color.inkSecondary)
							}
						}
						.padding(.vertical, 8)
						.padding(.horizontal, 10)
						.background(.ultraThinMaterial)
						.clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
					}
				}
				Text(t("detail.historyNote"))
					.font(.system(size: 10))
					.foregroundStyle(Color.inkSecondary)
					.fixedSize(horizontal: false, vertical: true)
			}
		}
	}
}

// MARK: - Screenshot cell

/// `CachedImage`'s placeholder cannot tell "still loading" from "gave up
/// entirely" — every caller until now only ever showed a spinner either way.
/// A feed screenshot is exactly the case that needs the difference: a dead
/// link buried among working ones should say so, not spin forever next to its
/// neighbours. Kept local rather than changing `CachedImage` itself, which
/// other screens rely on behaving exactly as it does today.
private struct ScreenshotThumbnail: View {
	let url: URL

	@State private var image: UIImage?
	@State private var failed = false

	var body: some View {
		Group {
			if let image {
				Image(uiImage: image)
					.resizable()
					.aspectRatio(contentMode: .fit)
			} else if failed {
				ZStack {
					Color.inkSecondary.opacity(0.10)
					VStack(spacing: 6) {
						Image(systemName: "exclamationmark.triangle")
							.font(.system(size: 18, weight: .light))
							.foregroundStyle(Color.inkSecondary)
						Text(t("detail.shotFailed"))
							.font(.system(size: 10))
							.foregroundStyle(Color.inkSecondary)
					}
				}
				.frame(width: 140)
			} else {
				ZStack {
					Color.inkSecondary.opacity(0.10)
					ProgressView()
				}
				.frame(width: 140)
			}
		}
		.task(id: url) {
			guard image == nil, !failed else { return }
			if let result = await ImageCache.shared.image(for: url, maximumPixels: ImageCache.screenshotPixels) {
				image = result
			} else {
				failed = true
			}
		}
	}
}

// MARK: - Full-size viewer

private struct ScreenshotViewer: View {
	let url: URL
	var onClose: () -> Void

	var body: some View {
		ZStack {
			Color.black.ignoresSafeArea()

			CachedImage(url: url, maximumPixels: ImageCache.screenshotPixels, contentMode: .fit) {
				ProgressView().tint(.white)
			}
			.padding(24)

			Button(action: onClose) {
				Image(systemName: "xmark")
					.font(.system(size: 13, weight: .bold))
					.foregroundStyle(.white)
					.glassCircle(size: 34)
			}
			.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
			.padding(.top, 14)
			.padding(.trailing, 14)
		}
		.contentShape(Rectangle())
		.onTapGesture(perform: onClose)
	}
}
