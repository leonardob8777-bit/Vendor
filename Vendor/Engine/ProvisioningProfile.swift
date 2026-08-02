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
			devices: plist["ProvisionedDevices"] as? [String] ?? []
		)
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
