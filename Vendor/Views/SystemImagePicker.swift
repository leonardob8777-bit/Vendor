//
//  SystemImagePicker.swift
//  Vendor
//
//  `PhotosPicker` is iOS 16+. This wraps `PHPickerViewController` instead,
//  which does the same job back to iOS 14 and is what `PhotosPicker` itself
//  is built on.
//

import SwiftUI
import PhotosUI

struct SystemImagePicker: UIViewControllerRepresentable {
	/// Called once with the picked image's PNG data, or `nil` if the user
	/// cancelled or the picked item could not be read as an image.
	var onPick: (Data?) -> Void

	func makeUIViewController(context: Context) -> PHPickerViewController {
		var config = PHPickerConfiguration()
		config.filter = .images
		config.selectionLimit = 1
		let picker = PHPickerViewController(configuration: config)
		picker.delegate = context.coordinator
		return picker
	}

	func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

	func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

	final class Coordinator: NSObject, PHPickerViewControllerDelegate {
		let onPick: (Data?) -> Void

		init(onPick: @escaping (Data?) -> Void) {
			self.onPick = onPick
		}

		func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
			picker.dismiss(animated: true)
			guard let provider = results.first?.itemProvider,
				  provider.canLoadObject(ofClass: UIImage.self)
			else {
				onPick(nil)
				return
			}
			provider.loadObject(ofClass: UIImage.self) { [onPick] object, _ in
				let data = (object as? UIImage)?.pngData()
				DispatchQueue.main.async { onPick(data) }
			}
		}
	}
}
