//
//  AppsView.swift
//  Vendor
//

import SwiftUI

/// One repository that loaded, ready to render.
struct LoadedSource: Identifiable {
	/// The address it came from, which is what makes it unique — there is more
	/// than one repository shipped with the app, so "built-in" is not an id.
	let id: String
	/// Nil for the repositories Vendor ships with.
	let custom: CustomSource?
	let source: AppSource

	var title: String { source.name ?? custom?.displayName ?? t("apps.source") }
}

@Observable
final class AppsViewModel {
	enum State {
		case loading
		case loaded([LoadedSource])
		case failed(String)
	}

	private(set) var state: State = .loading
	/// Repositories that were added but could not be read this time, by name.
	private(set) var unreachable: [String] = []
	var query = ""

	/// Loads every repository at once.
	///
	/// One that is down must not take the others with it: each is collected
	/// separately and its failure is reported beside the ones that worked,
	/// rather than replacing the whole screen with an error.
	func load() async {
		state = .loading
		unreachable = []

		let custom = SourceStore.shared.sources

		var loaded: [LoadedSource] = []
		var failed: [String] = []

		// The shipped repositories, in the order they are listed.
		for entry in SourceLoader.defaultSources {
			// An opt-in repository is not fetched at all until it is switched
			// on: no request, no wait, nothing on the screen.
			if entry.optIn && !SourceStore.shared.includes(entry.url) { continue }

			if let source = try? await SourceLoader.load(from: entry.url) {
				loaded.append(LoadedSource(id: entry.url.absoluteString, custom: nil, source: source))
			} else {
				failed.append(entry.url.host ?? entry.url.absoluteString)
			}
		}

		// Only worth taking over the screen when nothing at all came back.
		if loaded.isEmpty && custom.isEmpty {
			state = .failed(t("apps.allSourcesFailed"))
			return
		}

		await withTaskGroup(of: (CustomSource, AppSource?).self) { group in
			for entry in custom {
				group.addTask {
					(entry, try? await SourceLoader.load(from: entry.url))
				}
			}
			for await (entry, source) in group {
				if let source {
					SourceStore.shared.rename(entry.id, to: source.name)
					loaded.append(LoadedSource(id: entry.id.uuidString, custom: entry, source: source))
				} else {
					failed.append(entry.displayName)
				}
			}
		}

		// The built-in one first, then the rest in the order they were added —
		// a task group finishes in whatever order the network decides, and a
		// list that reshuffles itself on every refresh is unusable.
		let shipped = SourceLoader.defaultSourceURLs.map(\.absoluteString)
		let added = custom.map(\.id.uuidString)
		func rank(_ entry: LoadedSource) -> Int {
			if let i = shipped.firstIndex(of: entry.id) { return i }
			return shipped.count + (added.firstIndex(of: entry.id) ?? 0)
		}
		loaded.sort { rank($0) < rank($1) }

		unreachable = failed
		state = .loaded(loaded)
	}

	func matches(_ source: AppSource) -> [SourceApp] {
		guard !query.isEmpty else { return source.apps }
		return source.apps.filter {
			$0.name.containsFolding(query)
			|| ($0.developerName?.containsFolding(query) ?? false)
			|| ($0.subtitle?.containsFolding(query) ?? false)
		}
	}
}

struct AppsView: View {
	@State private var model = AppsViewModel()
	@State private var inspecting: AppDetail?
	@State private var managingSources = false

	var body: some View {
		Screen(
			t("tab.apps"),
			toolbar: AnyView(toolbarButtons),
			// Through `Screen` rather than a `.blur` on the whole thing: the
			// aurora ignores the safe area, so blurring the screen as a whole
			// leaves the strip beside the Dynamic Island outside the blurred
			// layer and the join reads as a black line across the top.
			contentBlur: inspecting == nil && !managingSources ? 0 : 16
		) {
			searchField.scrollEdgeSoftening()

			// Pinned above the remote source so it stays first whatever the
			// feed returns.
			ForEach(FeaturedApp.all) { featured in
				FeaturedAppRow(app: featured) { inspecting = AppDetail(featured) }
				.padding(.top, 4)
				.scrollEdgeSoftening()
			}

			switch model.state {
			case .loading:
				loadingState
			case .failed(let message):
				failureState(message)
			case .loaded(let loaded):
				// A repository that could not be read is named rather than
				// silently missing — otherwise adding a dead one looks like
				// nothing happened at all.
				ForEach(model.unreachable, id: \.self) { name in
					CalloutRow(text: String(format: t("apps.sourceFailed"), name))
				}

				let sections = loaded.map { ($0, model.matches($0.source)) }
					.filter { !$0.1.isEmpty }

				if sections.isEmpty {
					emptyState
				} else {
					// Lazy, not a plain VStack: one of the shipped repositories
					// lists over eight thousand apps, and building every row up
					// front freezes the tab on arrival.
					ForEach(sections, id: \.0.id) { entry, apps in
						sourceHeader(entry, count: apps.count)
						LazyVStack(spacing: 8) {
							ForEach(apps) { app in
								Button { inspecting = AppDetail(app) } label: {
									row(for: app)
								}
								.buttonStyle(.plain)
								.scrollEdgeSoftening()
							}
						}
					}
				}
			}
		}
		.task { await model.load() }
		.refreshable { await model.load() }
		// Flat curve for the blur, on the screen itself rather than over the
		// overlay: it has to reach 16 and stop. On a spring it overshoots and
		// settles back, and the softening visibly bounces.
		.animation(.easeInOut(duration: 0.25), value: inspecting == nil)
		// Presented as an overlay rather than a sheet: iOS dims and shrinks the
		// presenting view behind a sheet, and the design calls for the app
		// list to stay visible — just blurred.
		.overlay {
			if let detail = inspecting {
				AppDetailSheet(detail: detail) { inspecting = nil }
					// Opacity only. A scale transition grows the panel into
					// place, and at nearly the size of the display that reads as
					// the window stretching rather than as it arriving. The fade
					// is what makes it feel unhurried; the scale never was.
					.transition(.opacity)
			}
		}
		.animation(.easeInOut(duration: 0.25), value: inspecting?.id)
		.overlay {
			if managingSources {
				SourcesSheet {
					managingSources = false
					// Reloading on the way out rather than on every edit: adding
					// two repositories in a row should fetch once, not twice.
					Task { await model.load() }
				}
				.transition(.opacity)
			}
		}
		.animation(.easeInOut(duration: 0.25), value: managingSources)
		// The tab bar is the TabView's, so it draws above anything a tab lays
		// over its own content — sharp chrome on top of a floating panel.
		.toolbar(inspecting == nil && !managingSources ? .visible : .hidden, for: .tabBar)
	}

	// MARK: Chrome

	private var toolbarButtons: some View {
		HStack(spacing: 8) {
			Button {
				Haptics.tap()
				managingSources = true
			} label: {
				Image(systemName: "plus")
					.font(.system(size: 15, weight: .semibold))
					.foregroundStyle(Color.inkPrimary)
					.glassCircle(size: 34)
			}
			.accessibilityLabel(t("sources.title"))

			reloadButton
		}
	}

	private var reloadButton: some View {
		Button {
			Task { await model.load() }
		} label: {
			Image(systemName: "arrow.clockwise")
				.font(.system(size: 15, weight: .semibold))
				.foregroundStyle(Color.inkPrimary)
				.glassCircle(size: 34)
		}
	}

	private var searchField: some View {
		HStack(spacing: 8) {
			Image(systemName: "magnifyingglass")
				.font(.system(size: 13, weight: .semibold))
				.foregroundStyle(Color.inkSecondary)
			TextField(t("apps.search"), text: $model.query)
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

	private func sourceHeader(_ entry: LoadedSource, count: Int) -> some View {
		HStack(spacing: 6) {
			SectionLabel(text: entry.title)
			Badge(text: "\(count)", tone: .brand)
			Spacer(minLength: 0)
		}
	}

	// MARK: States

	private var loadingState: some View {
		VStack(spacing: 12) {
			ProgressView().controlSize(.large)
			Text(t("apps.loading"))
				.font(.system(size: 13))
				.foregroundStyle(Color.inkSecondary)
		}
		.frame(maxWidth: .infinity)
		.padding(.vertical, 44)
		.card()
	}

	private func failureState(_ message: String) -> some View {
		VStack(spacing: 10) {
			GlyphTile(systemName: "wifi.slash", tint: .warn, size: 50)
			Text(t("apps.failed"))
				.font(.system(size: 16, weight: .semibold))
				.foregroundStyle(Color.inkPrimary)
			Text(message)
				.font(.system(size: 12))
				.foregroundStyle(Color.inkSecondary)
				.multilineTextAlignment(.center)
			Button {
				Task { await model.load() }
			} label: {
				Text(t("apps.tryAgain"))
					.font(.system(size: 14, weight: .semibold))
					.foregroundStyle(.white)
					.padding(.horizontal, 22)
					.padding(.vertical, 9)
					.background(Capsule().fill(LinearGradient.brand))
			}
			.padding(.top, 2)
		}
		.frame(maxWidth: .infinity)
		.padding(.vertical, 30)
		.card()
	}

	private var emptyState: some View {
		VStack(spacing: 8) {
			GlyphTile(systemName: "magnifyingglass", size: 46)
			Text(t("apps.noMatches"))
				.font(.system(size: 15, weight: .semibold))
				.foregroundStyle(Color.inkPrimary)
		}
		.frame(maxWidth: .infinity)
		.padding(.vertical, 34)
		.card()
	}

	// MARK: Row

	private func row(for app: SourceApp) -> some View {
		HStack(spacing: 12) {
			icon(for: app)

			VStack(alignment: .leading, spacing: 3) {
				Text(app.name)
					.font(.system(size: 15, weight: .semibold))
					.foregroundStyle(Color.inkPrimary)
					.lineLimit(1)

				if let developer = app.developerName {
					Text(developer)
						.font(.system(size: 11))
						.foregroundStyle(Color.inkSecondary)
						.lineLimit(1)
				}

				if let subtitle = app.subtitle {
					Text(subtitle)
						.font(.system(size: 11))
						.foregroundStyle(Color.inkSecondary)
						.lineLimit(1)
				}
			}

			Spacer(minLength: 8)

			VStack(alignment: .trailing, spacing: 5) {
				// Fetching is always green; the colour shifts towards purple
				// only once the app moves further down the pipeline.
				GetButton(
					id: app.bundleIdentifier,
					downloadURL: app.downloadLink,
					fileName: app.suggestedFileName
				)

				HStack(spacing: 4) {
					if let version = app.displayVersion {
						// Some feeds ship git-describe strings; keep them short.
						Text(version.count > 10 ? String(version.prefix(10)) + "…" : version)
					}
					if let size = app.displaySize {
						Text("·")
						Text(size)
					}
				}
				.font(.system(size: 10))
				.foregroundStyle(Color.inkSecondary)
				.lineLimit(1)
				.fixedSize(horizontal: true, vertical: false)
			}
		}
		.card(padding: 11)
	}

	@ViewBuilder
	private func icon(for app: SourceApp) -> some View {
		CachedImage(url: app.iconLink) {
			ZStack {
				Color.brandSoft
				Image(systemName: "square.dashed")
					.font(.system(size: 18, weight: .medium))
					.foregroundStyle(Color.brand)
			}
		}
		.frame(width: 46, height: 46)
		.clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
	}
}
