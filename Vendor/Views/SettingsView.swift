//
//  SettingsView.swift
//  Vendor
//
//  Follows the floating-window pattern the rest of the app uses: no veil, blur
//  handled by the caller through `Screen`, tab bar hidden while it is open, and
//  the bottom safe area ignored so hiding that bar cannot move the panel. Same
//  shell as SourcesSheet, this app's other multi-section floating panel.
//

import SwiftUI

/// Not nested inside the view: `VendorApp` reads it too, to decide what
/// `.preferredColorScheme` the whole window gets before `RootTabView` exists.
enum AppearanceOption: String, CaseIterable, Identifiable {
	case system, light, dark

	var id: String { rawValue }

	/// `nil` is what tells SwiftUI to stop overriding and follow the system
	/// again — there is no separate "unset" case to fall back to.
	var colorScheme: ColorScheme? {
		switch self {
		case .system: return nil
		case .light:  return .light
		case .dark:   return .dark
		}
	}

	var title: String {
		switch self {
		case .system: return t("settings.appearance.system")
		case .light:  return t("settings.appearance.light")
		case .dark:   return t("settings.appearance.dark")
		}
	}

	var glyph: String {
		switch self {
		case .system: return "circle.lefthalf.filled"
		case .light:  return "sun.max"
		case .dark:   return "moon"
		}
	}
}

/// One licence Vendor is obliged to carry, and the file it lives in.
struct LicenseFile: Identifiable {
	let id: String
	let displayName: String
	let licence: String
}

struct SettingsView: View {
	/// Called on close.
	var dismiss: () -> Void

	@AppStorage("appearanceOverride") private var appearanceOverride = AppearanceOption.system.rawValue
	@AppStorage("appLockEnabled") private var appLockEnabled = false
	/// Not read directly — its presence keeps this view subscribed to
	/// `Localizer.shared`, so every `t(...)` call below redraws when the
	/// language flips.
	@ObservedObject private var localizer = Localizer.shared
	@State private var browsing: BrowserLink?
	@State private var viewingLicense: LicenseFile?
	@State private var cacheCleared = false

	private let telegramURL = URL(string: "https://t.me/LBsignapp")!
	private let websiteURL  = URL(string: "https://leonardob8777-bit.github.io/")!

	private let bundledLicenses: [LicenseFile] = [
		LicenseFile(id: "Zsign",      displayName: "Zsign",      licence: "MIT"),
		LicenseFile(id: "IDeviceKit", displayName: "IDeviceKit", licence: "MIT"),
		LicenseFile(id: "OpenSSL",    displayName: "OpenSSL",    licence: "Apache-2.0"),
	]

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
		.inAppBrowser($browsing)
		// A second floating panel over this one, the same way GuideDetailSheet
		// stacks over the guide list — the licence text is long enough that it
		// needs the full pane, not a popover squeezed into this one's scroll.
		.overlay {
			if let viewingLicense {
				LicenseSheet(license: viewingLicense) { self.viewingLicense = nil }
					.transition(.opacity)
			}
		}
		.animation(.easeInOut(duration: 0.25), value: viewingLicense?.id)
	}

	private var panel: some View {
		ZStack(alignment: .topTrailing) {
			ScrollView {
				VStack(alignment: .leading, spacing: 18) {
					header
					appearanceSection
					securitySection
					aboutSection
					linksSection
					openSourceSection
					storageSection
				}
				.padding(.horizontal, 18)
				.padding(.top, 22)
				.padding(.bottom, 26)
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

	// MARK: Header

	private var header: some View {
		VStack(alignment: .leading, spacing: 10) {
			GlyphTile(systemName: "gearshape", size: 46)

			Text(t("settings.title"))
				.font(.system(size: 22, weight: .bold))
				.foregroundStyle(Color.inkPrimary)

			Text(t("settings.detail"))
				.font(.system(size: 13))
				.foregroundStyle(Color.inkSecondary)
				.fixedSize(horizontal: false, vertical: true)
		}
		.padding(.trailing, 40) // clears the close button
	}

	// MARK: Appearance

	private var appearanceSection: some View {
		VStack(alignment: .leading, spacing: 8) {
			SectionLabel(text: t("settings.appearance"))
			VStack(spacing: 8) {
				ForEach(AppearanceOption.allCases) { option in
					appearanceRow(option)
				}
			}
		}
	}

	private func appearanceRow(_ option: AppearanceOption) -> some View {
		let selected = appearanceOverride == option.rawValue

		return Button {
			Haptics.tap()
			withAnimation(.easeInOut(duration: 0.2)) { appearanceOverride = option.rawValue }
		} label: {
			HStack(spacing: 11) {
				Image(systemName: option.glyph)
					.font(.system(size: 15, weight: .semibold))
					.foregroundStyle(selected ? Color.brand : Color.inkSecondary)
					.frame(width: 20)

				Text(option.title)
					.font(.system(size: 14, weight: .medium))
					.foregroundStyle(Color.inkPrimary)

				Spacer(minLength: 0)

				Image(systemName: selected ? "largecircle.fill.circle" : "circle")
					.font(.system(size: 17))
					.foregroundStyle(selected ? Color.brand : Color.inkSecondary)
			}
			.padding(.horizontal, 13)
			.padding(.vertical, 11)
			.background {
				if selected {
					RoundedRectangle(cornerRadius: 14, style: .continuous)
						.fill(Color.brandSoft)
				} else {
					RoundedRectangle(cornerRadius: 14, style: .continuous)
						.fill(.ultraThinMaterial)
				}
			}
			.overlay(
				RoundedRectangle(cornerRadius: 14, style: .continuous)
					.strokeBorder(
						selected ? Color.brand.opacity(0.45) : Color.clear,
						lineWidth: 1
					)
			)
		}
		.buttonStyle(.plain)
	}

	// MARK: Security

	private var securitySection: some View {
		VStack(alignment: .leading, spacing: 8) {
			SectionLabel(text: t("settings.security"))
			HStack(spacing: 12) {
				GlyphTile(systemName: "faceid", size: 40)
				VStack(alignment: .leading, spacing: 2) {
					Text(t("settings.appLock"))
						.font(.system(size: 13, weight: .semibold))
						.foregroundStyle(Color.inkPrimary)
					Text(
						AppLock.shared.canAuthenticate()
							? t("settings.appLockDetail")
							: t("settings.appLockUnavailable")
					)
					.font(.system(size: 11))
					.foregroundStyle(Color.inkSecondary)
					.fixedSize(horizontal: false, vertical: true)
				}
				Spacer(minLength: 8)
				Toggle("", isOn: $appLockEnabled)
					.labelsHidden()
					.tint(.brand)
					.disabled(!AppLock.shared.canAuthenticate())
			}
			.padding(10)
			.background(.ultraThinMaterial)
			.clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
		}
	}

	// MARK: About

	/// Read live rather than typed in: a hand-typed string is the kind of
	/// thing that quietly stops matching the day the build number bumps
	/// and nobody remembers to come back here.
	private var appVersion: String {
		Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
	}

	private var buildNumber: String {
		Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
	}

	private var aboutSection: some View {
		VStack(alignment: .leading, spacing: 8) {
			SectionLabel(text: t("settings.about"))
			HStack(spacing: 12) {
				GlyphTile(systemName: "app.badge", size: 42)
				VStack(alignment: .leading, spacing: 2) {
					Text("Vendor")
						.font(.system(size: 14, weight: .semibold))
						.foregroundStyle(Color.inkPrimary)
					Text(String(format: t("settings.versionFormat"), appVersion, buildNumber))
						.font(.system(size: 12))
						.foregroundStyle(Color.inkSecondary)
				}
				Spacer(minLength: 0)
			}
			.padding(10)
			.background(.ultraThinMaterial)
			.clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
		}
	}

	// MARK: Links

	private var linksSection: some View {
		VStack(alignment: .leading, spacing: 8) {
			SectionLabel(text: t("settings.links"))
			linkRow(
				icon: "paperplane.fill", tint: .telegram,
				title: t("settings.telegram"), detail: t("home.telegramDetail"),
				url: telegramURL
			)
			linkRow(
				icon: "globe", tint: .brand,
				title: t("settings.website"), detail: t("home.websiteDetail"),
				url: websiteURL
			)
		}
	}

	private func linkRow(icon: String, tint: Color, title: String, detail: String, url: URL) -> some View {
		Button {
			Haptics.tap()
			browsing = BrowserLink(url: url)
		} label: {
			HStack(spacing: 10) {
				GlyphTile(systemName: icon, tint: tint, size: 40)
				VStack(alignment: .leading, spacing: 1) {
					Text(title)
						.font(.system(size: 13, weight: .semibold))
						.foregroundStyle(Color.inkPrimary)
					Text(detail)
						.font(.system(size: 11))
						.foregroundStyle(Color.inkSecondary)
						.lineLimit(1)
				}
				Spacer(minLength: 0)
				Image(systemName: "arrow.up.right")
					.font(.system(size: 11, weight: .bold))
					.foregroundStyle(Color.inkSecondary)
			}
			.padding(10)
			.background(.ultraThinMaterial)
			.clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
		}
		.buttonStyle(.plain)
	}

	// MARK: Open source

	private var openSourceSection: some View {
		VStack(alignment: .leading, spacing: 8) {
			SectionLabel(text: t("settings.openSource"))
			Text(t("settings.openSourceDetail"))
				.font(.system(size: 12))
				.foregroundStyle(Color.inkSecondary)
				.fixedSize(horizontal: false, vertical: true)

			ForEach(bundledLicenses) { license in
				Button {
					Haptics.tap()
					viewingLicense = license
				} label: {
					HStack(spacing: 10) {
						Image(systemName: "doc.text")
							.font(.system(size: 13, weight: .light))
							.foregroundStyle(Color.mint)
						VStack(alignment: .leading, spacing: 1) {
							Text(license.displayName)
								.font(.system(size: 13, weight: .medium))
								.foregroundStyle(Color.inkPrimary)
							Text(license.licence)
								.font(.system(size: 10))
								.foregroundStyle(Color.inkSecondary)
						}
						Spacer(minLength: 0)
						Image(systemName: "chevron.right")
							.font(.system(size: 11, weight: .semibold))
							.foregroundStyle(Color.inkSecondary)
					}
					.padding(10)
					.background(.ultraThinMaterial)
					.clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
				}
				.buttonStyle(.plain)
			}
		}
	}

	// MARK: Storage

	/// The only cache in the app with no eviction of its own — artwork just
	/// accumulates in `Caches/Artwork` for as long as Vendor is installed.
	/// One button to reclaim it belongs here now that there is a Settings
	/// screen to put it on.
	private var storageSection: some View {
		VStack(alignment: .leading, spacing: 8) {
			SectionLabel(text: t("settings.storage"))
			Text(t("settings.storageDetail"))
				.font(.system(size: 12))
				.foregroundStyle(Color.inkSecondary)
				.fixedSize(horizontal: false, vertical: true)

			Button(action: clearCache) {
				HStack(spacing: 8) {
					Image(systemName: cacheCleared ? "checkmark.circle.fill" : "trash")
						.font(.system(size: 12, weight: .semibold))
					Text(cacheCleared ? t("settings.cacheCleared") : t("settings.clearCache"))
						.font(.system(size: 13, weight: .semibold))
				}
				.foregroundStyle(cacheCleared ? Color.ok : Color.bad)
				.frame(maxWidth: .infinity)
				.padding(.vertical, 11)
				.background(.ultraThinMaterial)
				.clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
			}
			.buttonStyle(.plain)
			.disabled(cacheCleared)
		}
	}

	private func clearCache() {
		Haptics.tap()
		ImageCache.shared.clear()
		withAnimation(.easeInOut(duration: 0.2)) { cacheCleared = true }
		Task {
			try? await Task.sleep(nanoseconds: 2_000_000_000)
			withAnimation(.easeInOut(duration: 0.2)) { cacheCleared = false }
		}
	}
}
