//
//  StoredCertificate.swift
//  Vendor
//
//  A signing identity the user imported: the two files on disk plus what the
//  engine told us about them.
//

import Foundation

struct StoredCertificate: Identifiable, Codable, Equatable {
	let id: UUID
	/// User supplied nickname, or the name read out of the provisioning profile.
	var name: String
	/// Team / issuer as advertised by the provisioning profile.
	var issuer: String?
	/// Password for the .p12. Empty when the key is not protected.
	///
	/// Held in memory like any other field — the signing engine takes it as a
	/// plain string — but deliberately never written to disk. `CertificateStore`
	/// keeps it in the keychain and fills this in after loading. See the Codable
	/// conformance below.
	var password: String
	/// Expiry reported by the engine, when it could determine one.
	var expiresAt: Date?
	/// Raw status code the engine returned while inspecting the pair.
	var statusCode: Int32
	/// Message the engine attached to a failure.
	var statusMessage: String?
	var importedAt: Date

	enum Health {
		case valid(daysLeft: Int)
		case expiring(daysLeft: Int)
		case expired(daysAgo: Int)
		case rejected(String)
	}

	var isUsable: Bool { statusCode == 0 }

	/// How many days this certificate was good for when it arrived.
	///
	/// Measured from the import rather than from an issue date, which a `.p12`
	/// does not hand over. Good enough for what it is used for: telling a
	/// seven-day certificate from a year-long one so neither is judged against
	/// the other's timescale.
	var lifetimeDays: Int {
		guard let expiresAt else { return 365 }
		let span = Calendar.current.dateComponents([.day], from: importedAt, to: expiresAt).day ?? 365
		return max(span, 1)
	}

	/// When to start warning, as a share of the certificate's own life.
	///
	/// A flat thirty days marked every free Apple ID certificate as expiring the
	/// moment it was imported — they only last seven — so the warning was on
	/// permanently and said nothing. A third of the life, capped at a month,
	/// leaves year-long certificates behaving exactly as before.
	var warningThresholdDays: Int {
		min(30, max(1, lifetimeDays / 3))
	}

	func health(now: Date = Date()) -> Health {
		guard isUsable else {
			return .rejected(statusMessage ?? "Rejected by the signing engine")
		}
		guard let expiresAt else {
			return .valid(daysLeft: 0)
		}
		let days = Calendar.current.dateComponents([.day], from: now, to: expiresAt).day ?? 0
		if days < 0 { return .expired(daysAgo: -days) }
		if days < warningThresholdDays { return .expiring(daysLeft: days) }
		return .valid(daysLeft: days)
	}

	/// Grouping used by the certificates screen.
	var group: String {
		switch health() {
		case .expired, .rejected: return t("certs.groupRevoked")
		default:
			guard let issuer else { return t("certs.groupDeveloper") }
			return issuer.localizedCaseInsensitiveContains("distribution")
				? t("certs.groupEnterprise")
				: t("certs.groupDeveloper")
		}
	}
}

// MARK: - Codable

/// Written in an extension so the memberwise initialiser survives: declaring an
/// initialiser in the body would remove it, and every call site builds one of
/// these field by field.
extension StoredCertificate {

	private enum CodingKeys: String, CodingKey {
		case id, name, issuer, password, expiresAt, statusCode, statusMessage, importedAt
	}

	init(from decoder: Decoder) throws {
		let c = try decoder.container(keyedBy: CodingKeys.self)
		id            = try c.decode(UUID.self, forKey: .id)
		name          = try c.decode(String.self, forKey: .name)
		issuer        = try c.decodeIfPresent(String.self, forKey: .issuer)
		expiresAt     = try c.decodeIfPresent(Date.self, forKey: .expiresAt)
		statusCode    = try c.decode(Int32.self, forKey: .statusCode)
		statusMessage = try c.decodeIfPresent(String.self, forKey: .statusMessage)
		importedAt    = try c.decode(Date.self, forKey: .importedAt)

		// Read, never written. Files created before the password moved to the
		// keychain still carry one; the store lifts it out on load and rewrites
		// the file without it. Anything newer simply has no such key.
		password = try c.decodeIfPresent(String.self, forKey: .password) ?? ""
	}

	func encode(to encoder: Encoder) throws {
		var c = encoder.container(keyedBy: CodingKeys.self)
		try c.encode(id, forKey: .id)
		try c.encode(name, forKey: .name)
		try c.encodeIfPresent(issuer, forKey: .issuer)
		try c.encodeIfPresent(expiresAt, forKey: .expiresAt)
		try c.encode(statusCode, forKey: .statusCode)
		try c.encodeIfPresent(statusMessage, forKey: .statusMessage)
		try c.encode(importedAt, forKey: .importedAt)
		// `password` is absent on purpose. It is the one field worth stealing.
	}
}
