//
//  CertificateStore.swift
//  Vendor
//
//  Keeps imported signing identities on disk and asks the engine to vet them.
//  Layout: Application Support/Certificates/<uuid>/{cert.p12,
//  profile.mobileprovision, metadata.json}
//
//  Application Support rather than Documents because the app shares Documents
//  over the Files app, and the `.p12` password is in the keychain rather than
//  in metadata.json for the same reason. Neither changes anything the signing
//  engine sees: it is still handed the password as a plain string at the moment
//  it signs.
//

import Foundation
import Combine
import Security

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

final class CertificateStore: ObservableObject {
	static let shared = CertificateStore()

	@Published private(set) var certificates: [StoredCertificate] = []

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
		var url = FileManager.default.applicationSupportDirectory.appendingPathComponent("Certificates", isDirectory: true)
		if !fm.fileExists(atPath: url.path) {
			try? fm.createDirectory(at: url, withIntermediateDirectories: true)
		}
		// Every private key Vendor holds lives somewhere under here. Excluding
		// the folder itself excludes everything already inside it too, so this
		// one flag covers certificates imported before this existed as well as
		// every one imported after — nothing about "your certificates never
		// leave the phone" holds if an iCloud or iTunes backup carries them off
		// instead. Set on every access rather than once at creation: cheap, and
		// it means an OS or restore path that ever clears the flag gets it back
		// the next time anything touches a certificate.
		var values = URLResourceValues()
		values.isExcludedFromBackup = true
		try? url.setResourceValues(values)
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
		let old = FileManager.default.documentsDirectory.appendingPathComponent("Certificates", isDirectory: true)
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
				  var cert = try? decoder.decode(StoredCertificate.self, from: data)
			else { return nil }

			// Read from the profile rather than persisted, so a record written
			// by an older build classifies correctly the first time it loads.
			cert.kind = ProvisioningProfile.read(at: provisionURL(for: id))?.kind

			if cert.password.isEmpty {
				// Normal path. The file never holds one, so it comes from the
				// keychain — or is genuinely empty, for an unprotected key.
				cert.password = password(for: id) ?? ""
			} else {
				// A file written before the move. Lift the password across and
				// rewrite without it, so the plain-text copy stops existing.
				setPassword(cert.password, for: id)
				try? write(cert)
			}
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

		// Checked locally rather than through the engine's revocation call, which
		// segfaults on an uninitialised pointer — see `CertificateInspector` for
		// the whole story. Detached because reading and decrypting the key is
		// not instant and this is reached from the main actor.
		let status = await Task.detached(priority: .userInitiated) {
			CertificateInspector.inspect(
				p12: p12Path, password: password, profile: provisionPath
			)
		}.value

		let profile = await Task.detached(priority: .userInitiated) {
			ProvisioningProfile.read(at: provisionPath)
		}.value

		let cert = StoredCertificate(
			id: id,
			name: nickname?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
				?? profile?.name
				?? t("certs.defaultName"),
			issuer: profile?.teamName,
			password: password,
			expiresAt: status.expiresAt ?? profile?.expirationDate,
			statusCode: status.code,
			statusMessage: status.message,
			importedAt: Date()
		)

		// Back on the main actor to publish the result.
		//
		// This method is not actor-isolated, so awaiting the detached tasks
		// above hands the rest of it to the cooperative pool — the caller
		// starts on the main actor and does not return to it. `reload()`
		// replaces `certificates`, which is `@Published` state that the Home,
		// IPA and Certificates screens are all reading, so leaving it there
		// invalidated live views from a background thread every time somebody
		// imported a certificate. Every other entry point into this store is a
		// view calling it directly, and so already on the main actor.
		try await MainActor.run {
			try write(cert)
			reload()
		}
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
		// Password first, so a failure to write the metadata cannot leave a
		// certificate whose key nobody can unlock.
		setPassword(cert.password, for: cert.id)

		let encoder = JSONEncoder()
		encoder.dateEncodingStrategy = .iso8601
		encoder.outputFormatting = .prettyPrinted
		try encoder.encode(cert).write(to: metadataURL(for: cert.id), options: .atomic)
	}

	// MARK: Password storage

	/// The `.p12` password lives here rather than beside the key.
	///
	/// Nothing about signing changes: the engine still receives it as a plain
	/// string at the moment it signs. What changes is that it is no longer
	/// written next to the file it unlocks, where a backup — or, until this was
	/// moved out of Documents, the Files app — would hand over both together.
	private static let passwordService = "com.leonardob8777bit.vendor.certificate-password"

	private func passwordQuery(for id: UUID) -> [String: Any] {
		[
			kSecClass as String: kSecClassGenericPassword,
			kSecAttrService as String: Self.passwordService,
			kSecAttrAccount as String: id.uuidString,
		]
	}

	private func password(for id: UUID) -> String? {
		var query = passwordQuery(for: id)
		query[kSecReturnData as String] = true
		query[kSecMatchLimit as String] = kSecMatchLimitOne

		var result: CFTypeRef?
		guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
			  let data = result as? Data
		else { return nil }
		return String(data: data, encoding: .utf8)
	}

	private func setPassword(_ password: String, for id: UUID) {
		let query = passwordQuery(for: id)
		SecItemDelete(query as CFDictionary)

		var add = query
		add[kSecValueData as String] = Data(password.utf8)
		// Readable after the first unlock rather than only while unlocked: a
		// signing run can outlive the screen going dark, and an install holds
		// background time deliberately.
		add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
		SecItemAdd(add as CFDictionary, nil)
	}

	private func deletePassword(for id: UUID) {
		SecItemDelete(passwordQuery(for: id) as CFDictionary)
	}

	// MARK: Deleting

	func delete(_ cert: StoredCertificate) {
		deletePassword(for: cert.id)
		try? fm.removeItem(at: folder(for: cert.id))
		certificates.removeAll { $0.id == cert.id }
	}
}

private extension String {
	var nilIfEmpty: String? { isEmpty ? nil : self }
}
