//
//  SignOptions.swift
//  Vendor
//
//  Everything the user can change about a package before it is signed. Kept as
//  one value so it travels from the card to the pipeline in a single argument,
//  and so it can be stored next to the package and survive a relaunch.
//
//  Nothing here signs anything: the metadata fields end up as the overrides the
//  engine already accepts, and the rest is handled by `BundlePreparer` before
//  the bundle reaches the engine at all.
//

import Foundation

struct SignOptions: Codable, Equatable {

	/// Replacement for `CFBundleDisplayName`. Empty means keep what the package
	/// already has — an empty string would otherwise be signed in as the name.
	var displayName: String = ""
	/// Replacement for `CFBundleIdentifier`.
	var bundleIdentifier: String = ""
	/// Replacement for `CFBundleShortVersionString`.
	var version: String = ""

	/// Signs under a bundle identifier of its own so the package can sit beside
	/// an existing copy instead of replacing it.
	var installAsDuplicate: Bool = false

	/// Adds `get-task-allow`, which is what lets a debugger — and so a JIT
	/// runtime — attach to the signed app.
	var enableJIT: Bool = false

	/// File name of the artwork the user picked, inside the package's folder.
	/// Nil means the package keeps its own icon.
	var customIconName: String?

	/// Names of embedded dylibs and frameworks to strip before signing.
	var removedComponents: [String] = []

	// MARK: Derived

	/// What each override should be sent to the engine as: a trimmed value, or
	/// nil when the field was left alone.
	private static func override(_ raw: String) -> String? {
		let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
		return trimmed.isEmpty ? nil : trimmed
	}

	var nameOverride: String? { Self.override(displayName) }
	var identifierOverride: String? { Self.override(bundleIdentifier) }
	var versionOverride: String? { Self.override(version) }

	/// True when anything at all would be done to the package.
	var isEmpty: Bool {
		nameOverride == nil
		&& identifierOverride == nil
		&& versionOverride == nil
		&& !enableJIT
		&& customIconName == nil
		&& removedComponents.isEmpty
	}

	// MARK: Duplicate identifiers

	/// Builds the identifier a duplicate install should carry.
	///
	/// Derived from whatever identifier is in play — the user's own if they typed
	/// one, otherwise the package's — so turning the toggle on after editing the
	/// field does not throw that edit away.
	static func duplicateIdentifier(from base: String) -> String {
		let stem = base.hasSuffix(".dup") ? base : base + ".dup"
		// A fixed ".dup" collides the second time the trick is needed, so the
		// suffix carries four characters of its own.
		let alphabet = "abcdefghijklmnopqrstuvwxyz0123456789"
		let tail = String((0..<4).map { _ in alphabet.randomElement()! })
		return "\(stem)\(tail)"
	}

	/// Whether `identifier` looks like something `duplicateIdentifier(from:)`
	/// produced, which is what lets the toggle undo its own edit and nothing else.
	static func isGeneratedDuplicate(_ identifier: String) -> Bool {
		guard let range = identifier.range(of: ".dup", options: .backwards) else { return false }
		let tail = identifier[range.upperBound...]
		return tail.count == 4 && tail.allSatisfy { $0.isLowercase || $0.isNumber }
	}
}
