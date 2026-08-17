//
//  VendorApp.swift
//  Vendor
//

import SwiftUI

@main
struct VendorApp: App {
	// Read by the same key Settings' Appearance picker writes to. This is the
	// one place the stored preference actually becomes a rendered colour
	// scheme — `App` is its own property-wrapper context, separate from the
	// views inside the window, so it needs its own `@AppStorage` rather than
	// reading SettingsView's.
	@AppStorage("appearanceOverride") private var appearanceOverride = AppearanceOption.system.rawValue

	var body: some Scene {
		WindowGroup {
			RootTabView()
				// `nil` for "System" lets SwiftUI fall back to following the
				// device again rather than pinning to whatever it last resolved to.
				.preferredColorScheme((AppearanceOption(rawValue: appearanceOverride) ?? .system).colorScheme)
				.task {
					// The install certificate is fetched here rather than when
					// Install is tapped: on demand it put a network round trip
					// between the tap and the system's install prompt, which
					// read as the app hanging.
					await Installer.shared.prepare()
				}
		}
	}
}
