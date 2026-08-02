//
//  SigningEngine.swift
//  Vendor
//
//  Thin, typed façade over the Zsign codesigning engine (MIT).
//  This file only adapts the engine's C-style API into Swift value types —
//  it deliberately contains no cryptography or signing logic of its own.
//

import Foundation
import ZsignSwift

/// Everything needed to sign one bundle.
struct SigningRequest {
	/// Path to the `.app` bundle to sign.
	var bundlePath: String
	/// Path to the `.mobileprovision` file.
	var provisionPath: String
	/// Path to the `.p12` private key.
	var certificatePath: String
	/// Password protecting the `.p12`.
	var certificatePassword: String

	/// Optional overrides applied to the bundle's Info.plist while signing.
	var overrideIdentifier: String?
	var overrideName: String?
	var overrideVersion: String?

	/// Optional path to a custom entitlements plist.
	var entitlementsPath: String?
	/// Strip `embedded.mobileprovision` instead of embedding it.
	var removeProvisioning: Bool = false
}

enum SigningError: LocalizedError {
	case engineRejected
	case engineFailed(String)

	var errorDescription: String? {
		switch self {
		case .engineRejected:
			return t("err.engine.rejected")
		case .engineFailed(let reason):
			return reason
		}
	}
}

/// Result of inspecting a certificate/provision pair.
struct CertificateStatus {
	/// Raw status code reported by the engine.
	let code: Int32
	/// Expiry date, when the engine could determine one.
	let expiresAt: Date?
	/// Engine-reported failure reason, if any.
	let message: String?

	var isUsable: Bool { code == 0 }
}

/// Entry point for all codesigning work in Vendor.
enum SigningEngine {

	// MARK: Signing

	/// Signs the bundle described by `request`.
	/// - Throws: ``SigningError`` when the engine reports failure.
	static func sign(_ request: SigningRequest) async throws {
		try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
			var resumed = false
			// The engine may invoke the completion and also return a status;
			// guard so the continuation is resumed exactly once.
			let finish: (Result<Void, Error>) -> Void = { result in
				guard !resumed else { return }
				resumed = true
				continuation.resume(with: result)
			}

			let accepted = Zsign.sign(
				appPath: request.bundlePath,
				provisionPath: request.provisionPath,
				p12Path: request.certificatePath,
				p12Password: request.certificatePassword,
				entitlementsPath: request.entitlementsPath ?? "",
				customIdentifier: request.overrideIdentifier ?? "",
				customName: request.overrideName ?? "",
				customVersion: request.overrideVersion ?? "",
				removeProvision: request.removeProvisioning,
				completion: { success, error in
					if let error {
						finish(.failure(SigningError.engineFailed(error.localizedDescription)))
					} else {
						finish(success ? .success(()) : .failure(SigningError.engineRejected))
					}
				}
			)

			if !accepted {
				finish(.failure(SigningError.engineRejected))
			}
		}
	}

	// MARK: Inspection

	/// Asks the engine whether a certificate/provision pair is still valid.
	static func inspectCertificate(
		provisionPath: String,
		certificatePath: String,
		password: String
	) async -> CertificateStatus {
		await withCheckedContinuation { continuation in
			Zsign.checkRevokage(
				provisionPath: provisionPath,
				p12Path: certificatePath,
				p12Password: password
			) { code, expiration, message in
				continuation.resume(
					returning: CertificateStatus(code: code, expiresAt: expiration, message: message)
				)
			}
		}
	}

	/// True when the given Mach-O executable already carries a signature.
	static func isSigned(executableAt path: String) -> Bool {
		Zsign.checkSigned(appExecutable: path)
	}

	// MARK: Load commands

	/// Lists the dynamic libraries an executable links against.
	static func dylibs(inExecutableAt path: String) -> [String] {
		Zsign.listDylibs(appExecutable: path)
	}

	/// Adds a load command pointing at `dylibPath`.
	@discardableResult
	static func inject(dylibPath: String, intoExecutableAt path: String, weak: Bool = true) -> Bool {
		Zsign.injectDyLib(appExecutable: path, with: dylibPath, weak: weak)
	}

	/// Removes the given load commands from an executable.
	@discardableResult
	static func remove(dylibs: [String], fromExecutableAt path: String) -> Bool {
		Zsign.removeDylibs(appExecutable: path, using: dylibs)
	}

	/// Repoints one load command at a different path.
	@discardableResult
	static func changeDylibPath(in path: String, from old: String, to new: String) -> Bool {
		Zsign.changeDylibPath(appExecutable: path, for: old, with: new)
	}
}
