//
//  Haptics.swift
//  Vendor
//
//  Physical feedback for the moments that matter: a package landing, a
//  signature finishing, an install starting. Kept in one place so the app is
//  consistent about when it speaks through the Taptic engine and when it
//  stays quiet.
//

import UIKit

@MainActor
enum Haptics {
	/// Generators are reused: building one per event misses the first tap,
	/// because the engine has not warmed up yet.
	private static let impact = UIImpactFeedbackGenerator(style: .medium)
	private static let notice = UINotificationFeedbackGenerator()

	static func tap() {
		impact.impactOccurred()
		impact.prepare()
	}

	static func success() {
		notice.notificationOccurred(.success)
		notice.prepare()
	}

	static func failure() {
		notice.notificationOccurred(.error)
		notice.prepare()
	}
}
