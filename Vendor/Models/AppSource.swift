//
//  AppSource.swift
//  Vendor
//
//  Models for the AltStore source format, which most public iOS app
//  repositories publish. Every field beyond the identity is optional so a
//  malformed or partial entry degrades instead of failing the whole feed.
//

import Foundation
import SwiftUI

struct AppSource: Decodable {
	let name: String?
	let identifier: String?
	let iconURL: String?
	let apps: [SourceApp]
}

/// Written in an extension so the memberwise initialiser survives — `SourceLoader`
/// rebuilds one of these field by field after filtering.
extension AppSource {

	private enum CodingKeys: String, CodingKey {
		case name, identifier, iconURL, apps
	}

	/// One unusable entry costs that entry, not the repository.
	///
	/// The header above promises a partial entry degrades instead of failing the
	/// whole feed, and it did not: `apps` decoded as a plain array, so a single
	/// object missing `name` — out of the 8343 that one shipped repository
	/// carries, written by as many different uploaders — threw, and the user got
	/// "The source did not return a readable app list" with every one of the
	/// other 8342 discarded behind it. Nothing in a feed is ours to trust on
	/// this, and one uploader should not be able to take down the list for
	/// everybody else.
	///
	/// `apps` itself stays required. It is the only thing separating a
	/// repository from any other JSON the address happens to serve, and
	/// `SourceStore.add` leans on the decode failing to reject a typo.
	init(from decoder: Decoder) throws {
		let c = try decoder.container(keyedBy: CodingKeys.self)
		name       = try c.decodeIfPresent(String.self, forKey: .name)
		identifier = try c.decodeIfPresent(String.self, forKey: .identifier)
		iconURL    = try c.decodeIfPresent(String.self, forKey: .iconURL)
		apps       = try c.decode([Lenient<SourceApp>].self, forKey: .apps).compactMap(\.value)
	}
}

/// An element that is allowed to fail without taking the array with it.
private struct Lenient<Wrapped: Decodable>: Decodable {
	let value: Wrapped?

	init(from decoder: Decoder) throws {
		value = try? Wrapped(from: decoder)
	}
}

struct SourceApp: Decodable, Identifiable {
	let name: String
	let bundleIdentifier: String
	let developerName: String?
	let subtitle: String?
	let localizedDescription: String?
	let iconURL: String?
	let version: String?
	let size: Int64?
	let downloadURL: String?
	let tintColor: String?
	let screenshotURLs: [String]?
	let versionDescription: String?
	let versionDate: String?
	let versions: [Version]?

	struct Version: Decodable {
		let version: String?
		let size: Int64?
		let downloadURL: String?
	}

	var id: String { bundleIdentifier }

	/// Newest version string, falling back to the top-level field.
	var displayVersion: String? {
		versions?.first?.version ?? version
	}

	/// Human readable download size, when the feed reports one.
	var displaySize: String? {
		let bytes = versions?.first?.size ?? size
		guard let bytes, bytes > 0 else { return nil }
		let f = ByteCountFormatter()
		f.countStyle = .file
		f.allowedUnits = [.useMB, .useGB]
		return f.string(fromByteCount: bytes)
	}

	var iconLink: URL? { iconURL.flatMap(Self.web) }

	/// Newest download link the feed offers.
	var downloadLink: URL? {
		(versions?.first?.downloadURL ?? downloadURL).flatMap(Self.web)
	}

	/// A URL from a feed, accepted only if it addresses the web.
	///
	/// Everything here is written by whoever runs the repository, and one of the
	/// shipped ones carries thousands of entries from many uploaders. `URLSession`
	/// downloads `file://` perfectly happily, so a feed could name a path inside
	/// this app's own container and have Vendor copy it onto the Imported shelf —
	/// which lives in Documents, which is shared over the Files app. The
	/// certificate store was deliberately moved out of Documents so a `.p12`
	/// could not be picked up from there; a feed naming it would have put it
	/// straight back. `SourceStore` already holds repository addresses to
	/// http(s); the links inside a feed were never given the same treatment.
	private static func web(_ text: String) -> URL? {
		guard let url = URL(string: text),
			  let scheme = url.scheme?.lowercased(),
			  scheme == "https" || scheme == "http",
			  url.host != nil
		else { return nil }
		return url
	}

	/// File name to store the package under. Feeds often point at redirects
	/// with no usable name, so fall back to the app itself.
	var suggestedFileName: String {
		// `lastPathComponent` is not necessarily one component: Foundation
		// decodes percent-escapes when it splits the path, so an encoded slash
		// comes back as a real one. See `DownloadSession.safeName`.
		if let last = downloadLink?.lastPathComponent.split(separator: "/").last.map(String.init),
		   last.lowercased().hasSuffix(".ipa"),
		   last != ".." {
			return last
		}
		let safe = name.replacingOccurrences(of: "/", with: "-")
		return "\(safe).ipa"
	}

	var screenshotLinks: [URL] {
		(screenshotURLs ?? []).compactMap(Self.web)
	}

	/// Release date rendered for display, when the feed supplies a valid one.
	///
	/// A bare calendar date is what the repositories actually publish —
	/// "2026-08-03", with no time on it at all — and `ISO8601DateFormatter`
	/// refuses that unless it is told to expect it. Both shipped feeds fell
	/// through to nil on every single entry, all 8343 of one and all 3 of the
	/// other, so the Released row was never shown for any app in the app.
	///
	/// Parsed and rendered in the same fixed zone. A date with no time is read
	/// as midnight UTC, and printing that in a zone behind UTC lands on the day
	/// before: without pinning it, every reader in the Americas would have seen
	/// each release dated one day early.
	var releasedOn: String? {
		guard let raw = versionDate?.trimmingCharacters(in: .whitespacesAndNewlines),
			  !raw.isEmpty
		else { return nil }

		let parser = ISO8601DateFormatter()
		parser.timeZone = Self.dateZone

		let accepted: [ISO8601DateFormatter.Options] = [
			[.withInternetDateTime, .withFractionalSeconds],
			[.withInternetDateTime],
			[.withFullDate],
		]
		guard let date = accepted.lazy.compactMap({ options -> Date? in
			parser.formatOptions = options
			return parser.date(from: raw)
		}).first else { return nil }

		var style = Date.FormatStyle(date: .abbreviated, time: .omitted)
		style.timeZone = Self.dateZone
		return date.formatted(style.locale(Localizer.shared.language.locale))
	}

	private static let dateZone = TimeZone(secondsFromGMT: 0) ?? TimeZone(identifier: "GMT")!

	/// Release notes with the markdown headings feeds tend to embed stripped out.
	var releaseNotes: String? {
		guard let raw = versionDescription?.trimmingCharacters(in: .whitespacesAndNewlines),
			  !raw.isEmpty else { return nil }
		let cleaned = raw
			.split(separator: "\n", omittingEmptySubsequences: false)
			.map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "# ")) }
			.joined(separator: "\n")
			.trimmingCharacters(in: .whitespacesAndNewlines)
		return cleaned.isEmpty ? nil : cleaned
	}

	/// Colour the action button borrows from the app itself.
	///
	/// Feeds routinely ship near-black tints (`#000000`, `#010f00`), which
	/// would vanish against a dark card. So the hue is kept — that is what
	/// identifies the app — while saturation and brightness are floored to
	/// values that stay legible. Greys have no usable hue and fall back to
	/// the brand colour.
	var accent: Color {
		guard let raw = tintColor, let hsb = HSB(hex: raw) else { return .brand }
		guard hsb.saturation >= 0.20 else { return .brand }

		return Color(
			hue: hsb.hue,
			saturation: max(hsb.saturation, 0.62),
			brightness: max(hsb.brightness, 0.78)
		)
	}

	/// Slightly rotated and deepened, for the far end of the gradient.
	var accentDeep: Color {
		guard let raw = tintColor, let hsb = HSB(hex: raw) else { return .brandDeep }
		guard hsb.saturation >= 0.20 else { return .brandDeep }

		return Color(
			hue: (hsb.hue + 0.055).truncatingRemainder(dividingBy: 1),
			saturation: max(hsb.saturation, 0.70),
			brightness: max(hsb.brightness, 0.62)
		)
	}
}

/// Minimal hex → HSB conversion, tolerant of `#abc`, `abc`, `#aabbcc`.
private struct HSB {
	let hue: Double
	let saturation: Double
	let brightness: Double

	init?(hex: String) {
		var s = hex.trimmingCharacters(in: .whitespaces)
		if s.hasPrefix("#") { s.removeFirst() }

		if s.count == 3 {
			s = s.map { "\($0)\($0)" }.joined()
		}
		guard s.count == 6, let value = UInt32(s, radix: 16) else { return nil }

		let r = Double((value >> 16) & 0xFF) / 255
		let g = Double((value >> 8) & 0xFF) / 255
		let b = Double(value & 0xFF) / 255

		let maxC = max(r, g, b)
		let minC = min(r, g, b)
		let delta = maxC - minC

		brightness = maxC
		saturation = maxC == 0 ? 0 : delta / maxC

		if delta == 0 {
			hue = 0
		} else if maxC == r {
			hue = (((g - b) / delta).truncatingRemainder(dividingBy: 6)) / 6
		} else if maxC == g {
			hue = ((b - r) / delta + 2) / 6
		} else {
			hue = ((r - g) / delta + 4) / 6
		}
	}
}

// MARK: - Loading

enum SourceLoaderError: LocalizedError {
	case badStatus(Int)
	case malformed

	var errorDescription: String? {
		switch self {
		case .badStatus(let code): return String(format: t("err.source.badStatus"), "\(code)")
		case .malformed:           return t("err.source.malformed")
		}
	}
}

enum SourceLoader {
	/// A repository shipped with the app.
	struct BuiltIn {
		let url: URL
		/// Left out of the list until the user asks for it in the repositories
		/// panel. For one that publishes thousands of entries, arriving switched
		/// on would bury everything else on the screen.
		let optIn: Bool
	}

	/// Repositories the app ships with. Deliberately not tied to any other
	/// signing app's project.
	static let defaultSources: [BuiltIn] = [
		// Publishes every version of every app as its own entry: 8342 of them,
		// which come to 783 once collapsed by identifier. Off unless asked for.
		BuiltIn(url: URL(string: "https://repository.apptesters.org/")!, optIn: true),
		BuiltIn(url: URL(string: "https://repo.ikghd.me/repo.json")!, optIn: false),
	]

	static var defaultSourceURLs: [URL] { defaultSources.map(\.url) }

	/// Bundle identifiers never shown, whatever a source advertises.
	private static let blocked: Set<String> = ["nya.asami.ksign"]

	static func load(from url: URL) async throws -> AppSource {
		var request = URLRequest(url: url)
		request.cachePolicy = .reloadRevalidatingCacheData
		request.timeoutInterval = 20

		let (data, response) = try await URLSession.shared.data(for: request)

		if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
			throw SourceLoaderError.badStatus(http.statusCode)
		}

		guard var source = try? JSONDecoder().decode(AppSource.self, from: data) else {
			throw SourceLoaderError.malformed
		}

		source = AppSource(
			name: source.name,
			identifier: source.identifier,
			iconURL: source.iconURL,
			// Deduplicated as well as filtered. `SourceApp.id` is the bundle
			// identifier, so two entries sharing one would give `ForEach` a
			// repeated id — which SwiftUI documents as undefined, and which also
			// makes both rows share one download's progress. The feed is not
			// ours to trust on this.
			apps: {
				var seen = Set<String>()
				return source.apps.filter {
					!blocked.contains($0.bundleIdentifier.lowercased())
						&& seen.insert($0.bundleIdentifier).inserted
				}
			}()
		)
		return source
	}
}
