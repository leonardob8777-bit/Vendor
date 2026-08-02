//
//  Downloader.swift
//  Vendor
//
//  Fetches .ipa packages and hands them to IPAStore. Progress is published per
//  app so a row can show its own spinner without the rest of the list caring.
//

import Foundation
import Observation

@Observable
@MainActor
final class Downloader {
	static let shared = Downloader()

	/// Fraction complete, keyed by the caller's own identifier.
	private(set) var progress: [String: Double] = [:]
	/// Last failure per identifier, cleared when a new attempt starts.
	private(set) var failures: [String: String] = [:]

	private var tasks: [String: Task<Void, Never>] = [:]

	private init() {}

	func isRunning(_ id: String) -> Bool { progress[id] != nil }

	/// Downloads `url` and files the result under Imported.
	func fetch(id: String, from url: URL, named fileName: String) {
		guard tasks[id] == nil else { return }

		failures[id] = nil
		progress[id] = 0

		tasks[id] = Task { [weak self] in
			guard let self else { return }
			defer {
				self.tasks[id] = nil
				self.progress[id] = nil
			}

			do {
				let file = try await DownloadSession.shared.download(
					url,
					named: fileName,
					onProgress: { [weak self] fraction in
						Task { @MainActor in self?.progress[id] = fraction }
					}
				)
				defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }

				// Unpacking is not instant on a large package, and a ring that
				// drops back to nothing at 100% looks like a failure. It stays
				// full until the package is filed.
				self.progress[id] = 1

				try await IPAStore.shared.importPackage(from: file)
			} catch is CancellationError {
				// Nothing to report: the user asked for this.
			} catch {
				self.failures[id] = error.localizedDescription
			}
		}
	}

	func clearFailure(_ id: String) { failures[id] = nil }

	/// Files a package that ships inside Vendor. Nothing to fetch, so the row
	/// shows a brief spinner and the app lands in Imported straight away.
	func adopt(id: String, bundledResource name: String) {
		guard tasks[id] == nil else { return }
		guard let source = Bundle.main.url(forResource: name, withExtension: "ipa") else {
			failures[id] = t("err.bundled.missing")
			return
		}

		failures[id] = nil
		progress[id] = 0

		tasks[id] = Task { [weak self] in
			guard let self else { return }
			defer {
				self.tasks[id] = nil
				self.progress[id] = nil
			}
			do {
				self.progress[id] = 0.4
				try await IPAStore.shared.importPackage(from: source)
			} catch {
				self.failures[id] = error.localizedDescription
			}
		}
	}

	func cancel(_ id: String) {
		tasks[id]?.cancel()
		tasks[id] = nil
		progress[id] = nil
	}
}

enum DownloadError: LocalizedError {
	case badStatus(Int)
	case cannotWrite

	var errorDescription: String? {
		switch self {
		case .badStatus(let code): return String(format: t("err.download.badStatus"), "\(code)")
		case .cannotWrite:         return t("err.download.cannotWrite")
		}
	}
}
