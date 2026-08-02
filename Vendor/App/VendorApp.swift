//
//  VendorApp.swift
//  Vendor
//

import SwiftUI

@main
struct VendorApp: App {
	var body: some Scene {
		WindowGroup {
			RootTabView()
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
