//
//  BundlePreparer.swift
//  Vendor
//
//  Everything done to an unpacked .app between extraction and signing: artwork
//  swapped, unwanted embedded libraries stripped, and the entitlements file the
//  engine should sign against written out.
//
//  Kept apart from `SigningPipeline` on purpose. The pipeline orchestrates and
//  the engine signs; this is the only place that rewrites the bundle's own
//  contents, so there is one file to read when a package comes out wrong.
//
//  The three metadata overrides are not here — the engine already applies name,
//  identifier and version itself, and rewriting Info.plist for them as well
//  would mean two things editing the same keys.
//

import Foundation
import UIKit

enum BundlePreparerError: LocalizedError {
	case iconUnreadable
	case cannotWriteEntitlements

	var errorDescription: String? {
		switch self {
		case .iconUnreadable:          return t("err.prepare.icon")
		case .cannotWriteEntitlements: return t("err.prepare.entitlements")
		}
	}
}

enum BundlePreparer {

	/// What the pipeline needs to know once preparation is done.
	struct Result {
		/// Entitlements file to sign against, when one had to be written.
		var entitlementsPath: String?
	}

	/// Applies `options` to an already-extracted bundle.
	///
	/// - Parameters:
	///   - bundle: the `.app` directory inside `Payload`.
	///   - iconFile: artwork the user picked, if any.
	///   - profile: the `.mobileprovision` about to be used, read for the
	///     entitlements a new file has to preserve.
	///   - scratch: directory for files that must not end up inside the bundle.
	static func prepare(
		bundle: URL,
		options: SignOptions,
		iconFile: URL?,
		profile: URL,
		scratch: URL
	) throws -> Result {

		if !options.removedComponents.isEmpty {
			removeComponents(options.removedComponents, from: bundle)
		}

		if let iconFile {
			try applyIcon(iconFile, to: bundle)
		}

		var result = Result()
		if options.enableJIT {
			result.entitlementsPath = try writeEntitlements(profile: profile, into: scratch).path
		}
		return result
	}

	// MARK: Entitlements

	/// Writes the profile's entitlements back out with `get-task-allow` added.
	///
	/// Handing the engine a file with only the extra key would sign the app with
	/// only that key: the entitlements file replaces the set, it does not add to
	/// it. An app stripped of its application-identifier does not launch.
	private static func writeEntitlements(profile: URL, into scratch: URL) throws -> URL {
		var entitlements = ProvisioningProfile.read(at: profile)?.entitlements ?? [:]
		entitlements["get-task-allow"] = true

		let url = scratch.appendingPathComponent("entitlements.plist")
		do {
			let data = try PropertyListSerialization.data(
				fromPropertyList: entitlements, format: .xml, options: 0
			)
			try data.write(to: url, options: .atomic)
		} catch {
			throw BundlePreparerError.cannotWriteEntitlements
		}
		return url
	}

	// MARK: Icon

	/// Sizes iOS looks for on the home screen, as `<stem>@<scale>x.png`.
	private static let iconSizes: [(stem: String, points: CGFloat, scale: CGFloat)] = [
		("VendorIcon60x60", 60, 2),
		("VendorIcon60x60", 60, 3),
		("VendorIcon76x76", 76, 2),
		("VendorIcon83.5x83.5", 83.5, 2),
	]

	private static func applyIcon(_ source: URL, to bundle: URL) throws {
		guard let data = try? Data(contentsOf: source), let image = UIImage(data: data) else {
			throw BundlePreparerError.iconUnreadable
		}

		for size in iconSizes {
			let pixels = size.points * size.scale
			guard let resized = image.squared(to: pixels), let png = resized.pngData() else { continue }
			let name = "\(size.stem)@\(Int(size.scale))x.png"
			try? png.write(to: bundle.appendingPathComponent(name), options: .atomic)
		}

		let plistURL = bundle.appendingPathComponent("Info.plist")
		guard let data = try? Data(contentsOf: plistURL),
			  var plist = (try? PropertyListSerialization.propertyList(
				from: data, options: [], format: nil)) as? [String: Any]
		else { throw BundlePreparerError.iconUnreadable }

		let phone = ["CFBundlePrimaryIcon": ["CFBundleIconFiles": ["VendorIcon60x60"]]]
		let pad = ["CFBundlePrimaryIcon": ["CFBundleIconFiles": [
			"VendorIcon60x60", "VendorIcon76x76", "VendorIcon83.5x83.5",
		]]]
		plist["CFBundleIcons"] = phone
		plist["CFBundleIcons~ipad"] = pad

		// `CFBundleIconName` points into the compiled asset catalog, and iOS
		// prefers it over any loose file. Left in place the app keeps its
		// original artwork and the new PNGs are simply ignored, which reads as
		// the feature silently doing nothing.
		plist.removeValue(forKey: "CFBundleIconName")
		plist.removeValue(forKey: "CFBundleIconFiles")
		plist.removeValue(forKey: "CFBundleIconFile")

		guard let out = try? PropertyListSerialization.data(
			fromPropertyList: plist, format: .xml, options: 0
		) else { throw BundlePreparerError.iconUnreadable }
		try? out.write(to: plistURL, options: .atomic)
	}

	// MARK: Embedded components

	/// Deletes the named dylibs and frameworks and takes their load commands out
	/// of the executable.
	///
	/// Both halves are needed: deleting the file alone leaves a load command
	/// pointing at nothing, and the app dies at launch instead of starting
	/// without the tweak.
	private static func removeComponents(_ names: [String], from bundle: URL) {
		let fm = FileManager.default
		let frameworks = bundle.appendingPathComponent("Frameworks", isDirectory: true)

		for name in names {
			try? fm.removeItem(at: frameworks.appendingPathComponent(name))
		}

		guard let executable = executableURL(of: bundle) else { return }
		// Matching on the last path component rather than the whole string: a
		// load command may be written @rpath, @executable_path or absolute, and
		// the list the user ticked holds file names.
		let commands = SigningEngine.dylibs(inExecutableAt: executable.path)
		let doomed = commands.filter { command in
			names.contains { name in
				command.hasSuffix("/" + name)
				|| command.contains("/\(name)/")
				|| (command as NSString).lastPathComponent == (name as NSString).deletingPathExtension
			}
		}
		guard !doomed.isEmpty else { return }
		SigningEngine.remove(dylibs: doomed, fromExecutableAt: executable.path)
	}

	private static func executableURL(of bundle: URL) -> URL? {
		let plistURL = bundle.appendingPathComponent("Info.plist")
		guard let data = try? Data(contentsOf: plistURL),
			  let plist = (try? PropertyListSerialization.propertyList(
				from: data, options: [], format: nil)) as? [String: Any],
			  let name = plist["CFBundleExecutable"] as? String
		else { return nil }
		let url = bundle.appendingPathComponent(name)
		return FileManager.default.fileExists(atPath: url.path) ? url : nil
	}
}

private extension UIImage {
	/// Redraws the image as a square of `pixels`, cropping to fill rather than
	/// squashing — an icon stretched to fit is worse than one cropped.
	func squared(to pixels: CGFloat) -> UIImage? {
		let format = UIGraphicsImageRendererFormat()
		format.scale = 1
		format.opaque = false
		let side = CGSize(width: pixels, height: pixels)

		return UIGraphicsImageRenderer(size: side, format: format).image { _ in
			let ratio = max(pixels / size.width, pixels / size.height)
			let scaled = CGSize(width: size.width * ratio, height: size.height * ratio)
			draw(in: CGRect(
				x: (pixels - scaled.width) / 2,
				y: (pixels - scaled.height) / 2,
				width: scaled.width,
				height: scaled.height
			))
		}
	}
}
