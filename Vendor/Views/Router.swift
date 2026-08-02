//
//  Router.swift
//  Vendor
//
//  The little bit of navigation state that has to be shared. A row in Apps
//  needs to be able to send you to the package it just downloaded, which lives
//  on another tab, so the selected tab cannot stay private to RootTabView.
//

import SwiftUI
import Observation

@Observable
@MainActor
final class Router {
	static let shared = Router()

	var tab: RootTabView.Tab = .home

	/// Package the IPA tab should open the next time it is shown. Cleared as
	/// soon as it has been acted on, so coming back to the tab later does not
	/// re-open a card the user has since closed.
	var revealPackage: UUID?

	private init() {}

	/// Switches to the IPA tab with `package` expanded.
	func reveal(_ package: UUID) {
		revealPackage = package
		tab = .ipa
	}
}
