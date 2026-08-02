//
//  SigningPipeline.swift
//  Vendor
//
//  Turns an imported .ipa into a signed one: unpack, inject any queued tweaks,
//  hand the bundle to the engine, then pack it back up.
//
//  The engine signs a directory, not an archive, which is why the whole package
//  has to hit disk in between. Everything happens inside a scratch folder that
//  is torn down whether the job succeeds or fails.
//

import Foundation

enum SigningPipelineError: LocalizedError {
	case noPayload
	case noExecutable
	case certificateMissing
	case emptyTweak(String)

	var errorDescription: String? {
		switch self {
		case .emptyTweak(let name):
			return String(format: t("deb.noTweakInside"), name)
		case .noPayload:
			return t("err.pipeline.noPayload")
		case .noExecutable:
			return t("err.pipeline.noExecutable")
		case .certificateMissing:
			return t("err.pipeline.certMissing")
		}
	}
}

enum SigningPipeline {

	/// What the caller gets back once a package has been signed.
	struct Output {
		/// The signed archive, sitting in the package's own folder.
		let archive: URL
		/// Bundle identifier the signed app ended up with.
		let bundleIdentifier: String?
	}

	/// Signs `package` with `certificate`, reporting progress as it goes.
	///
	/// - Parameter progress: called on the main actor with a stage and a
	///   fraction within that stage.
	static func sign(
		package: URL,
		tweaks: [URL],
		certificate: StoredCertificate,
		certificateP12: URL,
		certificateProfile: URL,
		options: SignOptions = SignOptions(),
		customIcon: URL? = nil,
		into destination: URL,
		progress: @escaping @MainActor (AppTask.Stage, Double) -> Void
	) async throws -> Output {

		let fm = FileManager.default
		guard fm.fileExists(atPath: certificateP12.path),
			  fm.fileExists(atPath: certificateProfile.path)
		else { throw SigningPipelineError.certificateMissing }

		// Scratch lives in tmp so a crash cannot leave it in Documents, where
		// it would show up in the Files app.
		let scratch = URL.temporaryDirectory
			.appendingPathComponent("vendor-sign-\(UUID().uuidString)", isDirectory: true)
		defer { try? fm.removeItem(at: scratch) }

		// MARK: Unpack

		await progress(.extracting, 0)
		let extracted = scratch.appendingPathComponent("extracted", isDirectory: true)
		try await Task.detached(priority: .userInitiated) {
			try ZipArchive.unpack(package, to: extracted)
		}.value
		await progress(.extracting, 1)

		let payload = extracted.appendingPathComponent("Payload", isDirectory: true)
		guard let bundle = try? fm.contentsOfDirectory(at: payload, includingPropertiesForKeys: nil)
			.first(where: { $0.pathExtension == "app" })
		else { throw SigningPipelineError.noPayload }

		// MARK: Inject

		if !tweaks.isEmpty {
			await progress(.signing, 0)
			try await Task.detached(priority: .userInitiated) {
				try injectTweaks(tweaks, into: bundle)
			}.value
		}

		// MARK: Prepare

		// Artwork, stripped libraries and entitlements all have to be settled
		// before the signature is taken, or the signature covers a bundle that
		// no longer matches what ships.
		let prepared = try await Task.detached(priority: .userInitiated) {
			try BundlePreparer.prepare(
				bundle: bundle,
				options: options,
				iconFile: customIcon,
				profile: certificateProfile,
				scratch: scratch
			)
		}.value

		// MARK: Sign

		await progress(.signing, 0.35)
		// The engine is synchronous C++. This call is reached from a Task that
		// inherits the main actor, so without detaching it the UI would freeze
		// for the whole signing run — the longest step in the pipeline.
		try await Task.detached(priority: .userInitiated) {
			try await SigningEngine.sign(
				SigningRequest(
					bundlePath: bundle.path,
					provisionPath: certificateProfile.path,
					certificatePath: certificateP12.path,
					certificatePassword: certificate.password,
					// Name, identifier and version are the engine's own
					// overrides — it rewrites Info.plist as part of signing, so
					// nothing on this side has to touch the file.
					overrideIdentifier: options.identifierOverride,
					overrideName: options.nameOverride,
					overrideVersion: options.versionOverride,
					entitlementsPath: prepared.entitlementsPath
				)
			)
		}.value
		await progress(.signing, 1)

		// MARK: Repack

		// Repacking is its own stage in the bar. Reporting it as `.installing`
		// made the ring claim the install had begun while the archive was still
		// being written, and left `.packaging` — a stage the caller lists —
		// permanently unused.
		await progress(.packaging, 0)
		try await Task.detached(priority: .userInitiated) {
			try ZipArchive.pack(extracted, into: destination)
		}.value
		await progress(.packaging, 1)

		let identifier = infoPlist(of: bundle)?["CFBundleIdentifier"] as? String
		return Output(archive: destination, bundleIdentifier: identifier)
	}

	// MARK: Tweaks

	/// Puts every queued tweak inside the bundle and adds a load command for
	/// each dylib. Injection happens before signing so the new load commands
	/// are covered by the signature.
	private static func injectTweaks(_ tweaks: [URL], into bundle: URL) throws {
		guard let executable = executableURL(of: bundle) else {
			throw SigningPipelineError.noExecutable
		}

		let fm = FileManager.default
		let scratch = URL.temporaryDirectory
			.appendingPathComponent("vendor-tweaks-\(UUID().uuidString)", isDirectory: true)
		defer { try? fm.removeItem(at: scratch) }

		var dylibs: [URL] = []
		var resources: [URL] = []

		for tweak in tweaks {
			switch tweak.pathExtension.lowercased() {
			case "dylib":
				dylibs.append(tweak)
			case "deb":
				let unpacked = scratch.appendingPathComponent(UUID().uuidString, isDirectory: true)
				try DebArchive.unpack(tweak, to: unpacked)
				let found = harvest(from: unpacked)
				// A .deb that unpacks cleanly but holds nothing injectable would
				// otherwise sign fine and change nothing, which reads as a bug.
				guard !found.dylibs.isEmpty else {
					throw SigningPipelineError.emptyTweak(tweak.lastPathComponent)
				}
				dylibs.append(contentsOf: found.dylibs)
				resources.append(contentsOf: found.bundles)
			default:
				continue
			}
		}

		guard !dylibs.isEmpty || !resources.isEmpty else { return }

		let frameworks = bundle.appendingPathComponent("Frameworks", isDirectory: true)
		try fm.createDirectory(at: frameworks, withIntermediateDirectories: true)

		// Tweak resource bundles sit beside the executable, which is where the
		// dylibs look for them once the absolute jailbreak paths are gone.
		for resource in resources {
			let destination = bundle.appendingPathComponent(resource.lastPathComponent)
			try? fm.removeItem(at: destination)
			try? fm.copyItem(at: resource, to: destination)
		}

		for dylib in dylibs {
			let destination = frameworks.appendingPathComponent(dylib.lastPathComponent)
			try? fm.removeItem(at: destination)
			try fm.copyItem(at: dylib, to: destination)
			try? fm.setAttributes(
				[.posixPermissions: NSNumber(value: Int16(0o755))],
				ofItemAtPath: destination.path
			)

			rewriteJailbreakPaths(in: destination)

			SigningEngine.inject(
				dylibPath: "@executable_path/Frameworks/\(dylib.lastPathComponent)",
				intoExecutableAt: executable.path
			)
		}
	}

	/// Pulls the payload out of an unpacked .deb: the dylibs a tweak installs,
	/// and any resource bundles that ship alongside them.
	private static func harvest(from root: URL) -> (dylibs: [URL], bundles: [URL]) {
		let fm = FileManager.default
		guard let walker = fm.enumerator(at: root, includingPropertiesForKeys: nil) else {
			return ([], [])
		}

		var dylibs: [URL] = []
		var bundles: [URL] = []

		for case let url as URL in walker {
			switch url.pathExtension.lowercased() {
			case "dylib":
				dylibs.append(url)
			case "bundle":
				bundles.append(url)
				// Everything inside travels with the bundle itself.
				walker.skipDescendants()
			default:
				continue
			}
		}
		return (dylibs, bundles)
	}

	/// Tweaks are built against a jailbroken filesystem and link to absolute
	/// paths that do not exist inside a sandboxed app. Rewriting them to
	/// `@rpath` form is what lets the dynamic linker find a bundled copy —
	/// without it the host app dies at launch with a missing-library error.
	private static func rewriteJailbreakPaths(in dylib: URL) {
		let replacements = [
			"/Library/Frameworks/CydiaSubstrate.framework/CydiaSubstrate":
				"@rpath/CydiaSubstrate.framework/CydiaSubstrate",
			"/usr/lib/libsubstrate.dylib":
				"@rpath/CydiaSubstrate.framework/CydiaSubstrate",
			"/usr/lib/libsubstitute.dylib":
				"@rpath/CydiaSubstrate.framework/CydiaSubstrate",
			"/usr/lib/libellekit.dylib":
				"@rpath/CydiaSubstrate.framework/CydiaSubstrate",
		]

		let linked = SigningEngine.dylibs(inExecutableAt: dylib.path)
		for (old, new) in replacements where linked.contains(old) {
			SigningEngine.changeDylibPath(in: dylib.path, from: old, to: new)
		}
	}

	// MARK: Bundle helpers

	private static func infoPlist(of bundle: URL) -> [String: Any]? {
		let url = bundle.appendingPathComponent("Info.plist")
		guard let data = try? Data(contentsOf: url),
			  let plist = try? PropertyListSerialization.propertyList(
				from: data, options: [], format: nil
			  ) as? [String: Any]
		else { return nil }
		return plist
	}

	/// The bundle's main binary, which is what load commands are added to.
	private static func executableURL(of bundle: URL) -> URL? {
		guard let name = infoPlist(of: bundle)?["CFBundleExecutable"] as? String else {
			return nil
		}
		let url = bundle.appendingPathComponent(name)
		return FileManager.default.fileExists(atPath: url.path) ? url : nil
	}
}
