//
//  ServerPack.swift
//  Vendor
//
//  Fetches the TLS material the install server presents to iOS.
//
//  iOS will only fetch an install manifest over HTTPS from a host it already
//  trusts, and it will not ask the user. The way every on-device installer
//  solves this is a public certificate for a domain whose DNS points back at
//  127.0.0.1 — the connection never leaves the phone, but the certificate
//  chains to a real authority, so iOS accepts it with no setup at all.
//
//  The pack is fetched rather than bundled because these certificates are
//  short-lived. Downloading it means a renewal reaches users on its own; a
//  bundled copy would expire and break installing for everyone at once.
//

import Foundation
import Security

enum ServerPackError: LocalizedError {
	case unreachable
	case malformed
	case expired
	case invalidMaterial

	var errorDescription: String? {
		switch self {
		case .unreachable:     return t("err.pack.unreachable")
		case .malformed:       return t("err.pack.malformed")
		case .expired:         return t("err.pack.expired")
		case .invalidMaterial: return t("err.pack.invalid")
		}
	}
}

/// The certificate, its chain and the host it is valid for.
struct ServerPack: Codable {
	/// Host to put in the URLs handed to iOS. Resolves to 127.0.0.1.
	let host: String
	/// Leaf certificate, PEM.
	let certificatePEM: String
	/// Issuing certificate, PEM. iOS needs the chain to validate the leaf.
	let issuerPEM: String
	/// Private key belonging to the leaf, PEM.
	let keyPEM: String
	let notAfter: Date

	var isUsable: Bool { notAfter > Date() }
}

enum ServerPackStore {

	private static let source = URL(string: "https://backloop.dev/pack.json")!
	private static var cacheURL: URL {
		URL.documentsDirectory.appendingPathComponent("server-pack.json")
	}

	// MARK: Access

	/// Returns a usable pack, refreshing from the network when the cached one
	/// is missing or has run out.
	static func current() async throws -> ServerPack {
		if let cached = cached(), cached.isUsable { return cached }

		let fetched = try await fetch()
		try? save(fetched)
		return fetched
	}

	static func cached() -> ServerPack? {
		guard let data = try? Data(contentsOf: cacheURL) else { return nil }
		let decoder = JSONDecoder()
		decoder.dateDecodingStrategy = .iso8601
		return try? decoder.decode(ServerPack.self, from: data)
	}

	private static func save(_ pack: ServerPack) throws {
		let encoder = JSONEncoder()
		encoder.dateEncodingStrategy = .iso8601
		try encoder.encode(pack).write(to: cacheURL, options: .atomic)
	}

	// MARK: Fetching

	private static func fetch() async throws -> ServerPack {
		var request = URLRequest(url: source)
		request.timeoutInterval = 20
		request.cachePolicy = .reloadIgnoringLocalCacheData

		guard let (data, response) = try? await URLSession.shared.data(for: request),
			  let http = response as? HTTPURLResponse,
			  (200..<300).contains(http.statusCode)
		else { throw ServerPackError.unreachable }

		guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
			  let certificate = root["cert"] as? String,
			  let issuer = root["ca"] as? String,
			  let info = root["info"] as? [String: Any],
			  let domains = info["domains"] as? [String: Any],
			  let commonName = domains["commonName"] as? String
		else { throw ServerPackError.malformed }

		// The key arrives in two halves so it is not sitting in the file as one
		// searchable blob. Joined back together it is an ordinary PEM.
		let first = root["key1"] as? String ?? ""
		let second = root["key2"] as? String ?? ""
		let key = first + second
		guard key.contains("PRIVATE KEY") else { throw ServerPackError.malformed }

		let expiry = (info["notAfter"] as? String).flatMap {
			ISO8601DateFormatter.pack.date(from: $0)
		} ?? Date().addingTimeInterval(60 * 60 * 24 * 30)

		guard expiry > Date() else { throw ServerPackError.expired }

		// A wildcard cannot be used literally; pick a label under it. Every
		// subdomain of this zone answers 127.0.0.1.
		let host = commonName.hasPrefix("*.")
			? "vendor." + commonName.dropFirst(2)
			: commonName

		return ServerPack(
			host: host,
			certificatePEM: certificate,
			issuerPEM: issuer,
			keyPEM: key,
			notAfter: expiry
		)
	}
}

private extension ISO8601DateFormatter {
	static let pack: ISO8601DateFormatter = {
		let formatter = ISO8601DateFormatter()
		formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
		return formatter
	}()
}

// MARK: - PEM

/// Turns PEM text into the keychain objects TLS needs.
enum PEM {

	/// Every DER block in a PEM document, in order.
	static func certificates(in text: String) -> [SecCertificate] {
		blocks(in: text, marker: "CERTIFICATE").compactMap {
			SecCertificateCreateWithData(nil, $0 as CFData)
		}
	}

	static func privateKey(in text: String) -> SecKey? {
		// PKCS#8 wraps the RSA key in an AlgorithmIdentifier; the Security
		// framework only takes the bare PKCS#1 body, so unwrap it first.
		if let pkcs8 = blocks(in: text, marker: "PRIVATE KEY").first {
			let body = unwrapPKCS8(pkcs8) ?? pkcs8
			return key(from: body)
		}
		if let pkcs1 = blocks(in: text, marker: "RSA PRIVATE KEY").first {
			return key(from: pkcs1)
		}
		return nil
	}

	private static func key(from der: Data) -> SecKey? {
		let attributes: [String: Any] = [
			kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
			kSecAttrKeyClass as String: kSecAttrKeyClassPrivate,
			kSecAttrKeySizeInBits as String: 2048,
		]
		return SecKeyCreateWithData(der as CFData, attributes as CFDictionary, nil)
	}

	/// Pulls the RSAPrivateKey out of a PKCS#8 PrivateKeyInfo.
	private static func unwrapPKCS8(_ der: Data) -> Data? {
		let bytes = [UInt8](der)
		var index = 0

		func readLength() -> Int? {
			guard index < bytes.count else { return nil }
			let first = bytes[index]; index += 1
			if first < 0x80 { return Int(first) }
			let count = Int(first & 0x7F)
			guard count > 0, index + count <= bytes.count else { return nil }
			var value = 0
			for _ in 0..<count { value = value << 8 | Int(bytes[index]); index += 1 }
			return value
		}

		// SEQUENCE { INTEGER version, SEQUENCE algorithm, OCTET STRING key }
		guard !bytes.isEmpty, bytes[index] == 0x30 else { return nil }
		index += 1
		guard readLength() != nil else { return nil }

		guard index < bytes.count, bytes[index] == 0x02 else { return nil }
		index += 1
		guard let versionLength = readLength() else { return nil }
		index += versionLength

		guard index < bytes.count, bytes[index] == 0x30 else { return nil }
		index += 1
		guard let algorithmLength = readLength() else { return nil }
		index += algorithmLength

		guard index < bytes.count, bytes[index] == 0x04 else { return nil }
		index += 1
		guard let keyLength = readLength(), index + keyLength <= bytes.count else { return nil }

		return Data(bytes[index..<(index + keyLength)])
	}

	/// Decodes every `-----BEGIN <marker>-----` block found.
	private static func blocks(in text: String, marker: String) -> [Data] {
		let begin = "-----BEGIN \(marker)-----"
		let end = "-----END \(marker)-----"

		var result: [Data] = []
		var remainder = Substring(text)

		while let start = remainder.range(of: begin),
			  let finish = remainder.range(of: end, range: start.upperBound..<remainder.endIndex) {
			let body = remainder[start.upperBound..<finish.lowerBound]
				.replacingOccurrences(of: "\n", with: "")
				.replacingOccurrences(of: "\r", with: "")
				.trimmingCharacters(in: .whitespaces)
			if let data = Data(base64Encoded: body) { result.append(data) }
			remainder = remainder[finish.upperBound...]
		}
		return result
	}
}
