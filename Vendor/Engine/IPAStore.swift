//
//  IPAStore.swift
//  Vendor
//
//  Keeps imported .ipa packages on disk, along with which certificate signed
//  them and which tweaks were injected.
//  Layout: Documents/IPAs/<uuid>/{package.ipa, tweaks/, metadata.json}
//

import Foundation
import Observation

struct ImportedIPA: Identifiable, Codable, Equatable {
	let id: UUID
	/// Original file name, e.g. Cyanide-1.3.6.ipa
	var fileName: String
	/// Display name read from the bundle, or the file name as a fallback.
	var name: String
	/// Bundle identifier read from the package's Info.plist.
	var bundleIdentifier: String?
	/// Marketing version read from the package's Info.plist.
	var version: String?
	/// True when artwork was extracted from the package.
	var hasIcon: Bool
	/// URL scheme the app registers, if any. Lets Vendor open it after install.
	var urlScheme: String?
	var sizeBytes: Int64
	var importedAt: Date
	/// Certificate used the last time this package was signed.
	var signedWithCertificateID: UUID?
	var signedAt: Date?
	/// Dylibs and tweak bundles queued for injection.
	var tweakFileNames: [String]

	/// Which catalogue entry this package was fetched for.
	///
	/// The Get button needs to know whether a row's app is already on the shelf,
	/// and the file name is not an answer: two unrelated apps in the feed ship
	/// their build as `Runner.ipa`, so downloading one made the other claim it
	/// had been downloaded too. Optional so packages filed before this decode.
	var sourceID: String?

	/// Pre-signing edits the user has made to this package.
	///
	/// Optional purely so packages imported before this existed still decode:
	/// a non-optional property with a default value is still required by the
	/// synthesised decoder, and every one of them would have vanished from the
	/// shelf. Read it through ``options``.
	var signOptions: SignOptions?

	/// Identifier the signed build actually carries, read back out of the bundle
	/// after the engine has applied any override.
	///
	/// Kept apart from ``bundleIdentifier`` rather than overwriting it: that one
	/// is what the original package holds, and re-signing always starts from the
	/// original. Optional so packages signed before this existed still decode.
	var signedBundleIdentifier: String?

	var options: SignOptions { signOptions ?? SignOptions() }

	var isSigned: Bool { signedAt != nil }

	// MARK: What the signed build looks like

	/// The identifier iOS is asked to install under.
	///
	/// The manifest has to name what is inside the archive. Naming the original
	/// while the archive carries an override is what would make Install as
	/// Duplicate install over the copy it was meant to sit beside.
	var installIdentifier: String? { signedBundleIdentifier ?? bundleIdentifier }

	/// Title and version for the install prompt, following the same overrides
	/// the engine wrote into the bundle.
	var installName: String { options.nameOverride ?? name }
	var installVersion: String? { options.versionOverride ?? version }

	var displaySize: String {
		let f = ByteCountFormatter()
		f.countStyle = .file
		f.allowedUnits = [.useMB]
		return f.string(fromByteCount: sizeBytes)
	}
}

enum IPAStoreError: LocalizedError {
	case unreadable
	case cannotWrite(String)
	case wrongType(String)

	var errorDescription: String? {
		switch self {
		case .unreadable:            return t("err.store.unreadable")
		case .cannotWrite(let why):  return String(format: t("err.store.cannotWrite"), why)
		case .wrongType(let why):    return why
		}
	}
}

@Observable
final class IPAStore {
	static let shared = IPAStore()

	private(set) var packages: [ImportedIPA] = []

	private let fm = FileManager.default

	private var root: URL {
		let url = URL.documentsDirectory.appendingPathComponent("IPAs", isDirectory: true)
		if !fm.fileExists(atPath: url.path) {
			try? fm.createDirectory(at: url, withIntermediateDirectories: true)
		}
		return url
	}

	private init() { reload() }

	// MARK: Paths

	func folder(for id: UUID) -> URL { root.appendingPathComponent(id.uuidString, isDirectory: true) }
	/// Path of the package file for a given id. Taking the id rather than the
	/// whole record means callers do not have to build a throwaway value.
	func packageURL(for id: UUID) -> URL { folder(for: id).appendingPathComponent("package.ipa") }
	func packageURL(for item: ImportedIPA) -> URL { packageURL(for: item.id) }
	/// Where a signed build lands. Kept alongside the original so re-signing
	/// with a different certificate always starts from the untouched package.
	func signedURL(for id: UUID) -> URL { folder(for: id).appendingPathComponent("signed.ipa") }
	func signedURL(for item: ImportedIPA) -> URL { signedURL(for: item.id) }
	func tweaksFolder(for id: UUID) -> URL { folder(for: id).appendingPathComponent("tweaks", isDirectory: true) }
	func iconURL(for id: UUID) -> URL { folder(for: id).appendingPathComponent("icon.png") }
	private func metadataURL(for id: UUID) -> URL { folder(for: id).appendingPathComponent("metadata.json") }

	// MARK: Reading

	func reload() {
		guard let entries = try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: nil) else {
			packages = []
			return
		}
		let decoder = JSONDecoder()
		decoder.dateDecodingStrategy = .iso8601

		packages = entries.compactMap { folder -> ImportedIPA? in
			guard folder.hasDirectoryPath,
				  let id = UUID(uuidString: folder.lastPathComponent),
				  let data = try? Data(contentsOf: metadataURL(for: id)),
				  let item = try? decoder.decode(ImportedIPA.self, from: data)
			else { return nil }
			return item
		}
		.sorted { $0.importedAt > $1.importedAt }
	}

	// MARK: Importing

	/// Copying and parsing happen off the main actor: both are file-system
	/// bound, and running them inline froze the UI for the whole import.
	@discardableResult
	func importPackage(from source: URL, sourceID: String? = nil) async throws -> ImportedIPA {
		let id = UUID()
		let dir = folder(for: id)
		let package = packageURL(for: id)
		let icon = iconURL(for: id)
		let tweaks = tweaksFolder(for: id)

		let (bytes, info) = try await Task.detached(priority: .userInitiated) { [self] in
			let fm = FileManager.default
			do {
				try fm.createDirectory(at: dir, withIntermediateDirectories: true)
				try fm.createDirectory(at: tweaks, withIntermediateDirectories: true)
				try copyScoped(from: source, to: package)
			} catch {
				try? fm.removeItem(at: dir)
				throw IPAStoreError.cannotWrite(error.localizedDescription)
			}

			let size = (try? fm.attributesOfItem(atPath: package.path)[.size] as? Int64) ?? 0

			// Read the bundle's own name, version and icon out of the package,
			// so the row shows the app rather than a file name.
			let parsed = IPAInspector.inspect(package)
			if let data = parsed?.iconData {
				try? data.write(to: icon, options: .atomic)
			}
			return (size, parsed)
		}.value

		let item = ImportedIPA(
			id: id,
			fileName: source.lastPathComponent,
			name: info?.displayName ?? source.deletingPathExtension().lastPathComponent,
			bundleIdentifier: info?.bundleIdentifier,
			version: info?.version,
			hasIcon: info?.iconData != nil,
			urlScheme: info?.urlScheme,
			sizeBytes: bytes,
			importedAt: Date(),
			signedWithCertificateID: nil,
			signedAt: nil,
			tweakFileNames: [],
			sourceID: sourceID,
			signOptions: nil
		)
		try write(item)
		reload()
		return item
	}

	/// Adds a tweak (.dylib or .deb) to a package's injection list.
	func addTweak(_ source: URL, to item: ImportedIPA) async throws {
		var updated = item
		let destination = tweaksFolder(for: item.id).appendingPathComponent(source.lastPathComponent)
		try await Task.detached(priority: .userInitiated) { [self] in
			try copyScoped(from: source, to: destination)
		}.value
		if !updated.tweakFileNames.contains(source.lastPathComponent) {
			updated.tweakFileNames.append(source.lastPathComponent)
		}
		try write(updated)
		reload()
	}

	func removeTweak(named name: String, from item: ImportedIPA) {
		var updated = item
		try? fm.removeItem(at: tweaksFolder(for: item.id).appendingPathComponent(name))
		updated.tweakFileNames.removeAll { $0 == name }
		try? write(updated)
		reload()
	}

	/// Records a successful signing run, which moves the package to the Signed
	/// shelf and makes `signedURL` the file worth exporting.
	func markSigned(_ item: ImportedIPA, with certificateID: UUID, identifier: String? = nil) {
		var updated = item
		updated.signedWithCertificateID = certificateID
		updated.signedAt = Date()
		// What the engine actually wrote, not what was asked for: an override the
		// engine declined to apply would otherwise be recorded as if it had taken.
		updated.signedBundleIdentifier = identifier
		if let size = try? fm.attributesOfItem(atPath: signedURL(for: item.id).path)[.size] as? Int64 {
			updated.sizeBytes = size
		}
		try? write(updated)
		reload()
	}

	/// Files the tweaks queued for a package, as URLs the pipeline can read.
	func tweakURLs(for item: ImportedIPA) -> [URL] {
		item.tweakFileNames.map { tweaksFolder(for: item.id).appendingPathComponent($0) }
	}

	func setCertificate(_ certificateID: UUID?, for item: ImportedIPA) {
		var updated = item
		updated.signedWithCertificateID = certificateID
		try? write(updated)
		reload()
	}

	// MARK: Sign options

	func setOptions(_ options: SignOptions, for item: ImportedIPA) {
		var updated = item
		updated.signOptions = options
		try? write(updated)
		reload()
	}

	/// Artwork the user chose to sign in, as opposed to ``iconURL`` which holds
	/// the icon read out of the package at import time.
	func customIconURL(for item: ImportedIPA) -> URL? {
		guard let name = item.options.customIconName else { return nil }
		let url = folder(for: item.id).appendingPathComponent(name)
		return fm.fileExists(atPath: url.path) ? url : nil
	}

	/// Stores artwork picked from the photo library and returns its file name.
	///
	/// Deliberately does not touch the options: the card holds an uncommitted
	/// draft while the user types, and writing the stored options back from here
	/// would throw away whatever was half-typed in the fields above.
	@discardableResult
	func saveCustomIcon(_ data: Data, for item: ImportedIPA) throws -> String {
		let name = "custom-icon.png"
		let url = folder(for: item.id).appendingPathComponent(name)
		do {
			try data.write(to: url, options: .atomic)
		} catch {
			throw IPAStoreError.cannotWrite(error.localizedDescription)
		}
		return name
	}

	/// Deletes stored artwork. The caller clears the reference in its own draft.
	func deleteCustomIcon(for item: ImportedIPA) {
		guard let name = item.options.customIconName else { return }
		try? fm.removeItem(at: folder(for: item.id).appendingPathComponent(name))
	}

	/// Free space on the volume the packages live on, for the pre-sign check.
	func availableBytes() -> Int64? {
		let values = try? root.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
		return values?.volumeAvailableCapacityForImportantUsage
	}

	func delete(_ item: ImportedIPA) {
		try? fm.removeItem(at: folder(for: item.id))
		packages.removeAll { $0.id == item.id }
	}

	// MARK: Helpers

	/// Streams the file across instead of loading it into memory. A 200 MB
	/// package read with `Data(contentsOf:)` would spike RAM by 200 MB and
	/// block whichever thread it ran on.
	private nonisolated func copyScoped(from source: URL, to destination: URL) throws {
		let scoped = source.startAccessingSecurityScopedResource()
		defer { if scoped { source.stopAccessingSecurityScopedResource() } }

		let fm = FileManager.default
		if fm.fileExists(atPath: destination.path) {
			try? fm.removeItem(at: destination)
		}
		do {
			try fm.copyItem(at: source, to: destination)
		} catch {
			// Some providers refuse a direct copy; fall back to a chunked read.
			guard let input = InputStream(url: source) else { throw IPAStoreError.unreadable }
			guard let output = OutputStream(url: destination, append: false) else {
				throw IPAStoreError.cannotWrite("destination unavailable")
			}
			input.open(); output.open()
            defer { input.close(); output.close() }

			var buffer = [UInt8](repeating: 0, count: 256 * 1024)
			while input.hasBytesAvailable {
				let read = input.read(&buffer, maxLength: buffer.count)
				if read < 0 { throw IPAStoreError.unreadable }
				if read == 0 { break }
				var written = 0
				while written < read {
					let n = output.write(Array(buffer[written..<read]), maxLength: read - written)
					if n <= 0 { throw IPAStoreError.cannotWrite("write failed") }
					written += n
				}
			}
		}
	}

	private func write(_ item: ImportedIPA) throws {
		let encoder = JSONEncoder()
		encoder.dateEncodingStrategy = .iso8601
		encoder.outputFormatting = .prettyPrinted
		try encoder.encode(item).write(to: metadataURL(for: item.id), options: .atomic)
	}
}
