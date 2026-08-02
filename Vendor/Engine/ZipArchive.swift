//
//  ZipArchive.swift
//  Vendor
//
//  Unpacking an .ipa to disk and packing one back up. Companion to ZipReader,
//  which only reads individual entries; signing needs the whole tree on disk
//  because the engine signs a directory, not an archive.
//
//  Written against Apple's Compression framework for the same reason as the
//  reader: an .ipa only ever uses store or deflate, so a third-party archiver
//  would buy nothing.
//

import Foundation
import Compression

enum ZipArchiveError: LocalizedError {
	case unreadable
	case corrupt(String)
	case cannotWrite(String)
	case tooLarge

	var errorDescription: String? {
		switch self {
		case .unreadable:            return t("err.zip.unreadable")
		case .corrupt(let what):     return String(format: t("err.zip.corrupt"), what)
		case .cannotWrite(let what): return String(format: t("err.zip.cannotWrite"), what)
		case .tooLarge:              return t("err.zip.tooLarge")
		}
	}
}

enum ZipArchive {

	// MARK: Unpacking

	/// Expands `archive` into `destination`, preserving unix permissions.
	static func unpack(_ archive: URL, to destination: URL) throws {
		guard let data = try? Data(contentsOf: archive, options: .mappedIfSafe) else {
			throw ZipArchiveError.unreadable
		}

		let entries = ZipReader.entries(of: archive)
		guard !entries.isEmpty else { throw ZipArchiveError.corrupt("no entries") }

		let fm = FileManager.default
		try fm.createDirectory(at: destination, withIntermediateDirectories: true)

		for entry in entries {
			// A crafted archive can name ../.. and escape the destination.
			guard let target = resolve(entry.path, under: destination) else {
				throw ZipArchiveError.corrupt("entry escapes the destination")
			}

			if entry.isDirectory {
				try fm.createDirectory(at: target, withIntermediateDirectories: true)
				continue
			}

			try fm.createDirectory(
				at: target.deletingLastPathComponent(),
				withIntermediateDirectories: true
			)

			guard let contents = ZipReader.contents(of: entry, in: data) else {
				throw ZipArchiveError.corrupt("could not expand \(entry.path)")
			}

			if entry.isSymlink {
				let link = String(decoding: contents, as: UTF8.self)
				try? fm.removeItem(at: target)
				try fm.createSymbolicLink(atPath: target.path, withDestinationPath: link)
				continue
			}

			try contents.write(to: target, options: .atomic)

			if let mode = entry.posixMode, mode & 0o777 != 0 {
				try? fm.setAttributes(
					[.posixPermissions: NSNumber(value: mode & 0o777)],
					ofItemAtPath: target.path
				)
			}
		}
	}

	/// Joins a archive-relative path onto `base`, rejecting traversal.
	private static func resolve(_ path: String, under base: URL) -> URL? {
		let parts = path.split(separator: "/").map(String.init)
		guard !parts.contains(".."), !parts.isEmpty else { return nil }
		return parts.reduce(base) { $0.appendingPathComponent($1) }
	}

	// MARK: Packing

	/// The original ZIP headers count entries in 16 bits and address them in 32,
	/// so a package past either limit needs ZIP64. Checking up front is what
	/// keeps the conversions below from trapping, which would take the app down
	/// mid-signature instead of reporting something the user can act on.
	private static let entryLimit = 0xFFFF
	private static let offsetLimit = Int(UInt32.max)

	/// Archives everything inside `directory` into `archive`.
	///
	/// Entries are written straight to the output file as they are produced, so
	/// peak memory stays at roughly one file rather than the whole package.
	static func pack(_ directory: URL, into archive: URL) throws {
		let fm = FileManager.default
		try? fm.removeItem(at: archive)
		guard fm.createFile(atPath: archive.path, contents: nil) else {
			throw ZipArchiveError.cannotWrite("could not create \(archive.lastPathComponent)")
		}

		let handle = try FileHandle(forWritingTo: archive)
		defer { try? handle.close() }

		// `FileHandle.write(_:)` is the Objective-C one: it raises rather than
		// throws, so a disk that fills partway through a package used to take
		// the whole app down instead of failing the job.
		func emit(_ data: Data) throws {
			do {
				try handle.write(contentsOf: data)
			} catch {
				throw ZipArchiveError.cannotWrite(archive.lastPathComponent)
			}
		}

		var directoryRecords = Data()
		var count = 0
		var offset = 0

		for relative in try tree(of: directory) {
			guard count < entryLimit, offset <= offsetLimit else {
				throw ZipArchiveError.tooLarge
			}
			let source = directory.appendingPathComponent(relative)
			let attributes = try fm.attributesOfItem(atPath: source.path)
			let type = attributes[.type] as? FileAttributeType
			let mode = (attributes[.posixPermissions] as? NSNumber)?.uint16Value ?? 0o644

			var name = relative
			var payload = Data()
			var stored = Data()
			var method: UInt16 = 0
			var unixMode: UInt16

			switch type {
			case .typeDirectory:
				name += "/"
				unixMode = UInt16(S_IFDIR) | mode
			case .typeSymbolicLink:
				let target = try fm.destinationOfSymbolicLink(atPath: source.path)
				payload = Data(target.utf8)
				stored = payload
				unixMode = UInt16(S_IFLNK) | mode
			default:
				payload = try Data(contentsOf: source, options: .mappedIfSafe)
				unixMode = UInt16(S_IFREG) | mode
				if let deflated = deflate(payload), deflated.count < payload.count {
					stored = deflated
					method = 8
				} else {
					stored = payload
				}
			}

			guard payload.count <= offsetLimit, stored.count <= offsetLimit else {
				throw ZipArchiveError.tooLarge
			}

			let crc = CRC32.checksum(payload)
			let nameBytes = Data(name.utf8)

			var local = Data()
			local.append(uint32: 0x0403_4b50)
			local.append(uint16: 20)          // version needed
			local.append(uint16: 0)           // flags
			local.append(uint16: method)
			local.append(uint16: 0)           // mod time
			local.append(uint16: 0x21)        // mod date — 1 Jan 1980
			local.append(uint32: crc)
			local.append(uint32: UInt32(stored.count))
			local.append(uint32: UInt32(payload.count))
			local.append(uint16: UInt16(nameBytes.count))
			local.append(uint16: 0)           // extra length
			local.append(nameBytes)

			try emit(local)
			if !stored.isEmpty { try emit(stored) }

			var record = Data()
			record.append(uint32: 0x0201_4b50)
			record.append(uint16: 0x031E)     // made by unix, zip 3.0
			record.append(uint16: 20)
			record.append(uint16: 0)
			record.append(uint16: method)
			record.append(uint16: 0)
			record.append(uint16: 0x21)
			record.append(uint32: crc)
			record.append(uint32: UInt32(stored.count))
			record.append(uint32: UInt32(payload.count))
			record.append(uint16: UInt16(nameBytes.count))
			record.append(uint16: 0)          // extra
			record.append(uint16: 0)          // comment
			record.append(uint16: 0)          // disk number
			record.append(uint16: 0)          // internal attributes
			record.append(uint32: UInt32(unixMode) << 16)
			record.append(uint32: UInt32(offset))
			record.append(nameBytes)

			directoryRecords.append(record)
			count += 1
			offset += local.count + stored.count
		}

		let directoryOffset = offset
		guard directoryOffset <= offsetLimit else { throw ZipArchiveError.tooLarge }
		try emit(directoryRecords)

		var end = Data()
		end.append(uint32: 0x0605_4b50)
		end.append(uint16: 0)                 // disk
		end.append(uint16: 0)                 // disk with directory
		end.append(uint16: UInt16(count))
		end.append(uint16: UInt16(count))
		end.append(uint32: UInt32(directoryRecords.count))
		end.append(uint32: UInt32(directoryOffset))
		end.append(uint16: 0)                 // comment length
		try emit(end)
	}

	/// Every path inside `root`, relative to it, parents before children.
	private static func tree(of root: URL) throws -> [String] {
		let fm = FileManager.default
		// No skipsHiddenFiles: a bundle may legitimately carry dotfiles, and
		// dropping them silently would ship a package missing pieces.
		guard let walker = fm.enumerator(
			at: root,
			includingPropertiesForKeys: [.isDirectoryKey],
			options: []
		) else {
			throw ZipArchiveError.cannotWrite("could not read \(root.lastPathComponent)")
		}

		let base = root.standardizedFileURL.path
		var result: [String] = []
		for case let url as URL in walker {
			let full = url.standardizedFileURL.path
			guard full.hasPrefix(base + "/") else { continue }
			result.append(String(full.dropFirst(base.count + 1)))
		}
		return result
	}

	/// Raw DEFLATE — the reader's counterpart. Returns nil when the data does
	/// not compress, which is common for already-compressed assets.
	private static func deflate(_ data: Data) -> Data? {
		guard !data.isEmpty else { return nil }
		var output = Data(count: data.count)

		let written: Int = output.withUnsafeMutableBytes { dst -> Int in
			guard let dstBase = dst.bindMemory(to: UInt8.self).baseAddress else { return 0 }
			return data.withUnsafeBytes { src -> Int in
				guard let srcBase = src.bindMemory(to: UInt8.self).baseAddress else { return 0 }
				return compression_encode_buffer(
					dstBase, data.count,
					srcBase, data.count,
					nil, COMPRESSION_ZLIB
				)
			}
		}

		guard written > 0 else { return nil }
		return output.prefix(written)
	}
}

// MARK: - CRC-32

/// Standard CRC-32, which ZIP requires in both headers.
enum CRC32 {
	private static let table: [UInt32] = (0..<256).map { index -> UInt32 in
		var value = UInt32(index)
		for _ in 0..<8 {
			value = (value & 1) == 1 ? (value >> 1) ^ 0xEDB8_8320 : value >> 1
		}
		return value
	}

	static func checksum(_ data: Data) -> UInt32 {
		var crc: UInt32 = 0xFFFF_FFFF
		data.withUnsafeBytes { raw in
			for byte in raw.bindMemory(to: UInt8.self) {
				crc = (crc >> 8) ^ table[Int((crc ^ UInt32(byte)) & 0xFF)]
			}
		}
		return crc ^ 0xFFFF_FFFF
	}
}

// MARK: - Little-endian helpers

private extension Data {
	mutating func append(uint16 value: UInt16) {
		append(UInt8(value & 0xFF))
		append(UInt8((value >> 8) & 0xFF))
	}

	mutating func append(uint32 value: UInt32) {
		append(UInt8(value & 0xFF))
		append(UInt8((value >> 8) & 0xFF))
		append(UInt8((value >> 16) & 0xFF))
		append(UInt8((value >> 24) & 0xFF))
	}
}
