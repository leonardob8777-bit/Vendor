//
//  DownloadSession.swift
//  Vendor
//
//  A download that actually reports its progress.
//
//  Foundation's async `URLSession.download(from:delegate:)` looks like it takes
//  a progress delegate, and it does — but it only forwards
//  `URLSessionTaskDelegate` methods to it. The byte counts live on
//  `URLSessionDownloadDelegate.urlSession(_:downloadTask:didWriteData:…)`,
//  which the async wrapper keeps for itself so it can hand back the finished
//  file. Passing a delegate that implements it is silently ignored: the file
//  arrives, and not one progress callback fires along the way. Measured
//  against a real 6.9 MB package, on both `URLSession.shared` and a session of
//  our own: zero callbacks, full download.
//
//  So the progress has to come from a session we own, driving a plain
//  `URLSessionDownloadTask` and bridging its delegate back into async/await.
//

import Foundation

/// Downloads a file, reporting progress, and hands back a URL the caller owns.
final class DownloadSession: NSObject, @unchecked Sendable {

	static let shared = DownloadSession()

	/// Everything one in-flight download needs, keyed by task identifier.
	private struct Pending {
		let onProgress: @Sendable (Double) -> Void
		let continuation: CheckedContinuation<URL, Error>
		/// Where the finished file was parked. The delegate hands over a temp
		/// file that Foundation deletes the moment the callback returns, so it
		/// has to be moved there and then, not later.
		var landed: URL?
		var failure: Error?
	}

	private var pending: [Int: Pending] = [:]
	private let lock = NSLock()

	private lazy var session: URLSession = {
		URLSession(configuration: .default, delegate: self, delegateQueue: nil)
	}()

	/// Fetches `url` and returns the downloaded file, named `fileName`, in a
	/// folder the caller is responsible for removing.
	func download(
		_ url: URL,
		named fileName: String,
		onProgress: @escaping @Sendable (Double) -> Void
	) async throws -> URL {
		var request = URLRequest(url: url)
		// URLSession asks for gzip by default, and when the response comes back
		// compressed Foundation cannot say how big the finished file will be:
		// every progress callback reports an expected size of -1, so there is
		// no fraction to show and the ring sits still for the whole download.
		// Measured on a real 6.9 MB package: 138 callbacks, all of them -1.
		// Asking for the bytes as they are costs nothing — an .ipa is already a
		// compressed archive — and the same download then reports a real total
		// from its first callback.
		request.setValue("identity", forHTTPHeaderField: "Accept-Encoding")

		let task = session.downloadTask(with: request)
		task.taskDescription = fileName

		return try await withTaskCancellationHandler {
			try await withCheckedThrowingContinuation { continuation in
				lock.lock()
				pending[task.taskIdentifier] = Pending(
					onProgress: onProgress,
					continuation: continuation
				)
				lock.unlock()
				task.resume()
			}
		} onCancel: {
			task.cancel()
		}
	}
}

// MARK: - Delegate

extension DownloadSession: URLSessionDownloadDelegate {

	func urlSession(
		_ session: URLSession,
		downloadTask: URLSessionDownloadTask,
		didWriteData bytesWritten: Int64,
		totalBytesWritten: Int64,
		totalBytesExpectedToWrite: Int64
	) {
		// The delegate's own count is the best source, with the response header
		// as a backstop. A server that truly declares no length reports -1 in
		// both, and then there is no fraction to compute: the ring is left
		// where it is rather than being fed a nonsense number.
		let expected = totalBytesExpectedToWrite > 0
			? totalBytesExpectedToWrite
			: (downloadTask.response?.expectedContentLength ?? -1)
		guard expected > 0 else { return }

		lock.lock()
		let report = pending[downloadTask.taskIdentifier]?.onProgress
		lock.unlock()

		report?(min(Double(totalBytesWritten) / Double(expected), 1))
	}

	func urlSession(
		_ session: URLSession,
		downloadTask: URLSessionDownloadTask,
		didFinishDownloadingTo location: URL
	) {
		let identifier = downloadTask.taskIdentifier

		lock.lock()
		let fileName = downloadTask.taskDescription ?? location.lastPathComponent
		lock.unlock()

		var landed: URL?
		var failure: Error?

		if let http = downloadTask.response as? HTTPURLResponse,
		   !(200..<300).contains(http.statusCode) {
			failure = DownloadError.badStatus(http.statusCode)
		} else {
			// The store names the package from the URL it is handed, so the
			// file needs its real name before it gets there.
			let folder = FileManager.default.temporaryDirectory
				.appendingPathComponent("vendor-downloads/\(UUID().uuidString)", isDirectory: true)
			do {
				try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
				let destination = folder.appendingPathComponent(fileName)
				try FileManager.default.moveItem(at: location, to: destination)
				landed = destination
			} catch {
				failure = IPAStoreError.cannotWrite(error.localizedDescription)
			}
		}

		lock.lock()
		pending[identifier]?.landed = landed
		pending[identifier]?.failure = failure
		lock.unlock()
	}

	func urlSession(
		_ session: URLSession,
		task: URLSessionTask,
		didCompleteWithError error: Error?
	) {
		lock.lock()
		let entry = pending.removeValue(forKey: task.taskIdentifier)
		lock.unlock()

		guard let entry else { return }

		if let error {
			// A cancelled task is the user's doing, and the caller reads it as
			// cancellation rather than as a failure worth an alert.
			let isCancelled = (error as? URLError)?.code == .cancelled
			entry.continuation.resume(throwing: isCancelled ? CancellationError() : error)
		} else if let failure = entry.failure {
			entry.continuation.resume(throwing: failure)
		} else if let landed = entry.landed {
			entry.continuation.resume(returning: landed)
		} else {
			entry.continuation.resume(throwing: IPAStoreError.unreadable)
		}
	}
}
