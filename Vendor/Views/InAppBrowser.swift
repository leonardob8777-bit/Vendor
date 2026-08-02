//
//  InAppBrowser.swift
//  Vendor
//
//  Every outbound link opens here rather than handing the user to Safari, so
//  they stay inside Vendor. SFSafariViewController keeps Safari's engine,
//  cookies isolation and Reader support without leaving the app.
//

import SwiftUI
import SafariServices

struct InAppBrowser: UIViewControllerRepresentable {
	let url: URL

	func makeUIViewController(context: Context) -> SFSafariViewController {
		let config = SFSafariViewController.Configuration()
		config.entersReaderIfAvailable = false
		config.barCollapsingEnabled = true

		let controller = SFSafariViewController(url: url, configuration: config)
		controller.preferredControlTintColor = UIColor(Color.brand)
		controller.dismissButtonStyle = .close
		return controller
	}

	func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}

/// Wraps a URL so it can drive `.sheet(item:)`.
struct BrowserLink: Identifiable {
	let id = UUID()
	let url: URL
}

extension View {
	/// Presents `link` in the in-app browser.
	func inAppBrowser(_ link: Binding<BrowserLink?>) -> some View {
		sheet(item: link) { target in
			InAppBrowser(url: target.url)
				.ignoresSafeArea()
		}
	}
}
