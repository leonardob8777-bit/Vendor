//
//  AppsView.swift
//  Vendor
//

import SwiftUI

@Observable
final class AppsViewModel {
	enum State {
		case loading
		case loaded(AppSource)
		case failed(String)
	}

	private(set) var state: State = .loading
	var query = ""

	func load() async {
		state = .loading
		do {
			let source = try await SourceLoader.load()
			state = .loaded(source)
		} catch {
			state = .failed(error.localizedDescription)
		}
	}

	func matches(_ source: AppSource) -> [SourceApp] {
		guard !query.isEmpty else { return source.apps }
		return source.apps.filter {
			$0.name.localizedCaseInsensitiveContains(query)
			|| ($0.developerName?.localizedCaseInsensitiveContains(query) ?? false)
			|| ($0.subtitle?.localizedCaseInsensitiveContains(query) ?? false)
		}
	}
}

struct AppsView: View {
	@State private var model = AppsViewModel()
	@State private var inspecting: AppDetail?

	var body: some View {
		Screen(
			t("tab.apps"),
			toolbar: AnyView(reloadButton),
			// Through `Screen` rather than a `.blur` on the whole thing: the
			// aurora ignores the safe area, so blurring the screen as a whole
			// leaves the strip beside the Dynamic Island outside the blurred
			// layer and the join reads as a black line across the top.
			contentBlur: inspecting == nil ? 0 : 16
		) {
			searchField

			// Pinned above the remote source so it stays first whatever the
			// feed returns.
			ForEach(FeaturedApp.all) { featured in
				FeaturedAppRow(app: featured) { inspecting = AppDetail(featured) }
				.padding(.top, 4)
			}

			switch model.state {
			case .loading:
				loadingState
			case .failed(let message):
				failureState(message)
			case .loaded(let source):
				let apps = model.matches(source)
				if apps.isEmpty {
					emptyState
				} else {
					sourceHeader(source, count: apps.count)
					VStack(spacing: 8) {
						ForEach(apps) { app in
							Button { inspecting = AppDetail(app) } label: {
								row(for: app)
							}
							.buttonStyle(.plain)
						}
					}
				}
			}
		}
		.task { await model.load() }
		.refreshable { await model.load() }
		// Flat curve, and applied to the screen rather than over the overlay: the
		// blur has to reach 16 and stop. Left to the panel's own animation it
		// rides a spring, and a spring on a blur radius overshoots and settles
		// back — the softening visibly bounces.
		.animation(.easeInOut(duration: 0.25), value: inspecting == nil)
		// Presented as an overlay rather than a sheet: iOS dims and shrinks the
		// presenting view behind a sheet, and the design calls for the app
		// list to stay visible — just blurred.
		.overlay {
			if let detail = inspecting {
				AppDetailSheet(detail: detail) { inspecting = nil }
					// Fade only. A scale transition means the panel grows into
					// place, and at nearly full-screen size that reads as the
					// window stretching rather than as it arriving.
					.transition(.opacity)
			}
		}
		.animation(.easeInOut(duration: 0.22), value: inspecting?.id)
		// The tab bar is the TabView's, so it draws above anything a tab lays
		// over its own content — sharp chrome on top of a floating panel.
		.toolbar(inspecting == nil ? .visible : .hidden, for: .tabBar)
	}

	// MARK: Chrome

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

	private func sourceHeader(_ source: AppSource, count: Int) -> some View {
		HStack(spacing: 6) {
			SectionLabel(text: source.name ?? t("apps.source"))
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
