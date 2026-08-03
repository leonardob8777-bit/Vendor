//
//  Installer.swift
//  Vendor
//
//  Installs a signed .ipa onto this device.
//
//  iOS has exactly one route for this outside the App Store: hand `installd` an
//  `itms-services://` URL pointing at a manifest it can fetch over HTTPS. So the
//  work here is to stand up that HTTPS endpoint locally, describe the package in
//  a manifest, and hand the URL to the system.
//
//  The one-time cost is trust: the device has to accept Vendor's own authority
//  before it will talk to the local server. `authorityInstalled` tracks that,
//  and `authorityURL` is what the setup screen opens.
//

import Foundation
import Security
import UIKit
import Observation

enum InstallerError: LocalizedError {
	case noSignedBuild
	case noBundleIdentifier
	case authorityNotTrusted
	case systemRefused
	case cancelled
	case simulatorUnsupported

	var errorDescription: String? {
		switch self {
		case .noSignedBuild:      return t("err.install.noBuild")
		case .noBundleIdentifier: return t("err.install.noBundleID")
		case .authorityNotTrusted: return t("err.install.notTrusted")
		case .systemRefused:      return t("err.install.refused")
		case .cancelled:          return t("err.install.cancelled")
		case .simulatorUnsupported: return t("err.install.simulator")
		}
	}
}

@Observable
@MainActor
final class Installer {
	static let shared = Installer()

	/// Set once the user has installed and trusted Vendor's authority.
	var authorityInstalled: Bool {
		didSet { UserDefaults.standard.set(authorityInstalled, forKey: Self.trustKey) }
	}

	/// Whether this build runs on the simulator.
	///
	/// A stored value, not an `#if` at the point of use: the compiler treats
	/// code after a conditional-compilation `throw` as unreachable and warns
	/// about it, and that warning has to be read every build by whoever is
	/// looking for a real one.
	private static let isSimulator: Bool = {
		#if targetEnvironment(simulator)
		return true
		#else
		return false
		#endif
	}()

	private static let trustKey = "vendor.authority.installed"
	private static let keyTag = "com.leonardob8777bit.vendor.local-tls"
	/// Bumped whenever the certificate's shape changes. A stored pair from an
	/// older format is thrown away rather than served, since the old one may be
	/// exactly why installing stopped working.
	private static let formatVersion = 2
	private static let versionKey = "vendor.authority.format"

	private let server = InstallServer()
	/// Identity and host resolved ahead of time by `prepare()`.
	private var readyIdentity: (identity: SecIdentity, host: String)?
	/// Held open until the install finishes; installd fetches asynchronously.
	private var shutdown: Task<Void, Never>?
	/// Background time keeping the listener answering while Vendor sits behind
	/// the system's install prompt. `.invalid` when none is held.
	private var backgroundToken: UIBackgroundTaskIdentifier = .invalid

	private init() {
		authorityInstalled = UserDefaults.standard.bool(forKey: Self.trustKey)
	}

	// MARK: Trust setup

	/// Writes the authority to disk and returns a URL the user can open to
	/// install it. iOS only offers the "Install Profile" flow for a certificate
	/// it is handed directly, which is why this goes through a file rather than
	/// the local server.
	func authorityFile() async throws -> URL {
		let identity = try await ensureIdentity()
		let url = URL.temporaryDirectory.appendingPathComponent("Vendor-Authority.cer")
		try identity.authorityDER.write(to: url, options: .atomic)
		return url
	}

	/// Warms the install path so tapping Install is immediate: the certificate
	/// is fetched, and the identity it forms is built and cached.
	func prepare() async {
		guard readyIdentity == nil else { return }
		guard let pack = try? await ServerPackStore.current() else { return }
		readyIdentity = publicIdentity(from: pack).map { ($0, pack.host) }
	}

	// MARK: Installing

	/// Serves `package` and asks iOS to install it.
	func install(_ package: URL, item: ImportedIPA) async throws {
		guard FileManager.default.fileExists(atPath: package.path) else {
			throw InstallerError.noSignedBuild
		}
		guard let bundleID = item.installIdentifier else {
			throw InstallerError.noBundleIdentifier
		}
		// itms-services has no handler in the simulator. Left to run, the open
		// call spends five seconds inside LaunchServices before giving up, and
		// the whole screen is frozen for it — which reads as Vendor hanging
		// rather than as the simulator being unable to install anything at all.
		//
		// Read from a constant rather than throwing straight out of an `#if`:
		// inside the conditional the compiler can see the whole rest of this
		// method is unreachable in a simulator build, and says so — one warning
		// on top of the hundred and sixty-odd the linker already contributes.
		if Self.isSimulator { throw InstallerError.simulatorUnsupported }
		shutdown?.cancel()
		finishServing()
		server.forgetRequests()

		// Preferred path: a publicly trusted certificate for a host that
		// resolves to this device. iOS accepts it with no setup, which is what
		// makes installing a single tap.
		let host: String
		if readyIdentity == nil { await prepare() }

		if let ready = readyIdentity {
			host = ready.host
			try await server.start(identity: ready.identity)
		} else {
			// Offline, or the pack has gone away: fall back to the certificate
			// Vendor mints itself, which needs the one-time trust step.
			guard authorityInstalled else { throw InstallerError.authorityNotTrusted }
			host = LocalCertificate.host
			let stored = try await ensureIdentity()
			try await server.start(identity: try keychainIdentity(for: stored))
		}

		// The server is listening from here on, so every way out of this method
		// has to close it. Writing the manifest can fail — a full disk is enough
		// — and leaving on that error used to leave the listener up with the
		// package still routed, for as long as Vendor stayed running.
		let manifest: URL
		do {
			manifest = try writeManifest(
				for: item,
				bundleID: bundleID,
				packageURL: "https://\(host):\(server.port)/app.ipa"
			)
		} catch {
			finishServing()
			throw error
		}

		server.serve(package, at: "/app.ipa", mime: "application/octet-stream")
		server.serve(manifest, at: "/manifest.plist", mime: "text/xml")

		let install = URL(
			string: "itms-services://?action=download-manifest&url="
				+ "https://\(host):\(server.port)/manifest.plist"
		)!

		// Opening this URL sends Vendor to the background, and a backgrounded app
		// is suspended within seconds — taking the listener with it. installd
		// then finds nothing on the port and reports that it cannot connect.
		// Asking for background time is what keeps the server answering.
		backgroundToken = UIApplication.shared.beginBackgroundTask(withName: "vendor.install") {
			// Ending the task here is not optional: an expiration handler that
			// returns without giving the time back gets the app killed outright.
			Task { @MainActor in self.finishServing() }
		}

		guard await UIApplication.shared.open(install) else {
			finishServing()
			throw InstallerError.systemRefused
		}

		// installd fetches the manifest, draws its prompt, and only comes back
		// for the package once the user has said yes — and that second fetch is
		// the whole package. A fixed timer used to close the listener at 25
		// seconds regardless, which cut long installs off mid-transfer. Waiting
		// for the package to actually go out is the honest end of the job.
		shutdown = Task { [weak self, server] in
			let deadline = ContinuousClock.now.advanced(by: .seconds(240))
			while ContinuousClock.now < deadline, !Task.isCancelled {
				if server.wasDelivered("/app.ipa") { break }
				try? await Task.sleep(for: .milliseconds(400))
			}
			// A breath of slack so installd closes the connection on its terms.
			try? await Task.sleep(for: .seconds(2))
			// Cancelled means someone else has taken the server over: either
			// `abort()` or the next install, and both close it themselves before
			// going on. Closing it here as well would land on whatever has
			// started since — the sleeps above give up the main actor, so a
			// second install can be several steps in by the time this runs, and
			// it would lose its listener and its background time to a task that
			// belongs to the install before it.
			guard !Task.isCancelled else { return }
			self?.finishServing()
		}
	}

	/// Stops serving and gives the background time back, however the install
	/// ended. Safe to call more than once.
	private func finishServing() {
		server.stop()
		if backgroundToken != .invalid {
			UIApplication.shared.endBackgroundTask(backgroundToken)
			backgroundToken = .invalid
		}
	}

	/// How the system prompt was answered, as far as it can be told.
	enum Outcome {
		case accepted
		case cancelled
	}

	/// Waits for the user to answer iOS's install prompt.
	///
	/// installd reports nothing back to the app that asked, so both signals are
	/// indirect: it fetches the manifest to draw its prompt, and only comes back
	/// for the package if the user taps Install. Cancel returns to Vendor
	/// exactly like Install does, so being at the front again proves nothing on
	/// its own — the request for the package is the honest signal.
	///
	/// This polls the application state rather than waiting on
	/// `didBecomeActive`. That notification is a single shot, and it fires while
	/// the caller is still on its way to listening for it: a cancelled install
	/// missed it and then sat through the entire timeout, leaving a progress
	/// panel that looked frozen for a minute and a half.
	func awaitOutcome(timeout: Duration = .seconds(180)) async -> Outcome {
		let start = ContinuousClock.now
		let deadline = start.advanced(by: timeout)
		/// The prompt is a system alert, so Vendor stops being the active app
		/// while it is up. Coming back only counts once it has gone away.
		var wasInterrupted = false
		var returnedAt: ContinuousClock.Instant?

		while ContinuousClock.now < deadline {
			if server.wasRequested("/app.ipa") { return .accepted }
			if Task.isCancelled { return .cancelled }

			if UIApplication.shared.applicationState == .active {
				if wasInterrupted, returnedAt == nil { returnedAt = ContinuousClock.now }
			} else {
				wasInterrupted = true
				returnedAt = nil
			}

			// Back in front, prompt gone, package never asked for: it was
			// dismissed. The grace covers installd beginning its transfer a
			// moment after the tap, which a quick user would otherwise beat.
			if let returnedAt, returnedAt.duration(to: .now) > .seconds(4) {
				return .cancelled
			}

			// The prompt never appeared at all: if installd had engaged it would
			// have read the manifest by now. Nothing is coming.
			if !wasInterrupted,
			   start.duration(to: .now) > .seconds(12),
			   !server.wasRequested("/manifest.plist") {
				return .cancelled
			}

			try? await Task.sleep(for: .milliseconds(200))
		}
		return .cancelled
	}

	/// Gives up on an install in flight: stops serving and hands back the
	/// background time. Whatever iOS is showing is iOS's to dismiss; this only
	/// stops Vendor waiting on it.
	func abort() {
		shutdown?.cancel()
		finishServing()
	}

	// MARK: Manifest

	private func writeManifest(
		for item: ImportedIPA,
		bundleID: String,
		packageURL: String
	) throws -> URL {
		let manifest: [String: Any] = [
			"items": [[
				"assets": [[
					"kind": "software-package",
					"url": packageURL,
				]],
				// Everything here describes what is inside the archive, not what
				// was imported. An override the user set is already baked into
				// the signed bundle, so the prompt has to say the same thing —
				// otherwise iOS is told one name and hands over another.
				"metadata": [
					"bundle-identifier": bundleID,
					"bundle-version": item.installVersion ?? "1.0",
					"kind": "software",
					"title": item.installName,
				],
			]]
		]

		let data = try PropertyListSerialization.data(
			fromPropertyList: manifest,
			format: .xml,
			options: 0
		)
		let url = URL.temporaryDirectory.appendingPathComponent("manifest.plist")
		try data.write(to: url, options: .atomic)
		return url
	}

	/// Files the downloaded certificate and key, then asks the keychain for the
	/// identity they form together.
	private func publicIdentity(from pack: ServerPack) -> SecIdentity? {
		let chain = PEM.certificates(in: pack.certificatePEM)
		guard let leaf = chain.first,
			  let key = PEM.privateKey(in: pack.keyPEM)
		else { return nil }

		let label = Self.keyTag + ".public"

		let keyQuery: [String: Any] = [
			kSecClass as String: kSecClassKey,
			kSecAttrApplicationTag as String: Data(label.utf8),
		]
		SecItemDelete(keyQuery as CFDictionary)
		var keyAdd = keyQuery
		keyAdd[kSecValueRef as String] = key
		SecItemAdd(keyAdd as CFDictionary, nil)

		let certQuery: [String: Any] = [
			kSecClass as String: kSecClassCertificate,
			kSecAttrLabel as String: label,
		]
		SecItemDelete(certQuery as CFDictionary)
		var certAdd = certQuery
		certAdd[kSecValueRef as String] = leaf
		SecItemAdd(certAdd as CFDictionary, nil)

		var result: CFTypeRef?
		let query: [String: Any] = [
			kSecClass as String: kSecClassIdentity,
			kSecAttrLabel as String: label,
			kSecReturnRef as String: true,
		]
		guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
			  let identity = result
		else { return nil }

		return (identity as! SecIdentity)
	}

	// MARK: Identity storage

	/// Generates the pair on first use and keeps it in the keychain thereafter,
	/// so the authority the user trusted stays the one the server presents.
	private func ensureIdentity() async throws -> GeneratedIdentity {
		let stored = UserDefaults.standard.integer(forKey: Self.versionKey)
		if stored == Self.formatVersion, let existing = loadIdentity() {
			return existing
		}

		// Two 2048-bit RSA keys. Measured at ~510 ms on a simulator running on
		// an M1, so noticeably worse on a phone — and this class is @MainActor,
		// so run inline it freezes the screen at the exact moment the user has
		// just tapped a button. Detached, the progress panel keeps animating.
		let generated = try await Task.detached(priority: .userInitiated) {
			try LocalCertificate.generate()
		}.value
		try store(generated)
		UserDefaults.standard.set(Self.formatVersion, forKey: Self.versionKey)
		// A new authority is a different authority: whatever the device trusted
		// before no longer matches, so the setup has to be done again.
		if stored != 0 && stored != Self.formatVersion {
			authorityInstalled = false
		}
		return generated
	}

	private func loadIdentity() -> GeneratedIdentity? {
		guard let authority = readData(account: "authority"),
			  let leaf = readData(account: "leaf"),
			  let key = readKey()
		else { return nil }
		return GeneratedIdentity(authorityDER: authority, leafDER: leaf, leafKey: key)
	}

	private func store(_ identity: GeneratedIdentity) throws {
		write(identity.authorityDER, account: "authority")
		write(identity.leafDER, account: "leaf")

		// The key is stored as a key item so SecIdentity can pair it with the
		// certificate later.
		let attributes: [String: Any] = [
			kSecClass as String: kSecClassKey,
			kSecAttrApplicationTag as String: Data(Self.keyTag.utf8),
			kSecValueRef as String: identity.leafKey,
		]
		SecItemDelete(attributes as CFDictionary)
		SecItemAdd(attributes as CFDictionary, nil)
	}

	/// Pairs the stored certificate with its key to get something TLS accepts.
	///
	/// iOS has no `SecIdentityCreateWithCertificate` — that is macOS only. The
	/// keychain forms the identity itself once the certificate and its matching
	/// private key are both filed, so the job here is to put them in and ask
	/// for the result back.
	private func keychainIdentity(for stored: GeneratedIdentity) throws -> SecIdentity {
		guard let certificate = SecCertificateCreateWithData(nil, stored.leafDER as CFData) else {
			throw LocalCertificateError.identity
		}

		let label = Self.keyTag
		let add: [String: Any] = [
			kSecClass as String: kSecClassCertificate,
			kSecAttrLabel as String: label,
			kSecValueRef as String: certificate,
		]
		SecItemDelete([
			kSecClass as String: kSecClassCertificate,
			kSecAttrLabel as String: label,
		] as CFDictionary)
		SecItemAdd(add as CFDictionary, nil)

		let query: [String: Any] = [
			kSecClass as String: kSecClassIdentity,
			kSecAttrLabel as String: label,
			kSecReturnRef as String: true,
		]
		var result: CFTypeRef?
		guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
			  let identity = result
		else { throw LocalCertificateError.identity }

		return (identity as! SecIdentity)
	}

	// MARK: Keychain helpers

	private func write(_ data: Data, account: String) {
		let query: [String: Any] = [
			kSecClass as String: kSecClassGenericPassword,
			kSecAttrService as String: Self.keyTag,
			kSecAttrAccount as String: account,
		]
		SecItemDelete(query as CFDictionary)

		var insert = query
		insert[kSecValueData as String] = data
		SecItemAdd(insert as CFDictionary, nil)
	}

	private func readData(account: String) -> Data? {
		let query: [String: Any] = [
			kSecClass as String: kSecClassGenericPassword,
			kSecAttrService as String: Self.keyTag,
			kSecAttrAccount as String: account,
			kSecReturnData as String: true,
		]
		var result: CFTypeRef?
		guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess else {
			return nil
		}
		return result as? Data
	}

	private func readKey() -> SecKey? {
		let query: [String: Any] = [
			kSecClass as String: kSecClassKey,
			kSecAttrApplicationTag as String: Data(Self.keyTag.utf8),
			kSecReturnRef as String: true,
		]
		var result: CFTypeRef?
		guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess else {
			return nil
		}
		// SecKey is a CF type; the cast is safe because the query asked for a ref.
		return (result as! SecKey?)
	}
}
