//
//  InstallServer.swift
//  Vendor
//
//  A tiny HTTPS server on the loopback interface, which is how the signed .ipa
//  reaches iOS.
//
//  iOS installs an app through `itms-services://`, and it will only fetch the
//  manifest over HTTPS from a host it trusts. So Vendor serves both the
//  manifest and the package to itself, over TLS, using the certificate minted
//  by LocalCertificate.
//

import Foundation
import Network
import Security

enum InstallServerError: LocalizedError {
	case identityUnavailable
	case cannotListen(String)

	var errorDescription: String? {
		switch self {
		case .identityUnavailable:  return t("err.server.identity")
		case .cannotListen(let why): return String(format: t("err.server.listen"), why)
		}
	}
}

/// Resumes a continuation exactly once, however many times it is told to.
///
/// A listener can report ready, then failed, and the timeout can fire on top of
/// both — and resuming a continuation twice is a crash, not a warning.
private final class ResumeOnce: @unchecked Sendable {
	private var continuation: CheckedContinuation<Void, Error>?
	private let lock = NSLock()

	init(_ continuation: CheckedContinuation<Void, Error>) {
		self.continuation = continuation
	}

	func succeed() { take()?.resume() }
	func fail(_ error: Error) { take()?.resume(throwing: error) }

	private func take() -> CheckedContinuation<Void, Error>? {
		lock.lock()
		defer { lock.unlock() }
		let pending = continuation
		continuation = nil
		return pending
	}
}

/// Serves one package for as long as the install takes.
final class InstallServer {

	/// Files the server will hand out, keyed by request path.
	private var routes: [String: (mime: String, url: URL)] = [:]
	/// Paths installd has asked for during the current install.
	private var requested: Set<String> = []
	/// Paths that have been sent all the way through, not merely asked for.
	private var delivered: Set<String> = []
	/// Guards everything above. The routing table is set from the main actor
	/// while connections read it on `queue`, and a Swift dictionary read during
	/// a write is not merely stale — it can fault.
	private let lock = NSLock()
	private var listener: NWListener?
	private let queue = DispatchQueue(label: "vendor.install-server")

	private(set) var port: UInt16 = 0

	// MARK: Lifecycle

	/// Starts listening on a free loopback port.
	///
	/// Waiting for the listener to come up used to block the calling thread on a
	/// semaphore — and the caller is the main actor, since installing begins at a
	/// tap. Suspending instead keeps the interface alive while the port is
	/// assigned.
	func start(identity: SecIdentity) async throws {
		guard let secIdentity = sec_identity_create(identity) else {
			throw InstallServerError.identityUnavailable
		}

		let options = NWProtocolTLS.Options()
		sec_protocol_options_set_local_identity(
			options.securityProtocolOptions,
			secIdentity
		)
		// iOS's installd will not negotiate below TLS 1.2.
		sec_protocol_options_set_min_tls_protocol_version(
			options.securityProtocolOptions, .TLSv12
		)

		let parameters = NWParameters(tls: options)
		// Deliberately not pinned to .loopback: installd is a separate system
		// process reaching in, and constraining the listener's interface is one
		// more way for it to find nothing there.
		parameters.allowLocalEndpointReuse = true
		parameters.includePeerToPeer = false

		let listener: NWListener
		do {
			listener = try NWListener(using: parameters)
		} catch {
			throw InstallServerError.cannotListen(error.localizedDescription)
		}

		listener.newConnectionHandler = { [weak self] connection in
			self?.accept(connection)
		}

		do {
			try await withCheckedThrowingContinuation { continuation in
				let gate = ResumeOnce(continuation)

				listener.stateUpdateHandler = { state in
					switch state {
					case .ready:
						gate.succeed()
					case .failed(let error):
						gate.fail(InstallServerError.cannotListen(error.localizedDescription))
					case .cancelled:
						gate.fail(InstallServerError.cannotListen("cancelled"))
					default:
						break
					}
				}

				listener.start(queue: queue)
				// A listener that never reports either way would otherwise leave
				// the install waiting forever.
				queue.asyncAfter(deadline: .now() + 5) {
					gate.fail(InstallServerError.cannotListen("timed out"))
				}
			}
		} catch {
			listener.cancel()
			throw error
		}

		guard let assigned = listener.port?.rawValue, assigned != 0 else {
			listener.cancel()
			throw InstallServerError.cannotListen("no port")
		}

		self.listener = listener
		self.port = assigned
	}

	func stop() {
		listener?.cancel()
		listener = nil
		lock.lock()
		routes = [:]
		lock.unlock()
	}

	/// Publishes a file at `path`, e.g. "/app.ipa".
	func serve(_ url: URL, at path: String, mime: String) {
		lock.lock()
		routes[path] = (mime, url)
		lock.unlock()
	}

	private func route(for path: String) -> (mime: String, url: URL)? {
		lock.lock()
		defer { lock.unlock() }
		return routes[path]
	}

	// MARK: What installd asked for

	/// True once `path` has been requested at least once.
	///
	/// This is the only feedback iOS gives about the install: it fetches the
	/// manifest to draw its confirmation prompt, and comes back for the package
	/// itself only if the user taps Install. So whether "/app.ipa" was ever
	/// asked for is the difference between a confirmed install and a cancelled
	/// one. Read from the main actor, written on the network queue, hence the
	/// lock.
	func wasRequested(_ path: String) -> Bool {
		lock.lock()
		defer { lock.unlock() }
		return requested.contains(path)
	}

	/// True once `path` has been sent in full.
	///
	/// Asking for the package and receiving it are different moments, and the
	/// gap between them is the whole transfer — which for a large app is not
	/// brief. This is what tells the caller the listener is safe to close.
	func wasDelivered(_ path: String) -> Bool {
		lock.lock()
		defer { lock.unlock() }
		return delivered.contains(path)
	}

	/// Clears the record, so the next install starts from a clean slate.
	func forgetRequests() {
		lock.lock()
		requested.removeAll()
		delivered.removeAll()
		lock.unlock()
	}

	// MARK: Connections

	private func accept(_ connection: NWConnection) {
		connection.start(queue: queue)
		receive(on: connection, buffer: Data())
	}

	/// Reads until the request headers are complete. A GET has no body, so the
	/// blank line is the whole signal we need.
	private func receive(on connection: NWConnection, buffer: Data) {
		connection.receive(minimumIncompleteLength: 1, maximumLength: 16 * 1024) {
			[weak self] chunk, _, isComplete, error in

			guard let self else { return }
			var accumulated = buffer
			if let chunk { accumulated.append(chunk) }

			if error != nil || (isComplete && accumulated.isEmpty) {
				connection.cancel()
				return
			}

			let terminator = Data("\r\n\r\n".utf8)
			guard let end = accumulated.range(of: terminator) else {
				if accumulated.count > 64 * 1024 {
					connection.cancel()
				} else {
					self.receive(on: connection, buffer: accumulated)
				}
				return
			}

			let head = String(decoding: accumulated[..<end.lowerBound], as: UTF8.self)
			self.respond(to: head, on: connection)
		}
	}

	private func respond(to head: String, on connection: NWConnection) {
		let requestLine = head.split(separator: "\r\n").first ?? ""
		let fields = requestLine.split(separator: " ")
		let path = fields.count > 1 ? String(fields[1]) : "/"

		lock.lock()
		requested.insert(path)
		lock.unlock()

		guard let route = route(for: path),
			  let handle = try? FileHandle(forReadingFrom: route.url),
			  let size = try? FileManager.default
				.attributesOfItem(atPath: route.url.path)[.size] as? Int
		else {
			send(status: "404 Not Found", body: Data(), mime: "text/plain", on: connection)
			return
		}

		var header = "HTTP/1.1 200 OK\r\n"
		header += "Content-Type: \(route.mime)\r\n"
		header += "Content-Length: \(size)\r\n"
		header += "Connection: close\r\n\r\n"

		connection.send(content: Data(header.utf8), completion: .contentProcessed { [weak self] _ in
			// Packages run to hundreds of megabytes; sending in chunks keeps
			// the whole file out of memory at once.
			self?.pump(handle, of: path, on: connection)
		})
	}

	private func pump(_ handle: FileHandle, of path: String, on connection: NWConnection) {
		let chunk = (try? handle.read(upToCount: 256 * 1024)) ?? Data()

		guard !chunk.isEmpty else {
			try? handle.close()
			lock.lock()
			delivered.insert(path)
			lock.unlock()
			connection.send(content: nil, isComplete: true, completion: .contentProcessed { _ in
				connection.cancel()
			})
			return
		}

		connection.send(content: chunk, completion: .contentProcessed { [weak self] error in
			guard let self, error == nil else {
				try? handle.close()
				connection.cancel()
				return
			}
			self.pump(handle, of: path, on: connection)
		})
	}

	private func send(status: String, body: Data, mime: String, on connection: NWConnection) {
		var header = "HTTP/1.1 \(status)\r\n"
		header += "Content-Type: \(mime)\r\n"
		header += "Content-Length: \(body.count)\r\n"
		header += "Connection: close\r\n\r\n"

		connection.send(
			content: Data(header.utf8) + body,
			isComplete: true,
			completion: .contentProcessed { _ in connection.cancel() }
		)
	}
}
