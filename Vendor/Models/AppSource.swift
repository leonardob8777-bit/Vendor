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

	var iconLink: URL? { iconURL.flatMap(URL.init(string:)) }

	/// Newest download link the feed offers.
	var downloadLink: URL? {
		(versions?.first?.downloadURL ?? downloadURL).flatMap(URL.init(string:))
	}

	/// File name to store the package under. Feeds often point at redirects
	/// with no usable name, so fall back to the app itself.
	var suggestedFileName: String {
		if let last = downloadLink?.lastPathComponent, last.lowercased().hasSuffix(".ipa") {
			return last
		}
		let safe = name.replacingOccurrences(of: "/", with: "-")
		return "\(safe).ipa"
	}

	var screenshotLinks: [URL] {
		(screenshotURLs ?? []).compactMap(URL.init(string:))
	}

	/// Release date rendered for display, when the feed supplies a valid one.
	var releasedOn: String? {
		guard let raw = versionDate else { return nil }
		let iso = ISO8601DateFormatter()
		iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
		let date = iso.date(from: raw) ?? ISO8601DateFormatter().date(from: raw)
		guard let date else { return nil }
		return date.formatted(date: .abbreviated, time: .omitted)
	}

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
