//
//  CertificateStore.swift
//  Vendor
//
//  Keeps imported signing identities on disk and asks the engine to vet them.
//  Layout: Documents/Certificates/<uuid>/{cert.p12, profile.mobileprovision,
//  metadata.json}
//

import Foundation
import Observation

enum CertificateStoreError: LocalizedError {
	case cannotReadPickedFile
	case cannotWrite(String)

	var errorDescription: String? {
		switch self {
		case .cannotReadPickedFile:
			return t("err.cert.unreadable")
		case .cannotWrite(let detail):
			return String(format: t("err.cert.cannotWrite"), detail)
		}
	}
}

@Observable
final class CertificateStore {
	static let shared = CertificateStore()

	private(set) var certificates: [StoredCertificate] = []

	private let fm = FileManager.default

	/// Application Support, not Documents.
	///
	/// Vendor ships with `UIFileSharingEnabled`, so everything under Documents is
	/// browsable from the Files app and over iTunes/Finder. That is wanted for
	/// packages — dropping an .ipa in is how people use it — but the same switch
	/// was putting `cert.p12` and a `metadata.json` holding its password in
	/// plain text one tap away from anyone holding the phone. The Home screen
	/// promises these never leave the device; they were sitting in a folder made
	/// for taking things off it.
	private var root: URL {
		let url = URL.applicationSupportDirectory.appendingPathComponent("Certificates", isDirectory: true)
		if !fm.fileExists(atPath: url.path) {
			try? fm.createDirectory(at: url, withIntermediateDirectories: true)
		}
		return url
	}

	private init() {
		migrateOutOfDocuments()
		reload()
	}

	/// Moves certificates filed before they had somewhere private to live.
	///
	/// Runs once: the old folder is removed after its contents have been moved,
	/// so a later launch finds nothing to do. An entry that somehow exists in
	/// both places is left alone rather than overwritten — the newer location is
	/// the one in use.
	private func migrateOutOfDocuments() {
		let old = URL.documentsDirectory.appendingPathComponent("Certificates", isDirectory: true)
		guard fm.fileExists(atPath: old.path) else { return }

		let destination = root
		if let entries = try? fm.contentsOfDirectory(at: old, includingPropertiesForKeys: nil) {
			for entry in entries {
				let target = destination.appendingPathComponent(entry.lastPathComponent)
				guard !fm.fileExists(atPath: target.path) else { continue }
				try? fm.moveItem(at: entry, to: target)
			}
		}

		// Only once there is nothing left. Removing the old folder regardless
		// would delete any certificate whose move failed — and a signing
		// identity is not something to lose to a tidy-up. Left in place, the
		// next launch tries again.
		let leftovers = (try? fm.contentsOfDirectory(atPath: old.path)) ?? []
		if leftovers.isEmpty {
			try? fm.removeItem(at: old)
		}
	}

	// MARK: Paths

	func folder(for id: UUID) -> URL {
		root.appendingPathComponent(id.uuidString, isDirectory: true)
	}

	func p12URL(for id: UUID) -> URL { folder(for: id).appendingPathComponent("cert.p12") }
	func provisionURL(for id: UUID) -> URL { folder(for: id).appendingPathComponent("profile.mobileprovision") }
	private func metadataURL(for id: UUID) -> URL { folder(for: id).appendingPathComponent("metadata.json") }

	// MARK: Reading

	func reload() {
		guard let entries = try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: nil) else {
			certificates = []
			return
		}
		let decoder = JSONDecoder()
		decoder.dateDecodingStrategy = .iso8601

		certificates = entries.compactMap { folder -> StoredCertificate? in
			guard folder.hasDirectoryPath,
				  let id = UUID(uuidString: folder.lastPathComponent),
				  let data = try? Data(contentsOf: metadataURL(for: id)),
				  let cert = try? decoder.decode(StoredCertificate.self, from: data)
			else { return nil }
			return cert
		}
		.sorted { $0.importedAt > $1.importedAt }
	}

	// MARK: Importing

	/// Copies the two picked files into place, asks the engine to vet them,
	/// and records the result.
	@discardableResult
	func importCertificate(
		p12Source: URL,
		provisionSource: URL,
		password: String,
		nickname: String?
	) async throws -> StoredCertificate {
		let id = UUID()
		let dir = folder(for: id)

		let p12Path = p12URL(for: id)
		let provisionPath = provisionURL(for: id)

		try await Task.detached(priority: .userInitiated) { [self] in
			do {
				try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
				try copyScoped(from: p12Source, to: p12Path)
				try copyScoped(from: provisionSource, to: provisionPath)
			} catch {
				try? FileManager.default.removeItem(at: dir)
				throw CertificateStoreError.cannotWrite(error.localizedDescription)
			}
		}.value

		// The engine is the authority on whether this pair can actually sign.
		// Detached because the engine is synchronous C++ that reaches out to
		// Apple: on the main actor it would stall the screen while it waits.
		let status = await Task.detached(priority: .userInitiated) {
			await SigningEngine.inspectCertificate(
				provisionPath: provisionPath.path,
				certificatePath: p12Path.path,
				password: password
			)
		}.value

		let profile = await Task.detached(priority: .userInitiated) {
			ProvisioningProfile.read(at: provisionPath)
		}.value

		let cert = StoredCertificate(
			id: id,
			name: nickname?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
				?? profile?.name
				?? "Certificate",
			issuer: profile?.teamName,
			password: password,
			expiresAt: status.expiresAt ?? profile?.expirationDate,
			statusCode: status.code,
			statusMessage: status.message,
			importedAt: Date()
		)

		try write(cert)
		reload()
		return cert
	}

	/// Streams the file rather than loading it whole, and is `nonisolated` so
	/// it can run on a detached task.
	private nonisolated func copyScoped(from source: URL, to destination: URL) throws {
		let scoped = source.startAccessingSecurityScopedResource()
		defer { if scoped { source.stopAccessingSecurityScopedResource() } }

		let fm = FileManager.default
		if fm.fileExists(atPath: destination.path) { try? fm.removeItem(at: destination) }
		do {
			try fm.copyItem(at: source, to: destination)
		} catch {
			guard let data = try? Data(contentsOf: source) else {
				throw CertificateStoreError.cannotReadPickedFile
			}
			try data.write(to: destination, options: .atomic)
		}
	}

	private func write(_ cert: StoredCertificate) throws {
		let encoder = JSONEncoder()
		encoder.dateEncodingStrategy = .iso8601
		encoder.outputFormatting = .prettyPrinted
		try encoder.encode(cert).write(to: metadataURL(for: cert.id), options: .atomic)
	}

	// MARK: Deleting

	func delete(_ cert: StoredCertificate) {
		try? fm.removeItem(at: folder(for: cert.id))
		certificates.removeAll { $0.id == cert.id }
	}
}

private extension String {
	var nilIfEmpty: String? { isEmpty ? nil : self }
}
