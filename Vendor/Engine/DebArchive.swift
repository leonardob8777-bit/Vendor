//
//  DebArchive.swift
//  Vendor
//
//  Unpacks a Debian package so the tweaks inside it can be injected.
//
//  A .deb is an `ar` archive holding `control.tar.*` and `data.tar.*`; the
//  payload we care about lives in the data tarball, under the paths the tweak
//  would occupy on a jailbroken device. Three formats stack up — ar, tar and
//  the compression on top — and all three are simple enough to read directly
//  rather than take on a dependency.
//

import Foundation
import Compression

enum DebArchiveError: LocalizedError {
	case notAnArchive
	case noPayload
	case unsupportedCompression(String)
	case corrupt(String)

	var errorDescription: String? {
		switch self {
		case .notAnArchive:
			return t("deb.notArchive")
		case .noPayload:
			return t("deb.noPayload")
		case .unsupportedCompression(let ext):
			return String(format: t("deb.unsupported"), ext)
		case .corrupt(let what):
			return String(format: t("deb.corrupt"), what)
		}
	}
}

enum DebArchive {

	/// Expands the package's data payload into `destination`.
	static func unpack(_ deb: URL, to destination: URL) throws {
		guard let data = try? Data(contentsOf: deb, options: .mappedIfSafe) else {
			throw DebArchiveError.notAnArchive
		}

		let members = try arMembers(in: data)
		guard let payload = members.first(where: { $0.name.hasPrefix("data.tar") }) else {
			throw DebArchiveError.noPayload
		}

		let suffix = String(payload.name.dropFirst("data.tar".count))
		let tar = try decompress(payload.contents, suffix: suffix)

		try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
		try untar(tar, into: destination)
	}

	// MARK: ar

	private struct ArMember {
		let name: String
		let contents: Data
	}

	/// Walks the `ar` container. Headers are fixed 60-byte ASCII records and
	/// every member is padded to an even offset.
	private static func arMembers(in data: Data) throws -> [ArMember] {
		let magic = Data("!<arch>\n".utf8)
		guard data.count > magic.count, data.prefix(magic.count) == magic else {
			throw DebArchiveError.notAnArchive
		}

		var cursor = data.startIndex + magic.count
		var members: [ArMember] = []

		while cursor + 60 <= data.endIndex {
			let header = data[cursor..<(cursor + 60)]
			let rawName = ascii(header, 0, 16)
				.trimmingCharacters(in: .whitespaces)
			// GNU ar terminates names with a slash.
			let name = rawName.hasSuffix("/") ? String(rawName.dropLast()) : rawName

			// `Int("-1")` succeeds, and a negative size puts `end` behind
			// `start`: the bounds check below still passes, and `subdata` traps
			// on a range whose lower bound is above its upper one.
			guard let size = Int(ascii(header, 48, 10).trimmingCharacters(in: .whitespaces)),
				  size >= 0
			else {
				throw DebArchiveError.corrupt("bad member size")
			}

			let start = cursor + 60
			let end = start + size
			guard end <= data.endIndex else { throw DebArchiveError.corrupt("member overruns file") }

			members.append(ArMember(name: name, contents: data.subdata(in: start..<end)))
			cursor = end + (size % 2)  // members are two-byte aligned
		}
		return members
	}

	private static func ascii(_ data: Data, _ offset: Int, _ length: Int) -> String {
		let base = data.startIndex + offset
		guard base + length <= data.endIndex else { return "" }
		return String(decoding: data[base..<(base + length)], as: UTF8.self)
	}

	// MARK: Compression

	private static func decompress(_ data: Data, suffix: String) throws -> Data {
		switch suffix.lowercased() {
		case "", ".tar":
			return data
		case ".gz":
			guard let out = gunzip(data) else { throw DebArchiveError.corrupt("bad gzip stream") }
			return out
		case ".xz", ".lzma":
			guard let out = decode(data, using: COMPRESSION_LZMA) else {
				throw DebArchiveError.corrupt("bad xz stream")
			}
			return out
		case ".zst", ".bz2":
			// Neither is available through Apple's Compression framework, and
			// vendoring a decoder for a format almost no tweak uses is not worth
			// the surface area. Say so plainly instead of failing obscurely.
			throw DebArchiveError.unsupportedCompression(suffix)
		default:
			throw DebArchiveError.unsupportedCompression(suffix)
		}
	}

	/// Strips the gzip wrapper and inflates the raw deflate stream inside.
	private static func gunzip(_ data: Data) -> Data? {
		guard data.count > 18 else { return nil }
		let bytes = [UInt8](data)
		guard bytes[0] == 0x1F, bytes[1] == 0x8B, bytes[2] == 0x08 else { return nil }

		let flags = bytes[3]
		var index = 10

		if flags & 0x04 != 0 {                       // FEXTRA
			guard index + 2 <= bytes.count else { return nil }
			let extra = Int(bytes[index]) | Int(bytes[index + 1]) << 8
			index += 2 + extra
		}
		if flags & 0x08 != 0 {                       // FNAME
			while index < bytes.count, bytes[index] != 0 { index += 1 }
			index += 1
		}
		if flags & 0x10 != 0 {                       // FCOMMENT
			while index < bytes.count, bytes[index] != 0 { index += 1 }
			index += 1
		}
		if flags & 0x02 != 0 { index += 2 }          // FHCRC

		guard index < bytes.count - 8 else { return nil }
		let body = data.subdata(in: (data.startIndex + index)..<(data.endIndex - 8))

		// The gzip trailer carries the real size, which makes the output buffer
		// exact rather than a guess.
		let tail = [UInt8](data.suffix(4))
		let declared = Int(tail[0]) | Int(tail[1]) << 8 | Int(tail[2]) << 16 | Int(tail[3]) << 24

		// Only a hint, and one the file being read gets to choose: four bytes
		// saying four gigabytes would have this allocate four gigabytes before
		// reading a single byte of the stream. Capped, because `decode` grows
		// the buffer on its own when the first guess is too small — so the cap
		// costs a retry at worst and can never truncate the result.
		let guess = min(max(declared, body.count * 4), 256 << 20)

		return decode(body, using: COMPRESSION_ZLIB, hint: guess)
	}

	/// Runs a one-shot decode, growing the buffer if the payload does not fit.
	private static func decode(
		_ data: Data,
		using algorithm: compression_algorithm,
		hint: Int? = nil
	) -> Data? {
		guard !data.isEmpty else { return Data() }
		var capacity = max(hint ?? data.count * 6, 64 * 1024)

		// A full buffer is indistinguishable from a truncated one, so on an
		// exact fill retry with more room before trusting the result.
		for _ in 0..<6 {
			var output = Data(count: capacity)
			let written: Int = output.withUnsafeMutableBytes { dst -> Int in
				guard let dstBase = dst.bindMemory(to: UInt8.self).baseAddress else { return 0 }
				return data.withUnsafeBytes { src -> Int in
					guard let srcBase = src.bindMemory(to: UInt8.self).baseAddress else { return 0 }
					return compression_decode_buffer(
						dstBase, capacity, srcBase, data.count, nil, algorithm
					)
				}
			}
			if written <= 0 { return nil }
			if written < capacity { return output.prefix(written) }
			capacity *= 4
		}
		return nil
	}

	// MARK: tar

	/// Extracts a ustar stream. Only the record types a .deb actually uses are
	/// handled: files, directories and symlinks.
	private static func untar(_ data: Data, into destination: URL) throws {
		let fm = FileManager.default
		var cursor = data.startIndex

		while cursor + 512 <= data.endIndex {
			let header = data[cursor..<(cursor + 512)]

			let name = cString(header, 0, 100)
			if name.isEmpty { break }                 // two zero blocks end the stream

			let prefix = cString(header, 345, 155)
			let full = prefix.isEmpty ? name : "\(prefix)/\(name)"

			// As in the ar header: negative parses, inverts the range and traps.
			// Worse here — the cursor advance would also run backwards, so the
			// loop never reaches the end of the data.
			guard let size = Int(octal(header, 124, 12)), size >= 0 else {
				throw DebArchiveError.corrupt("bad tar size")
			}
			let type = Character(UnicodeScalar(header[header.startIndex + 156]))
			let mode = mode_t(Int(octal(header, 100, 8)) ?? 0o644)

			let body = cursor + 512
			let end = body + size
			guard end <= data.endIndex else { throw DebArchiveError.corrupt("tar entry overruns file") }

			// Paths in a .deb are absolute (./Library/...); strip the leading
			// markers and refuse anything that climbs out of the destination.
			let parts = full.split(separator: "/").map(String.init)
				.filter { $0 != "." && !$0.isEmpty }
			if parts.contains("..") { throw DebArchiveError.corrupt("entry escapes the destination") }

			if !parts.isEmpty {
				let target = parts.reduce(destination) { $0.appendingPathComponent($1) }

				switch type {
				case "5":                              // directory
					try? fm.createDirectory(at: target, withIntermediateDirectories: true)
				case "0", "\0":                        // regular file
					try? fm.createDirectory(
						at: target.deletingLastPathComponent(),
						withIntermediateDirectories: true
					)
					try data.subdata(in: body..<end).write(to: target, options: .atomic)
					try? fm.setAttributes(
						[.posixPermissions: NSNumber(value: mode & 0o777)],
						ofItemAtPath: target.path
					)
				case "1", "2":                         // hard link, symlink
					let link = cString(header, 157, 100)
					// The check above covers where an entry is written, not
					// where a link points. Without this, a package can ship a
					// link out of the destination and then a plain file
					// underneath it — the file's own path holds no "..", so it
					// passes, and the write follows the link outside.
					let hops = link.split(separator: "/")
					guard !link.hasPrefix("/"), !hops.contains("..") else {
						throw DebArchiveError.corrupt("link escapes the destination")
					}
					try? fm.createDirectory(
						at: target.deletingLastPathComponent(),
						withIntermediateDirectories: true
					)
					try? fm.removeItem(at: target)
					try? fm.createSymbolicLink(atPath: target.path, withDestinationPath: link)
				default:
					break                              // long names, pax headers: skipped
				}
			}

			cursor = end + ((512 - size % 512) % 512)  // records are 512-aligned
		}
	}

	private static func cString(_ data: Data, _ offset: Int, _ length: Int) -> String {
		let base = data.startIndex + offset
		guard base + length <= data.endIndex else { return "" }
		let slice = data[base..<(base + length)]
		let trimmed = slice.prefix { $0 != 0 }
		return String(decoding: trimmed, as: UTF8.self)
	}

	private static func octal(_ data: Data, _ offset: Int, _ length: Int) -> String.SubSequence {
		let raw = cString(data, offset, length).trimmingCharacters(in: .whitespaces)
		return Substring(raw)
	}
}

private extension Int {
	/// Parses the octal fields tar stores its numbers in.
	init?(_ octal: String.SubSequence) {
		guard !octal.isEmpty, let value = Int(octal, radix: 8) else { return nil }
		self = value
	}
}
