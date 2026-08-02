//
//  DER.swift
//  Vendor
//
//  Just enough ASN.1 DER to build an X.509 certificate by hand.
//
//  Vendor needs to serve the signed .ipa to iOS over HTTPS, and iOS will only
//  accept a manifest from a host it trusts. Rather than ship a shared private
//  key — which every copy of the app would carry, and which would expire —
//  each install mints its own certificate on the device. That needs a DER
//  writer, and this is it.
//

import Foundation

/// A DER-encoded value. Composing these is how the certificate is assembled.
struct DERValue {
	let bytes: [UInt8]

	init(bytes: [UInt8]) { self.bytes = bytes }

	init(tag: UInt8, contents: [UInt8]) {
		var out: [UInt8] = [tag]
		out.append(contentsOf: DERValue.length(contents.count))
		out.append(contentsOf: contents)
		bytes = out
	}

	init(tag: UInt8, children: [DERValue]) {
		self.init(tag: tag, contents: children.flatMap(\.bytes))
	}

	/// DER length: short form under 128, long form above.
	private static func length(_ count: Int) -> [UInt8] {
		if count < 0x80 { return [UInt8(count)] }
		var value = count
		var digits: [UInt8] = []
		while value > 0 {
			digits.insert(UInt8(value & 0xFF), at: 0)
			value >>= 8
		}
		return [0x80 | UInt8(digits.count)] + digits
	}

	var data: Data { Data(bytes) }
}

enum DER {

	// MARK: Primitives

	static func sequence(_ children: [DERValue]) -> DERValue {
		DERValue(tag: 0x30, children: children)
	}

	static func set(_ children: [DERValue]) -> DERValue {
		DERValue(tag: 0x31, children: children)
	}

	static func integer(_ value: Int) -> DERValue {
		var digits: [UInt8] = []
		var remaining = value
		repeat {
			digits.insert(UInt8(remaining & 0xFF), at: 0)
			remaining >>= 8
		} while remaining > 0
		// A leading high bit would read as negative.
		if digits[0] & 0x80 != 0 { digits.insert(0, at: 0) }
		return DERValue(tag: 0x02, contents: digits)
	}

	/// Positive integer from raw bytes, used for serial numbers.
	static func integer(bytes: [UInt8]) -> DERValue {
		var digits = bytes
		while digits.count > 1, digits[0] == 0 { digits.removeFirst() }
		if digits.isEmpty { digits = [0] }
		if digits[0] & 0x80 != 0 { digits.insert(0, at: 0) }
		return DERValue(tag: 0x02, contents: digits)
	}

	static func bitString(_ contents: [UInt8]) -> DERValue {
		DERValue(tag: 0x03, contents: [0x00] + contents)  // no unused bits
	}

	static func octetString(_ contents: [UInt8]) -> DERValue {
		DERValue(tag: 0x04, contents: contents)
	}

	static func null() -> DERValue {
		DERValue(tag: 0x05, contents: [])
	}

	static func boolean(_ value: Bool) -> DERValue {
		DERValue(tag: 0x01, contents: [value ? 0xFF : 0x00])
	}

	static func utf8String(_ text: String) -> DERValue {
		DERValue(tag: 0x0C, contents: [UInt8](text.utf8))
	}

	static func ia5String(_ text: String) -> DERValue {
		DERValue(tag: 0x16, contents: [UInt8](text.utf8))
	}

	static func printableString(_ text: String) -> DERValue {
		DERValue(tag: 0x13, contents: [UInt8](text.utf8))
	}

	/// UTCTime, which X.509 uses for dates before 2050.
	static func utcTime(_ date: Date) -> DERValue {
		let formatter = DateFormatter()
		formatter.dateFormat = "yyMMddHHmmss'Z'"
		formatter.timeZone = TimeZone(identifier: "UTC")
		formatter.locale = Locale(identifier: "en_US_POSIX")
		return DERValue(tag: 0x17, contents: [UInt8](formatter.string(from: date).utf8))
	}

	/// GeneralizedTime, needed once a date reaches 2050.
	static func generalizedTime(_ date: Date) -> DERValue {
		let formatter = DateFormatter()
		formatter.dateFormat = "yyyyMMddHHmmss'Z'"
		formatter.timeZone = TimeZone(identifier: "UTC")
		formatter.locale = Locale(identifier: "en_US_POSIX")
		return DERValue(tag: 0x18, contents: [UInt8](formatter.string(from: date).utf8))
	}

	/// Picks the encoding X.509 requires for the year in question.
	static func time(_ date: Date) -> DERValue {
		var calendar = Calendar(identifier: .gregorian)
		calendar.timeZone = TimeZone(identifier: "UTC")!
		let year = calendar.component(.year, from: date)
		return year < 2050 ? utcTime(date) : generalizedTime(date)
	}

	/// Object identifier from its dotted form.
	static func objectIdentifier(_ dotted: String) -> DERValue {
		let parts = dotted.split(separator: ".").compactMap { Int($0) }
		guard parts.count >= 2 else { return DERValue(tag: 0x06, contents: []) }

		var contents: [UInt8] = [UInt8(parts[0] * 40 + parts[1])]
		for component in parts.dropFirst(2) {
			contents.append(contentsOf: base128(component))
		}
		return DERValue(tag: 0x06, contents: contents)
	}

	/// Base-128 with a continuation bit, which is how OIDs pack their arcs.
	private static func base128(_ value: Int) -> [UInt8] {
		if value == 0 { return [0] }
		var digits: [UInt8] = []
		var remaining = value
		while remaining > 0 {
			digits.insert(UInt8(remaining & 0x7F), at: 0)
			remaining >>= 7
		}
		for index in 0..<(digits.count - 1) { digits[index] |= 0x80 }
		return digits
	}

	// MARK: Context-specific wrappers

	static func explicit(_ tagNumber: UInt8, _ child: DERValue) -> DERValue {
		DERValue(tag: 0xA0 | tagNumber, contents: child.bytes)
	}

	static func implicit(_ tagNumber: UInt8, _ contents: [UInt8]) -> DERValue {
		DERValue(tag: 0x80 | tagNumber, contents: contents)
	}
}
