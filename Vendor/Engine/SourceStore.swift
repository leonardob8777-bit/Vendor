//
//  SourceStore.swift
//  Vendor
//
//  Repositories the user has added by hand, on top of the one Vendor ships
//  with. Stored in Application Support rather than Documents: it is app state,
//  not something anyone should be editing through the Files app.
//

import Foundation
import Observation

struct CustomSource: Identifiable, Codable, Equatable {
	let id: UUID
	var url: URL
	/// Name the feed reports, filled in the first time it loads. Nil until then,
	/// so a repository that has never been reachable still shows its address.
	var name: String?
	var addedAt: Date

	/// What to call it in the list.
	var displayName: String { name ?? url.host ?? url.absoluteString }
}

enum SourceStoreError: LocalizedError {
	case notAURL
	case alreadyAdded
	case unreadable(String)

	var errorDescription: String? {
		switch self {
		case .notAURL:            return t("sources.notAURL")
		case .alreadyAdded:       return t("sources.alreadyAdded")
		case .unreadable(let why): return String(format: t("sources.unreadable"), why)
		}
	}
}

@Observable
final class SourceStore {
	static let shared = SourceStore()

	private(set) var sources: [CustomSource] = []

	/// Shipped repositories the user has switched on, by address.
	///
	/// Kept in defaults rather than in `sources.json`: it is a preference about
	/// a repository the app already carries, not a repository record, and
	/// mixing the two would mean rewriting the file format for a checkbox.
	private(set) var expanded: Set<String> = []

	private let fm = FileManager.default

	private var file: URL {
		let dir = URL.applicationSupportDirectory
		if !fm.fileExists(atPath: dir.path) {
			try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
		}
		return dir.appendingPathComponent("sources.json")
	}

	private static let expandedKey = "vendor.sources.expanded"

	private init() {
		expanded = Set(UserDefaults.standard.stringArray(forKey: Self.expandedKey) ?? [])
		reload()
	}

	/// Whether an opt-in repository has been switched on.
	func includes(_ url: URL) -> Bool { expanded.contains(url.absoluteString) }

	func setIncluded(_ on: Bool, for url: URL) {
		if on { expanded.insert(url.absoluteString) } else { expanded.remove(url.absoluteString) }
		UserDefaults.standard.set(Array(expanded), forKey: Self.expandedKey)
	}

	func reload() {
		guard let data = try? Data(contentsOf: file) else { sources = []; return }
		let decoder = JSONDecoder()
		decoder.dateDecodingStrategy = .iso8601
		sources = (try? decoder.decode([CustomSource].self, from: data)) ?? []
	}

	/// Checks the address really serves a repository before keeping it.
	///
	/// Storing first and finding out later would leave a permanent error row in
	/// the list for a typo, and the user would have to delete it to be rid of a
	/// mistake they made two seconds ago.
	@discardableResult
	func add(_ text: String) async throws -> CustomSource {
		let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
		guard let url = URL(string: trimmed),
			  let scheme = url.scheme?.lowercased(),
			  scheme == "https" || scheme == "http",
			  url.host != nil
		else { throw SourceStoreError.notAURL }

		guard !sources.contains(where: { $0.url == url }),
			  !SourceLoader.defaultSourceURLs.contains(url)
		else { throw SourceStoreError.alreadyAdded }

		let loaded: AppSource
		do {
			loaded = try await SourceLoader.load(from: url)
		} catch {
			throw SourceStoreError.unreadable(error.localizedDescription)
		}

		let source = CustomSource(id: UUID(), url: url, name: loaded.name, addedAt: Date())
		sources.append(source)
		write()
		return source
	}

	func remove(_ source: CustomSource) {
		sources.removeAll { $0.id == source.id }
		write()
	}

	/// Records the name a feed reported, so the list stops showing a bare host.
	func rename(_ id: UUID, to name: String?) {
		guard let name, !name.isEmpty,
			  let index = sources.firstIndex(where: { $0.id == id }),
			  sources[index].name != name
		else { return }
		sources[index].name = name
		write()
	}

	private func write() {
		let encoder = JSONEncoder()
		encoder.dateEncodingStrategy = .iso8601
		encoder.outputFormatting = .prettyPrinted
		try? encoder.encode(sources).write(to: file, options: .atomic)
	}
}
