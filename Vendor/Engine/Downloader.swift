//
//  Downloader.swift
//  Vendor
//
//  Fetches .ipa packages and hands them to IPAStore. Progress is published per
//  app so a row can show its own spinner without the rest of the list caring.
//

import Foundation
import Combine

@MainActor
final class Downloader: ObservableObject {
	static let shared = Downloader()

	/// Fraction complete, keyed by the caller's own identifier.
	@Published private(set) var progress: [String: Double] = [:]
	/// Last failure per identifier, cleared when a new attempt starts.
	@Published private(set) var failures: [String: String] = [:]

	private var tasks: [String: Task<Void, Never>] = [:]
	/// Bumped every time work starts or is called off under an identifier.
	///
	/// A cancelled download does not stop dead: it unwinds at its next
	/// suspension point, and its cleanup used to run whatever had happened in
	/// the meantime. Tapping Get again in that window left the new download
	/// with its progress wiped and its task dropped — running, untracked,
	/// impossible to cancel, and a further tap started a third.
	private var generation: [String: Int] = [:]

	private init() {}

	func isRunning(_ id: String) -> Bool { progress[id] != nil }

	/// Downloads `url` and files the result under Imported.
	func fetch(id: String, from url: URL, named fileName: String) {
		guard tasks[id] == nil else { return }

		let token = bump(id)
		failures[id] = nil
		progress[id] = 0

		tasks[id] = Task { [weak self] in
			guard let self else { return }
			defer { self.finish(id, token: token) }

			do {
				let file = try await DownloadSession.shared.download(
					url,
					named: fileName,
					onProgress: { [weak self] fraction in
						Task { @MainActor in
							guard self?.generation[id] == token else { return }
							self?.progress[id] = fraction
						}
					}
				)
				defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }

				// The download does not stop the moment it is called off — it
				// unwinds at its next suspension point, and by then the user may
				// have tapped Get again. Filing the package here would put the
				// abandoned attempt's copy on the shelf and drive the new
				// attempt's ring, so this run has nothing left to do.
				guard self.isCurrent(id, token) else { return }

				// Unpacking is not instant on a large package, and a ring that
				// drops back to nothing at 100% looks like a failure. It stays
				// full until the package is filed.
				self.progress[id] = 1

				try await IPAStore.shared.importPackage(from: file, sourceID: id)
			} catch is CancellationError {
				// Nothing to report: the user asked for this.
			} catch {
				// Same reason: an attempt that has been replaced must not raise
				// an alert over the one that replaced it. Cancelling a download
				// and starting it again put "download failed" on screen while the
				// new one was still going.
				guard self.isCurrent(id, token) else { return }
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

		let token = bump(id)
		failures[id] = nil
		progress[id] = 0

		tasks[id] = Task { [weak self] in
			guard let self else { return }
			defer { self.finish(id, token: token) }
			do {
				// Full, not part way. There is nothing to fetch, so the only work
				// is filing it — and a ring frozen at 40% for the whole of that
				// reads as a download that stalled.
				self.progress[id] = 1
				try await IPAStore.shared.importPackage(from: source, sourceID: id)
			} catch {
				guard self.isCurrent(id, token) else { return }
				self.failures[id] = error.localizedDescription
			}
		}
	}

	func cancel(_ id: String) {
		tasks[id]?.cancel()
		_ = bump(id)
		tasks[id] = nil
		progress[id] = nil
	}

	/// Claims `id` for a new run and returns the token identifying it.
	private func bump(_ id: String) -> Int {
		let next = (generation[id] ?? 0) + 1
		generation[id] = next
		return next
	}

	/// Whether `token` still owns `id`, or something newer has claimed it.
	private func isCurrent(_ id: String, _ token: Int) -> Bool {
		generation[id] == token
	}

	/// Clears the state of a run, unless something newer has already claimed it.
	private func finish(_ id: String, token: Int) {
		guard generation[id] == token else { return }
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
