//
//  ProvisioningProfile.swift
//  Vendor
//
//  A .mobileprovision is a CMS-signed container with an XML plist inside.
//  Rather than verify the signature (the engine already vets the pair), this
//  reads the embedded plist purely to show the user what they imported.
//

import Foundation

struct ProvisioningProfile {
	let name: String?
	let teamName: String?
	let expirationDate: Date?
	let applicationIdentifier: String?
	let devices: [String]
	/// Set on an in-house profile, which is what "enterprise" actually means:
	/// it installs on any device rather than on a listed set.
	let provisionsAllDevices: Bool
	/// The profile's own entitlements, verbatim.
	///
	/// A signed app has to carry the entitlements its profile grants, so adding
	/// one means handing the engine this dictionary plus the extra key — not a
	/// file holding the extra key alone, which would strip everything else.
	let entitlements: [String: Any]

	static func read(at url: URL) -> ProvisioningProfile? {
		guard let data = try? Data(contentsOf: url),
			  let plistData = extractPlist(from: data),
			  let plist = try? PropertyListSerialization.propertyList(
				  from: plistData, options: [], format: nil
			  ) as? [String: Any]
		else { return nil }

		let entitlements = plist["Entitlements"] as? [String: Any]

		return ProvisioningProfile(
			name: plist["Name"] as? String,
			teamName: plist["TeamName"] as? String,
			expirationDate: plist["ExpirationDate"] as? Date,
			applicationIdentifier: entitlements?["application-identifier"] as? String,
			devices: plist["ProvisionedDevices"] as? [String] ?? [],
			provisionsAllDevices: plist["ProvisionsAllDevices"] as? Bool ?? false,
			entitlements: entitlements ?? [:]
		)
	}

	/// What kind of profile this is.
	///
	/// Read from the two fields that actually carry the answer rather than from
	/// the certificate's name. `get-task-allow` is what lets a debugger attach,
	/// which only a development profile grants; `ProvisionsAllDevices` is what
	/// makes a profile in-house. Everything else is a distribution profile, and
	/// whether it lists devices only separates ad hoc from App Store — a
	/// distinction with no consequence for signing.
	enum Kind: String {
		case development
		case distribution
		case enterprise
	}

	var kind: Kind {
		if entitlements["get-task-allow"] as? Bool == true { return .development }
		if provisionsAllDevices { return .enterprise }
		return .distribution
	}

	/// Slices out the `<?xml … </plist>` payload embedded in the signature.
	private static func extractPlist(from data: Data) -> Data? {
		guard let open = "<?xml".data(using: .utf8),
			  let close = "</plist>".data(using: .utf8),
			  let start = data.range(of: open),
			  let end = data.range(of: close, options: .backwards)
		else { return nil }
		return data.subdata(in: start.lowerBound..<end.upperBound)
	}
}
