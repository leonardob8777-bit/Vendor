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
