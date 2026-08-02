//
//  DocumentPicker.swift
//  Vendor
//
//  Presents UIDocumentPickerViewController straight from the active window.
//
//  SwiftUI's `.fileImporter` rebuilds its configuration every time the view's
//  body is evaluated, and these screens sit under a backdrop that animates
//  forever — so the body never settles and presenting the picker took seconds.
//  Going through UIKit skips that entirely: the controller is built once, when
//  the button is actually tapped.
//

import UIKit
import UniformTypeIdentifiers

@MainActor
enum DocumentPicker {

	/// Presents the system file picker and hands back what the user chose.
	/// The URLs are security-scoped; callers must open access before reading.
	static func present(
		contentTypes: [UTType],
		allowsMultiple: Bool = false,
		onPick: @escaping ([URL]) -> Void
	) {
		guard let presenter = UIApplication.topViewController() else { return }

		let controller = UIDocumentPickerViewController(
			forOpeningContentTypes: contentTypes,
			asCopy: true
		)
		controller.allowsMultipleSelection = allowsMultiple
		controller.shouldShowFileExtensions = true

		let delegate = Delegate(onPick: onPick)
		controller.delegate = delegate
		// The delegate would otherwise deallocate the moment this call returns.
		objc_setAssociatedObject(controller, &Delegate.key, delegate, .OBJC_ASSOCIATION_RETAIN)

		presenter.present(controller, animated: true)
	}

	// MARK: Plumbing

	private final class Delegate: NSObject, UIDocumentPickerDelegate {
		nonisolated(unsafe) static var key: UInt8 = 0

		private let onPick: ([URL]) -> Void

		init(onPick: @escaping ([URL]) -> Void) {
			self.onPick = onPick
		}

		func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
			onPick(urls)
		}

		func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
			onPick([])
		}
	}

}
