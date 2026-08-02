//
//  FeaturedApp.swift
//  Vendor
//
//  Apps pinned above the remote source. Their details were taken from the
//  Vendor site's own catalogue, so the two stay in step.
//

import SwiftUI

struct FeaturedApp: Identifiable {
	let id: String
	let name: String
	let developer: String
	let summary: String
	/// Chips shown beside the name. More than one is allowed, e.g. HOT + NEW.
	let badges: [(text: String, kind: SiteBadge.Kind)]
	/// Colour washed into the card's corner.
	let glow: Color
	let iconURL: URL?
	/// Artwork shipped with Vendor, for apps whose icon is not hosted anywhere.
	/// Takes precedence over `iconURL` when set.
	var iconAsset: String? = nil
	/// Package shipped inside Vendor, for apps that are not hosted anywhere.
	/// When set, Get copies it straight into Imported instead of downloading.
	var bundledFile: String? = nil
	/// Listed but not yet downloadable. The row shows a Soon chip where the Get
	/// button would be, rather than a button that fetches something missing.
	var comingSoon: Bool = false
	let downloadURL: URL
	/// Bytes, when known.
	let size: Int64?
	/// Version string, when the source publishes one.
	let version: String?

	var displaySize: String? {
		guard let size, size > 0 else { return nil }
		let formatter = ByteCountFormatter()
		formatter.countStyle = .file
		formatter.allowedUnits = [.useMB]
		return formatter.string(fromByteCount: size)
	}
}

extension FeaturedApp {
	/// System tweaking toolkit, distributed as a raw .ipa to sign yourself.
	static let lara = FeaturedApp(
		id: "lara",
		name: "Lara",
		developer: "Leonardo Bt",
		summary: "Toolkit for tweaking iOS system settings and behaviour.",
		badges: [("HOT", .hot)],
		glow: .gold,
		iconURL: URL(string: "https://leonardob8777-bit.github.io/assets/lara.png"),
		iconAsset: "LaraIcon",
		downloadURL: URL(string: "https://leonardob8777-bit.github.io/apps/lara.ipa")!,
		size: 6_928_874,
		version: nil
	)

	/// Tweak runner built on the DarkSword kernel exploit. Open source,
	/// AGPL-3.0, released on GitHub.
	static let cyanide = FeaturedApp(
		id: "cyanide",
		name: "Cyanide",
		developer: "0xjohnnydev",
		summary: "Tweak runner for iOS built on the DarkSword kernel exploit.",
		badges: [("POPULAR", .popular)],
		glow: .brand,
		iconURL: URL(string: "https://raw.githubusercontent.com/0xjohnnydev/cyanide/main/Cyanide/Assets.xcassets/AppIcon.appiconset/icon-ios-1024x1024.png"),
		iconAsset: "CyanideIcon",
		downloadURL: URL(string: "https://github.com/0xjohnnydev/cyanide/releases/download/v1.3.6/Cyanide-1.3.6.ipa")!,
		size: 7_895_202,
		version: "1.3.6"
	)

	/// Sibling of Cyanide — same DarkSword base, separate fork, released
	/// within the last few days, which is what earns the NEW chip.
	static let infern0 = FeaturedApp(
		id: "infern0",
		name: "Infern0",
		developer: "Nnnnnnn274",
		summary: "Sibling build of Cyanide, on the same DarkSword base.",
		badges: [("HOT", .hot), ("NEW", .new)],
		glow: Color(red: 1.00, green: 0.42, blue: 0.21),
		iconURL: URL(string: "https://raw.githubusercontent.com/Nnnnnnn274/Infern0/main/Infern0/Assets.xcassets/AppIcon.appiconset/icon-ios-1024x1024.png"),
		iconAsset: "Infern0Icon",
		downloadURL: URL(string: "https://github.com/Nnnnnnn274/Infern0/releases/download/4.0.0/Infern0-4.0.0.ipa")!,
		size: 13_712_761,
		version: "4.0.0"
	)

	/// Free Fire client with the DarkSword patches applied. Metadata read from
	/// the package itself rather than typed in, so the row matches what
	/// actually installs.
	static let ffds = FeaturedApp(
		id: "ffds",
		name: "FF DS",
		developer: "DarkSword",
		summary: "Patched Free Fire client built on the DarkSword base.",
		badges: [("HOT", .hot), ("EPIC", .epic)],
		glow: .gold,
		iconURL: nil,
		iconAsset: "FFDSIcon",
		comingSoon: true,
		downloadURL: URL(string: "https://leonardob8777-bit.github.io/apps/FF_Darksword_crack.ipa")!,
		size: 1_843_116,
		version: "1.5.2"
	)

	static let turbomax = FeaturedApp(
		id: "turbomax",
		name: "TurboMax",
		developer: "DarkSword",
		summary: "Performance tuner from the DarkSword games line.",
		badges: [("HOT", .hot), ("EPIC", .epic)],
		glow: .gold,
		iconURL: nil,
		iconAsset: "TurboMaxIcon",
		comingSoon: true,
		downloadURL: URL(string: "https://leonardob8777-bit.github.io/apps/turbomax.ipa")!,
		size: 17_051_987,
		version: "1.0"
	)

	static let all: [FeaturedApp] = [.ffds, .turbomax, .lara, .infern0, .cyanide]
}
