//
//  LocalCertificate.swift
//  Vendor
//
//  Mints the certificate the local install server presents to iOS.
//
//  Two certificates are made: a small authority, which the user installs and
//  trusts once, and a leaf for 127.0.0.1 signed by it. They are generated on
//  the device and never leave it, so no copy of Vendor shares a private key
//  with any other — a bundled key would be extractable by anyone.
//

import Foundation
import Security

enum LocalCertificateError: LocalizedError {
	case keyGeneration
	case signing
	case identity

	var errorDescription: String? {
		switch self {
		case .keyGeneration: return t("err.local.key")
		case .signing:       return t("err.local.sign")
		case .identity:      return t("err.local.identity")
		}
	}
}

struct GeneratedIdentity {
	/// DER of the authority, which the user installs on the device.
	let authorityDER: Data
	/// DER of the leaf presented by the server.
	let leafDER: Data
	/// Private key belonging to the leaf.
	let leafKey: SecKey
}

enum LocalCertificate {

	/// Host the leaf is issued for. Everything stays on the loopback interface,
	/// so the address never has to resolve anywhere.
	static let host = "127.0.0.1"

	// MARK: Generation

	static func generate() throws -> GeneratedIdentity {
		let authorityKey = try makeKey()
		let leafKey = try makeKey()

		let now = Date()
		// Ten years: this authority is local to one device, and an expiry would
		// silently break installing long after anyone remembers why.
		let expiry = now.addingTimeInterval(60 * 60 * 24 * 365 * 10)

		let authorityName = name(commonName: "Vendor Local Authority")
		let leafName = name(commonName: host)

		let authorityDER = try certificate(
			subject: authorityName,
			issuer: authorityName,
			publicKey: try publicKey(of: authorityKey),
			signingKey: authorityKey,
			serial: 1,
			from: now, to: expiry,
			isAuthority: true,
			subjectAltName: nil
		)

		let leafDER = try certificate(
			subject: leafName,
			issuer: authorityName,
			publicKey: try publicKey(of: leafKey),
			signingKey: authorityKey,
			serial: 2,
			from: now, to: expiry,
			isAuthority: false,
			subjectAltName: host
		)

		return GeneratedIdentity(
			authorityDER: authorityDER,
			leafDER: leafDER,
			leafKey: leafKey
		)
	}

	// MARK: Keys

	private static func makeKey() throws -> SecKey {
		let attributes: [String: Any] = [
			kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
			kSecAttrKeySizeInBits as String: 2048,
		]
		var error: Unmanaged<CFError>?
		guard let key = SecKeyCreateRandomKey(attributes as CFDictionary, &error) else {
			throw LocalCertificateError.keyGeneration
		}
		return key
	}

	/// SubjectPublicKeyInfo for an RSA key. `SecKeyCopyExternalRepresentation`
	/// hands back a bare PKCS#1 RSAPublicKey, which still needs the algorithm
	/// wrapper X.509 expects around it.
	private static func publicKey(of key: SecKey) throws -> DERValue {
		guard let publicKey = SecKeyCopyPublicKey(key),
			  let raw = SecKeyCopyExternalRepresentation(publicKey, nil) as Data?
		else { throw LocalCertificateError.keyGeneration }

		return DER.sequence([
			DER.sequence([
				DER.objectIdentifier("1.2.840.113549.1.1.1"),   // rsaEncryption
				DER.null(),
			]),
			DER.bitString([UInt8](raw)),
		])
	}

	// MARK: Certificate

	private static func name(commonName: String) -> DERValue {
		DER.sequence([
			DER.set([
				DER.sequence([
					DER.objectIdentifier("2.5.4.3"),            // commonName
					DER.utf8String(commonName),
				])
			]),
			DER.set([
				DER.sequence([
					DER.objectIdentifier("2.5.4.10"),           // organizationName
					DER.utf8String("Vendor"),
				])
			]),
		])
	}

	private static func certificate(
		subject: DERValue,
		issuer: DERValue,
		publicKey: DERValue,
		signingKey: SecKey,
		serial: Int,
		from: Date,
		to: Date,
		isAuthority: Bool,
		subjectAltName: String?
	) throws -> Data {

		let algorithm = DER.sequence([
			DER.objectIdentifier("1.2.840.113549.1.1.11"),      // sha256WithRSA
			DER.null(),
		])

		var extensions: [DERValue] = [
			// basicConstraints, marked critical as the profile requires.
			DER.sequence([
				DER.objectIdentifier("2.5.29.19"),
				DER.boolean(true),
				DER.octetString(
					DER.sequence(isAuthority ? [DER.boolean(true)] : []).bytes
				),
			]),
			// keyUsage
			DER.sequence([
				DER.objectIdentifier("2.5.29.15"),
				DER.boolean(true),
				DER.octetString(
					isAuthority
						// keyCertSign + cRLSign
						? DERValue(tag: 0x03, contents: [0x01, 0x06]).bytes
						// digitalSignature + keyEncipherment
						: DERValue(tag: 0x03, contents: [0x05, 0xA0]).bytes
				),
			]),
		]

		if !isAuthority {
			// extendedKeyUsage: serverAuth. iOS refuses a TLS leaf without it.
			extensions.append(
				DER.sequence([
					DER.objectIdentifier("2.5.29.37"),
					DER.octetString(
						DER.sequence([DER.objectIdentifier("1.3.6.1.5.5.7.3.1")]).bytes
					),
				])
			)
		}

		if let subjectAltName {
			// An address goes in as iPAddress [7], not dNSName: iOS matches the
			// literal 127.0.0.1 against the IP entry and ignores a name.
			let octets = subjectAltName.split(separator: ".").compactMap { UInt8($0) }
			if octets.count == 4 {
				// Both forms: the address for the URL Vendor builds, and the
				// name in case iOS resolves the host rather than dialling the
				// literal address.
				let names = DER.sequence([
					DERValue(tag: 0x82, contents: [UInt8]("localhost".utf8)),
					DER.implicit(7, octets),
				])
				extensions.append(
					DER.sequence([
						DER.objectIdentifier("2.5.29.17"),
						DER.octetString(names.bytes),
					])
				)
			}
		}

		let tbs = DER.sequence([
			DER.explicit(0, DER.integer(2)),                    // version v3
			DER.integer(serial),
			algorithm,
			issuer,
			DER.sequence([DER.time(from), DER.time(to)]),
			subject,
			publicKey,
			DER.explicit(3, DER.sequence(extensions)),
		])

		var error: Unmanaged<CFError>?
		guard let signature = SecKeyCreateSignature(
			signingKey,
			.rsaSignatureMessagePKCS1v15SHA256,
			tbs.data as CFData,
			&error
		) as Data? else {
			throw LocalCertificateError.signing
		}

		return DER.sequence([
			tbs,
			algorithm,
			DER.bitString([UInt8](signature)),
		]).data
	}
}
