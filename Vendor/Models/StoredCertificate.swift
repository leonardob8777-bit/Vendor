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
	/// What the provisioning profile says this identity is for.
	///
	/// Filled in by the store when it loads, from the profile file beside the
	/// key, and never written to `metadata.json` — reading it back from the
	/// profile every time costs one small plist parse and cannot go stale. Nil
	/// only when the profile will not parse.
	var kind: ProvisioningProfile.Kind?

	enum Health {
		case valid(daysLeft: Int)
		case expiring(daysLeft: Int)
		case expired(daysAgo: Int)
		case rejected(String)
	}

	var isUsable: Bool { statusCode == 0 }

	/// Whether it could sign something right now.
	///
	/// `isUsable` only reports what the engine made of the file, which says
	/// nothing about the date — so an expired certificate is "usable" and sorts
	/// ahead of a healthy one when the sort is by soonest expiry, its date being
	/// in the past. That put an expired identity on the Home card, under the word
	/// Expired, while a certificate good for another ten months sat in the list
	/// behind it.
	var canSignNow: Bool {
		guard isUsable else { return false }
		guard let expiresAt else { return true }
		return expiresAt > Date()
	}

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
			return .rejected(statusMessage ?? t("certs.rejectedByEngine"))
		}
		guard let expiresAt else {
			return .valid(daysLeft: 0)
		}
		let days = Calendar.current.dateComponents([.day], from: now, to: expiresAt).day ?? 0
		if days < 0 { return .expired(daysAgo: -days) }
		if days < warningThresholdDays { return .expiring(daysLeft: days) }
		return .valid(daysLeft: days)
	}

	/// Which bucket the certificates screen files this under.
	///
	/// A value, not the heading text. The screen used to group on the heading
	/// itself and then keep the buckets whose names appeared in a hard-coded
	/// list of English words — so in Spanish nothing ever matched and the screen
	/// went blank with certificates sitting in the store, and any bucket whose
	/// English name was not in that list was dropped without a trace.
	///
	/// Which kind it is comes from the profile. The old test searched the issuer
	/// for the word "distribution", and the issuer is the profile's TeamName — a
	/// person's or company's name — so it never contained it: everything landed
	/// under Developer, including certificates plainly named Distribution, and
	/// Enterprise could not be reached at all.
	enum Group: Int, CaseIterable, Hashable {
		// Declaration order is display order.
		case enterprise, distribution, developer, other, revoked

		var title: String {
			switch self {
			case .enterprise:   return t("certs.groupEnterprise")
			case .distribution: return t("certs.groupDistribution")
			case .developer:    return t("certs.groupDeveloper")
			case .other:        return t("certs.groupOther")
			case .revoked:      return t("certs.groupRevoked")
			}
		}
	}

	var group: Group {
		switch health() {
		case .expired, .rejected:
			return .revoked
		default:
			switch kind {
			case .development:  return .developer
			case .distribution: return .distribution
			case .enterprise:   return .enterprise
			case nil:           return .other
			}
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
