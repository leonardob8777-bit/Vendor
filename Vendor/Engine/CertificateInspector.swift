//
//  CertificateInspector.swift
//  Vendor
//
//  Checks an imported certificate/profile pair without going through the
//  engine's revocation check.
//
//  Why not the engine: `Zsign.checkRevokage` asks Apple whether the certificate
//  has been revoked, and parses the reply with
//
//      OCSP_RESPONSE *resp;                       // never set
//      d2i_OCSP_RESPONSE(&resp, …);
//
//  OpenSSL's `d2i_*` contract is to reuse whatever `*a` points at when it is not
//  null. `resp` is an uninitialised local, so OpenSSL dereferences whatever the
//  stack happened to hold — which on one run here was the text `%{public`, left
//  over from a logging call. Two imports, two segmentation faults, always in the
//  same place. It is undefined behaviour: it works when the stack happens to
//  hold zeroes, which is why the same certificate imports fine on one device and
//  kills the app on another. Present in the pinned revision and still present on
//  upstream's `package` branch.
//
//  So this does the part that can be done safely and locally: prove the password
//  opens the key, and read the dates. What is given up is the revocation answer
//  — and a revocation check that crashes the app is worth less than none. Only
//  the import path used it; signing never calls it.
//

import Foundation
import Security

enum CertificateInspector {

	struct Result {
		/// 0 when the pair can be used. Mirrors what the engine reported, so
		/// `StoredCertificate.isUsable` keeps working unchanged.
		let code: Int32
		let message: String?
		let expiresAt: Date?
	}

	static func inspect(p12: URL, password: String, profile: URL) -> Result {
		guard let data = try? Data(contentsOf: p12) else {
			return Result(code: 10, message: t("cert.unreadableKey"), expiresAt: nil)
		}

		// The one check that matters most at import: does this password actually
		// open this key? A wrong password is far and away the common failure,
		// and it is the one the engine used to report.
		var items: CFArray?
		let status = SecPKCS12Import(
			data as CFData,
			[kSecImportExportPassphrase as String: password] as CFDictionary,
			&items
		)

		switch status {
		case errSecSuccess:
			break
		case errSecAuthFailed, errSecPkcs12VerifyFailure:
			return Result(code: 11, message: t("cert.wrongPassword"), expiresAt: nil)
		case errSecDecode:
			return Result(code: 12, message: t("cert.notAKey"), expiresAt: nil)
		default:
			return Result(code: 13, message: String(format: t("cert.keyRefused"), status), expiresAt: nil)
		}

		guard let contents = items as? [[String: Any]], !contents.isEmpty else {
			return Result(code: 14, message: t("cert.noIdentity"), expiresAt: nil)
		}

		// The profile carries the date the app already shows, and it is the one
		// that governs whether iOS will accept the signature.
		let expiry = ProvisioningProfile.read(at: profile)?.expirationDate
		if let expiry, expiry < Date() {
			return Result(code: 15, message: t("cert.profileExpired"), expiresAt: expiry)
		}

		return Result(code: 0, message: nil, expiresAt: expiry)
	}
}
