//
//  RootTabView.swift
//  Vendor
//

import SwiftUI
import Combine

struct RootTabView: View {
	enum Tab: Hashable {
		case home, apps, ipa, certificates, guide

		var title: String {
			switch self {
			case .home:         return t("tab.home")
			case .apps:         return t("tab.apps")
			case .ipa:          return t("tab.ipa")
			case .certificates: return t("tab.certificates")
			case .guide:        return t("tab.guide")
			}
		}

		/// Outline symbols with simple geometry — the filled variants read as
		/// heavy blobs at tab-bar size.
		var glyph: String {
			switch self {
			case .home:         return "house"
			case .apps:         return "cube"
			case .ipa:          return "doc.zipper"
			case .certificates: return "shield"
			case .guide:        return "book"
			}
		}
	}

	@ObservedObject private var router = Router.shared
	/// Not read directly — its presence keeps this view subscribed to
	/// `Localizer.shared`, so every `t(...)` call below redraws when the
	/// language flips.
	@ObservedObject private var localizer = Localizer.shared

	init() {
		// The tab bar sizes itself from its item metrics, so a larger label
		// font and roomier icon insets grow the whole bar.
		let item = UITabBarItemAppearance()
		let title: [NSAttributedString.Key: Any] = [
			.font: UIFont.systemFont(ofSize: 12, weight: .semibold)
		]
		item.normal.titleTextAttributes = title
		item.selected.titleTextAttributes = title
		item.normal.iconColor = UIColor(Color.inkPrimary)

		for layout in [item.normal, item.selected] {
			layout.titlePositionAdjustment = UIOffset(horizontal: 0, vertical: 2)
		}

		let appearance = UITabBarAppearance()
		appearance.configureWithDefaultBackground()
		appearance.stackedLayoutAppearance = item
		appearance.inlineLayoutAppearance = item
		appearance.compactInlineLayoutAppearance = item

		UITabBar.appearance().standardAppearance = appearance
		UITabBar.appearance().scrollEdgeAppearance = appearance
	}

	var body: some View {
		TabView(selection: $router.tab) {
			// Home can jump to the other tabs, so it takes the selection.
			HomeView(tab: $router.tab).tag(Tab.home)
				.tabItem { tabLabel(.home) }

			AppsView().tag(Tab.apps)
				.tabItem { tabLabel(.apps) }

			IPAView().tag(Tab.ipa)
				.tabItem { tabLabel(.ipa) }

			CertificatesView().tag(Tab.certificates)
				.tabItem { tabLabel(.certificates) }

			GuideView().tag(Tab.guide)
				.tabItem { tabLabel(.guide) }
		}
		.tint(.brand)
		// One subscription for the app's whole lifetime rather than wiring
		// this into every screen that happens to touch certificates. Fires
		// once immediately with whatever is already imported — `$certificates`
		// is `@Published`, so a new subscriber gets the current value before
		// any future change — which doubles as the launch-time resync, and
		// again on every import or delete after that.
		.onReceive(CertificateStore.shared.$certificates) { certificates in
			CertificateExpiryNotifier.sync(certificates)
		}
	}

	/// iOS substitutes the `.fill` variant for tab symbols unless the label
	/// itself opts out, which is what undoes the thin-line look.
	private func tabLabel(_ tab: Tab) -> some View {
		Label(tab.title, systemImage: tab.glyph)
			.environment(\.symbolVariants, .none)
			.imageScale(.large)
	}
}

// MARK: - Shared chrome

/// Standard screen scaffold. The title is drawn as content rather than as a
/// navigation title — that matches the design and avoids the large empty
/// header strip a `navigationTitle` reserves.
struct Screen<Content: View>: View {
	let title: String
	var toolbar: AnyView?
	/// Softens the screen's own content while a panel floats over it.
	///
	/// Deliberately applied here rather than to the whole screen from outside.
	/// The aurora ignores the safe area, so it paints the strip beneath the
	/// Dynamic Island — which sits outside the bounds of a blur applied to the
	/// screen as a whole. That strip stayed sharp while everything below it went
	/// soft, and the join read as a black line ruled across the top of the
	/// display. Blurring the content and leaving the aurora alone has no seam to
	/// give away: the backdrop is a slow gradient, and blurring it changed
	/// nothing anyone could see.
	var contentBlur: CGFloat = 0
	@ViewBuilder var content: () -> Content

	init(
		_ title: String,
		toolbar: AnyView? = nil,
		contentBlur: CGFloat = 0,
		@ViewBuilder content: @escaping () -> Content
	) {
		self.title = title
		self.toolbar = toolbar
		self.contentBlur = contentBlur
		self.content = content
	}

	var body: some View {
		ScrollView {
			VStack(spacing: 12) {
				HStack(alignment: .center) {
					Text(title)
						.font(.system(size: 28, weight: .bold))
						.foregroundStyle(Color.inkPrimary)
					Spacer(minLength: 8)
					toolbar
				}
				.padding(.bottom, 2)
				// The title softens with everything else once it starts leaving,
				// but stays sharp while the list is at rest at the top.
				.scrollEdgeSoftening()

				content()
			}
			.padding(.horizontal, 16)
			.padding(.top, 6)
			// Clears the floating tab bar, which otherwise overlaps and
			// shows the last card through its material.
			.padding(.bottom, 96)
		}
		.blur(radius: contentBlur)
		.auroraBackground()
	}
}

extension View {

	/// Softens a row as it approaches the top or bottom of its scroll view.
	///
	/// Applied per row rather than as a haze laid over the edges of the screen:
	/// an overlay would blur whatever sat under it even when the list has not
	/// moved, which means the title arrives already out of focus. Keyed to each
	/// row's own position, nothing is touched until it starts to leave.
	///
	/// Still a detail rather than an effect, but with enough weight to be seen
	/// in motion: four points of blur and a third of the opacity. Past this the
	/// edges stop reading as depth and start reading as a rendering fault.
	///
	/// Pass `false` for a row that can grow taller than the scroll view. The
	/// identity phase means "this row is fully clear of both edges", which a row
	/// taller than the viewport never is — so it does not soften on its way past,
	/// it sits blurred permanently. That is what happened to the signing card the
	/// moment it was opened: every field in it, hazy and dimmed, for as long as
	/// it was the thing being read.
	@ViewBuilder
	func scrollEdgeSoftening(_ active: Bool = true) -> some View {
		if #available(iOS 17, *) {
			scrollTransition(.interactive, axis: .vertical) { view, phase in
				view
					.blur(radius: active && !phase.isIdentity ? 4 : 0)
					.opacity(active && !phase.isIdentity ? 0.65 : 1)
			}
		} else {
			self
		}
	}

	/// `.scrollBounceBehavior(.basedOnSize)` is iOS 16.4+; below that a sheet
	/// short enough to fit the screen just rubber-bands like any other.
	@ViewBuilder
	func scrollBounceBehaviorCompat() -> some View {
		if #available(iOS 16.4, *) {
			scrollBounceBehavior(.basedOnSize)
		} else {
			self
		}
	}

	/// `.toolbar(_:for:)` is iOS 16+; below that the tab bar just stays put
	/// under whatever panel is floating over it.
	@ViewBuilder
	func tabBarVisibility(_ visible: Bool) -> some View {
		if #available(iOS 16, *) {
			toolbar(visible ? .visible : .hidden, for: .tabBar)
		} else {
			self
		}
	}
}

/// Rounded tile that holds a glyph, used down the left edge of most rows.
struct GlyphTile: View {
	let systemName: String
	var tint: Color = .brand
	var size: CGFloat = 40

	var body: some View {
		Image(systemName: systemName)
			// Light stroke and a slightly larger glyph: reads as a line icon
			// rather than a solid badge.
			.font(.system(size: size * 0.46, weight: .light))
			.foregroundStyle(tint)
			.frame(width: size, height: size)
			.background(tint.opacity(0.10))
			.overlay(
				RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
					.strokeBorder(tint.opacity(0.16), lineWidth: 0.8)
			)
			.clipShape(RoundedRectangle(cornerRadius: size * 0.3, style: .continuous))
	}
}
