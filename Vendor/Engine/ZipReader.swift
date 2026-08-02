//
//  ZipReader.swift
//  Vendor
//
//  Minimal read-only ZIP support, enough to pull individual files out of an
//  .ipa. Written against Apple's Compression framework rather than pulling in
//  a third-party archiver: an .ipa only ever uses store (0) or deflate (8),
//  and raw deflate is exactly what COMPRESSION_ZLIB decodes.
//

import Foundation
import Compression

struct ZipEntry {
	let path: String
	let compressionMethod: UInt16
	let compressedSize: Int
	let uncompressedSize: Int
	/// Offset of the local file header inside the archive.
	let localHeaderOffset: Int
	/// Top 16 bits hold the unix mode when the archive was made on unix. This
	/// is how the executable bit survives a round trip — an .app whose binary
	/// comes back as 0644 will not launch.
	let externalAttributes: UInt32

	/// Unix mode, or nil when the archive carries no unix metadata.
	var posixMode: mode_t? {
		let mode = mode_t(externalAttributes >> 16)
		return mode == 0 ? nil : mode
	}

	var isDirectory: Bool {
		if path.hasSuffix("/") { return true }
		if let mode = posixMode { return mode & S_IFMT == S_IFDIR }
		return false
	}

	var isSymlink: Bool {
		guard let mode = posixMode else { return false }
		return mode & S_IFMT == S_IFLNK
	}
}

enum ZipReader {

	// MARK: Directory

	/// Lists every file in the archive by walking the central directory.
	static func entries(of url: URL) -> [ZipEntry] {
		guard let data = try? Data(contentsOf: url, options: .mappedIfSafe) else { return [] }
		guard let eocd = findEndOfCentralDirectory(in: data) else { return [] }

		let count = Int(read16(data, eocd + 10))
		var cursor = Int(read32(data, eocd + 16))
		var result: [ZipEntry] = []
		result.reserveCapacity(count)

		for _ in 0..<count {
			guard cursor + 46 <= data.count, read32(data, cursor) == 0x0201_4b50 else { break }

			let method = read16(data, cursor + 10)
			let compressed = Int(read32(data, cursor + 20))
			let uncompressed = Int(read32(data, cursor + 24))
			let nameLength = Int(read16(data, cursor + 28))
			let extraLength = Int(read16(data, cursor + 30))
			let commentLength = Int(read16(data, cursor + 32))
			let external = read32(data, cursor + 38)
			let localOffset = Int(read32(data, cursor + 42))

			let nameStart = cursor + 46
			guard nameStart + nameLength <= data.count else { break }
			// Packages built on Windows store paths with backslashes. Left as
			// they are, the whole bundle reads as one file with a very long
			// name: no Payload folder, nothing to sign.
			let name = String(
				decoding: data[nameStart..<(nameStart + nameLength)],
				as: UTF8.self
			).replacingOccurrences(of: "\\", with: "/")

			result.append(ZipEntry(
				path: name,
				compressionMethod: method,
				compressedSize: compressed,
				uncompressedSize: uncompressed,
				localHeaderOffset: localOffset,
				externalAttributes: external
			))

			cursor = nameStart + nameLength + extraLength + commentLength
		}
		return result
	}

	// MARK: Extraction

	/// Returns the decompressed contents of one entry.
	static func contents(of entry: ZipEntry, in url: URL) -> Data? {
		guard let data = try? Data(contentsOf: url, options: .mappedIfSafe) else { return nil }
		return contents(of: entry, in: data)
	}

	static func contents(of entry: ZipEntry, in data: Data) -> Data? {
		let header = entry.localHeaderOffset
		guard header + 30 <= data.count, read32(data, header) == 0x0403_4b50 else { return nil }

		// The local header repeats the name and extra lengths, and they can
		// differ from the central directory's — always trust the local ones.
		let nameLength = Int(read16(data, header + 26))
		let extraLength = Int(read16(data, header + 28))
		let start = header + 30 + nameLength + extraLength
		let end = start + entry.compressedSize
		guard end <= data.count else { return nil }

		let payload = data.subdata(in: start..<end)

		switch entry.compressionMethod {
		case 0:
			return payload
		case 8:
			return inflate(payload, expectedSize: entry.uncompressedSize)
		default:
			return nil
		}
	}

	/// Raw DEFLATE, which is what ZIP stores (no zlib header or trailer).
	private static func inflate(_ data: Data, expectedSize: Int) -> Data? {
		guard expectedSize > 0 else { return Data() }
		// Slack covers archives that under-report the size.
		let capacity = expectedSize + 4096
		var output = Data(count: capacity)

		let written: Int = output.withUnsafeMutableBytes { dst -> Int in
			guard let dstBase = dst.bindMemory(to: UInt8.self).baseAddress else { return 0 }
			return data.withUnsafeBytes { src -> Int in
				guard let srcBase = src.bindMemory(to: UInt8.self).baseAddress else { return 0 }
				return compression_decode_buffer(
					dstBase, capacity,
					srcBase, data.count,
					nil, COMPRESSION_ZLIB
				)
			}
		}

		guard written > 0 else { return nil }
		return output.prefix(written)
	}

	// MARK: Byte helpers

	private static func findEndOfCentralDirectory(in data: Data) -> Int? {
		// The EOCD sits at the tail, after a comment of up to 64 KB.
		let minimum = 22
		guard data.count >= minimum else { return nil }
		let lowest = max(0, data.count - minimum - 65_536)
		var index = data.count - minimum
		while index >= lowest {
			if read32(data, index) == 0x0605_4b50 { return index }
			index -= 1
		}
		return nil
	}

	private static func read16(_ data: Data, _ offset: Int) -> UInt16 {
		guard offset + 2 <= data.count else { return 0 }
		let base = data.startIndex + offset
		return UInt16(data[base]) | UInt16(data[base + 1]) << 8
	}

	private static func read32(_ data: Data, _ offset: Int) -> UInt32 {
		guard offset + 4 <= data.count else { return 0 }
		let base = data.startIndex + offset
		return UInt32(data[base])
			| UInt32(data[base + 1]) << 8
			| UInt32(data[base + 2]) << 16
			| UInt32(data[base + 3]) << 24
	}
}
