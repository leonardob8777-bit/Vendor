//
//  ShareSheet.swift
//  Vendor
//
//  Presents UIActivityViewController from the active window, for the same
//  reason DocumentPicker goes through UIKit: the SwiftUI wrapper rebuilds its
//  configuration on every body pass, and these screens never stop animating.
//

import UIKit

@MainActor
enum ShareSheet {

	static func present(items: [Any]) {
		guard let presenter = topViewController() else { return }

		let controller = UIActivityViewController(
			activityItems: items,
			applicationActivities: nil
		)

		// iPad refuses to present a popover with no anchor.
		if let popover = controller.popoverPresentationController {
			popover.sourceView = presenter.view
			popover.sourceRect = CGRect(
				x: presenter.view.bounds.midX,
				y: presenter.view.bounds.midY,
				width: 0, height: 0
			)
			popover.permittedArrowDirections = []
		}

		presenter.present(controller, animated: true)
	}

	private static func topViewController() -> UIViewController? {
		let scene = UIApplication.shared.connectedScenes
			.compactMap { $0 as? UIWindowScene }
			.first { $0.activationState == .foregroundActive }

		guard var top = scene?.keyWindow?.rootViewController else { return nil }
		while let presented = top.presentedViewController {
			top = presented
		}
		return top
	}
}
