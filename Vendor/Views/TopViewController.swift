//
//  TopViewController.swift
//  Vendor
//
//  Finding the controller to present from, for the two places that still have
//  to reach into UIKit: the document picker and the share sheet.
//
//  It lived in both of them, letter for letter. Walking the scene graph is the
//  kind of thing that needs revisiting when iOS changes how windows work, and
//  two copies means finding out that only one of them was updated.
//

import UIKit

extension UIApplication {

	/// The frontmost presented controller, or nil when there is no active scene.
	static func topViewController() -> UIViewController? {
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
