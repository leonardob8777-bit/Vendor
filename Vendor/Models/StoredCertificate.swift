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

	func health(now: Date = Date()) -> Health {
		guard isUsable else {
			return .rejected(statusMessage ?? "Rejected by the signing engine")
		}
		guard let expiresAt else {
			return .valid(daysLeft: 0)
		}
		let days = Calendar.current.dateComponents([.day], from: now, to: expiresAt).day ?? 0
		if days < 0 { return .expired(daysAgo: -days) }
		if days < 30 { return .expiring(daysLeft: days) }
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
