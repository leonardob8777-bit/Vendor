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

final class AppsViewModel: ObservableObject {
	enum State {
		case loading
		case loaded([LoadedSource])
		case failed(String)
	}

	@Published private(set) var state: State = .loading
	/// Repositories that were added but could not be read this time, by name.
	@Published private(set) var unreachable: [String] = []
	@Published var query = ""

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

/// How a repository's apps are ordered on screen. Session-only: nobody has
/// asked for this to survive a relaunch, and persisting it would mean a
/// migration path the day the sort list grows past three cases.
private enum AppSortOption: CaseIterable, Hashable {
	case feed, name, size

	var title: String {
		switch self {
		case .feed: return t("apps.sortFeed")
		case .name: return t("apps.sortName")
		case .size: return t("apps.sortSize")
		}
	}
}

struct AppsView: View {
	@StateObject private var model = AppsViewModel()
	@State private var inspecting: AppDetail?
	@State private var managingSources = false
	@State private var sortOption: AppSortOption = .feed
	/// Repositories folded away for this session, by `LoadedSource.id`. One of
	/// the shipped ones runs past eight thousand entries, and building that
	/// many rows is not something a Lazy stack alone saves you from — the
	/// section has to be skipped, not just laid out off-screen.
	@State private var collapsedSources: Set<String> = []
	/// Not read directly — its presence keeps this view subscribed to
	/// `Localizer.shared`, so every `t(...)` call below redraws when the
	/// language flips.
	@ObservedObject private var localizer = Localizer.shared

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
			if !model.query.isEmpty { searchSummary }

			// A heading of its own: without one these sat above the first
			// repository's header and read as belonging to it, which is the one
			// thing they are not.
			SectionLabel(text: t("apps.featured"))

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
				//
				// Indexed rather than keyed on the name, the same as the guide
				// blocks. A repository is named by its feed, and falls back to its
				// host when the feed does not say — so two of them added from one
				// host, or two that report the same name, hand `ForEach` a
				// repeated id. Losing a row there loses exactly the message this
				// list exists to deliver.
				ForEach(Array(model.unreachable.enumerated()), id: \.offset) { _, name in
					CalloutRow(text: String(format: t("apps.sourceFailed"), name))
				}

				let sections = loaded.map { ($0, model.matches($0.source)) }
					.filter { !$0.1.isEmpty }

				if sections.isEmpty {
					emptyState(query: model.query)
				} else {
					// Lazy, not a plain VStack: one of the shipped repositories
					// lists over eight thousand apps, and building every row up
					// front freezes the tab on arrival.
					ForEach(sections, id: \.0.id) { entry, apps in
						sourceHeader(entry, count: apps.count)
						// Collapsed sections skip the ForEach entirely rather than
						// hiding it — a LazyVStack still has to lay out whatever it
						// is handed the moment it scrolls near, and eight thousand
						// rows behind one folded header is exactly the case this
						// exists for.
						if !collapsedSources.contains(entry.id) {
							LazyVStack(spacing: 8) {
								ForEach(sortedApps(apps)) { app in
									AppsRow(app: app) { inspecting = AppDetail(app) }
										.scrollEdgeSoftening()
								}
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
		.tabBarVisibility(inspecting == nil && !managingSources)
	}

	// MARK: Chrome

	private var toolbarButtons: some View {
		HStack(spacing: 8) {
			sortMenu

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

	private var sortMenu: some View {
		Menu {
			Picker(t("apps.sort"), selection: $sortOption) {
				ForEach(AppSortOption.allCases, id: \.self) { option in
					Text(option.title).tag(option)
				}
			}
		} label: {
			Image(systemName: "arrow.up.arrow.down")
				.font(.system(size: 15, weight: .semibold))
				.foregroundStyle(Color.inkPrimary)
				.glassCircle(size: 34)
		}
		.accessibilityLabel(t("apps.sort"))
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
		// Not `apps.tryAgain`: "Try again" answers a failure, and this control
		// is there whether anything failed or not.
		.accessibilityLabel(t("apps.reload"))
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

	/// Count and a Clear button, shown under the field once there is a query
	/// to describe. Silent otherwise — a row that only ever reads "0 results"
	/// or repeats the obvious while empty earns its place less than not
	/// being there.
	private var searchSummary: some View {
		HStack(spacing: 8) {
			Text(resultsText)
				.font(.system(size: 12, weight: .medium))
				.foregroundStyle(Color.inkSecondary)
			Spacer(minLength: 8)
			Button {
				Haptics.tap()
				model.query = ""
			} label: {
				Text(t("apps.clearSearch"))
					.font(.system(size: 12, weight: .semibold))
					.foregroundStyle(Color.brand)
			}
		}
	}

	private var resultsText: String {
		guard case .loaded(let loaded) = model.state else { return "" }
		let count = loaded.reduce(0) { $0 + model.matches($1.source).count }
		return count == 1 ? t("apps.resultsOne") : String(format: t("apps.results"), count)
	}

	private func sourceHeader(_ entry: LoadedSource, count: Int) -> some View {
		let collapsed = collapsedSources.contains(entry.id)
		return Button {
			Haptics.tap()
			withAnimation(.easeInOut(duration: 0.2)) {
				if collapsed {
					collapsedSources.remove(entry.id)
				} else {
					collapsedSources.insert(entry.id)
				}
			}
		} label: {
			HStack(spacing: 6) {
				SectionLabel(text: entry.title)
				Badge(text: "\(count)", tone: .brand)
				Spacer(minLength: 0)
				Image(systemName: "chevron.down")
					.font(.system(size: 11, weight: .bold))
					.foregroundStyle(Color.inkSecondary)
					.rotationEffect(.degrees(collapsed ? -90 : 0))
			}
			.contentShape(Rectangle())
		}
		.buttonStyle(.plain)
		.accessibilityLabel(collapsed ? t("apps.showApps") : t("apps.hideApps"))
	}

	/// As published, alphabetical, or biggest first. Session-only — there is
	/// nothing here worth a migration path yet.
	private func sortedApps(_ apps: [SourceApp]) -> [SourceApp] {
		switch sortOption {
		case .feed:
			return apps
		case .name:
			return apps.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
		case .size:
			return apps.sorted { rawSize($0) > rawSize($1) }
		}
	}

	/// Bytes behind `displaySize`, for sorting rather than showing — an app
	/// the feed never reported a size for sinks to the bottom rather than
	/// breaking the comparator.
	private func rawSize(_ app: SourceApp) -> Int64 {
		app.versions?.first?.size ?? app.size ?? 0
	}

	// MARK: States

	private var loadingState: some View {
		VStack(spacing: 8) {
			ForEach(0..<5, id: \.self) { index in
				AppsRowSkeleton(index: index)
			}
		}
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

	/// The generic heading covers both causes — nothing loaded, or nothing
	/// matched — and only the second one has a query worth quoting back, so
	/// the detail line only appears when there is one.
	private func emptyState(query: String) -> some View {
		VStack(spacing: 8) {
			GlyphTile(systemName: "magnifyingglass", size: 46)
			Text(t("apps.noMatches"))
				.font(.system(size: 15, weight: .semibold))
				.foregroundStyle(Color.inkPrimary)
			if !query.isEmpty {
				Text(String(format: t("apps.noMatchesDetail"), query))
					.font(.system(size: 12))
					.foregroundStyle(Color.inkSecondary)
					.multilineTextAlignment(.center)
			}
		}
		.frame(maxWidth: .infinity)
		.padding(.vertical, 34)
		.card()
	}
}
