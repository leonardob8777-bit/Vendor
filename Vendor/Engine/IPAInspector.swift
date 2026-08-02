//
//  IPAInspector.swift
//  Vendor
//
//  Reads an .ipa's own Info.plist and icon straight out of the archive, so an
//  imported package shows the app's real name, version and artwork instead of
//  a file name.
//

import Foundation

struct IPAInfo {
	let displayName: String?
	let bundleIdentifier: String?
	let version: String?
	let iconData: Data?
	/// First URL scheme the bundle registers, when it registers one. This is
	/// the only public way to launch another app, so it decides whether Vendor
	/// can offer to open it once installed.
	let urlScheme: String?
}

enum IPAInspector {

	static func inspect(_ package: URL) -> IPAInfo? {
		guard let archive = try? Data(contentsOf: package, options: .mappedIfSafe) else { return nil }
		let entries = ZipReader.entries(of: package)
		guard !entries.isEmpty else { return nil }

		// Payload/<Something>.app/Info.plist — the one at the bundle root, not
		// the ones belonging to nested frameworks or extensions.
		guard let infoEntry = entries
			.filter({ $0.path.hasSuffix(".app/Info.plist") && $0.path.hasPrefix("Payload/") })
			.min(by: { $0.path.components(separatedBy: "/").count < $1.path.components(separatedBy: "/").count })
		else { return nil }

		guard let plistData = ZipReader.contents(of: infoEntry, in: archive),
			  let plist = try? PropertyListSerialization.propertyList(
				from: plistData, options: [], format: nil
			  ) as? [String: Any]
		else { return nil }

		let bundleRoot = infoEntry.path.replacingOccurrences(of: "Info.plist", with: "")

		return IPAInfo(
			displayName: (plist["CFBundleDisplayName"] as? String)
				?? (plist["CFBundleName"] as? String),
			bundleIdentifier: plist["CFBundleIdentifier"] as? String,
			version: (plist["CFBundleShortVersionString"] as? String)
				?? (plist["CFBundleVersion"] as? String),
			iconData: iconData(from: plist, bundleRoot: bundleRoot, entries: entries, archive: archive),
			urlScheme: firstURLScheme(in: plist)
		)
	}

	/// Bundles list their schemes under CFBundleURLTypes; the first usable one
	/// is enough to launch the app.
	private static func firstURLScheme(in plist: [String: Any]) -> String? {
		guard let types = plist["CFBundleURLTypes"] as? [[String: Any]] else { return nil }
		for type in types {
			guard let schemes = type["CFBundleURLSchemes"] as? [String] else { continue }
			if let scheme = schemes.first(where: { !$0.isEmpty }) { return scheme }
		}
		return nil
	}

    // MARK: Icon

	private static func iconData(
		from plist: [String: Any],
		bundleRoot: String,
		entries: [ZipEntry],
		archive: Data
	) -> Data? {
		let names = declaredIconNames(in: plist)

		// Prefer a name the bundle actually declares; the files on disk carry a
		// size and scale suffix, so match by prefix.
		for name in names {
			let candidates = entries.filter {
				$0.path.hasPrefix(bundleRoot + name) && $0.path.hasSuffix(".png")
			}
			if let best = largest(of: candidates),
			   let data = ZipReader.contents(of: best, in: archive) {
				return data
			}
		}

		// Nothing declared: fall back to any AppIcon file sitting at the root
		// of the bundle.
		let fallback = entries.filter {
			$0.path.hasPrefix(bundleRoot)
			&& $0.path.hasSuffix(".png")
			&& $0.path.dropFirst(bundleRoot.count).contains("AppIcon")
			&& !$0.path.dropFirst(bundleRoot.count).contains("/")
		}
		guard let best = largest(of: fallback) else { return nil }
		return ZipReader.contents(of: best, in: archive)
	}

	/// Icon file stems named by the bundle, newest key format first.
	private static func declaredIconNames(in plist: [String: Any]) -> [String] {
		var names: [String] = []

		if let icons = plist["CFBundleIcons"] as? [String: Any],
		   let primary = icons["CFBundlePrimaryIcon"] as? [String: Any] {
			if let files = primary["CFBundleIconFiles"] as? [String] {
				names.append(contentsOf: files)
			}
			if let name = primary["CFBundleIconName"] as? String {
				names.append(name)
			}
		}
		if let files = plist["CFBundleIconFiles"] as? [String] {
			names.append(contentsOf: files)
		}
		if let file = plist["CFBundleIconFile"] as? String {
			names.append(file)
		}
		// Longest first, so "AppIcon60x60" wins over "AppIcon" when both exist.
		return Array(Set(names)).sorted { $0.count > $1.count }
	}

	/// Biggest artwork available, which is the one worth showing.
	private static func largest(of entries: [ZipEntry]) -> ZipEntry? {
		entries.max { $0.uncompressedSize < $1.uncompressedSize }
	}
}
