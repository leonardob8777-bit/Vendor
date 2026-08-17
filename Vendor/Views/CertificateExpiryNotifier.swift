//
//  CertificateExpiryNotifier.swift
//  Vendor
//
//  Local notifications for a certificate's own expiry. Sits outside Engine on
//  purpose: it only reads what CertificateStore already publishes and never
//  touches a .p12 or a signature, so nothing here belongs to the signing
//  engine's territory.
//

import Foundation
import UserNotifications

@MainActor
enum CertificateExpiryNotifier {

	/// How far ahead to warn, and the pieces each lead time needs to build its
	/// own request. Two entries rather than a single "days before" list with a
	/// shared body: the copy reads better tailored ("expires tomorrow" instead
	/// of "expires in 1 day"), and the id suffix has to be stable regardless of
	/// wording changes.
	private static let leadTimes: [(days: Int, idSuffix: String, bodyKey: String)] = [
		(7, "d7", "certs.notify.body7"),
		(1, "d1", "certs.notify.body1"),
	]

	private static func identifiers(for id: UUID) -> [String] {
		leadTimes.map { "\(id.uuidString).expiry.\($0.idSuffix)" }
	}

	private static func defaultsKey(for id: UUID) -> String { "certNotify.\(id.uuidString)" }

	/// Mirrors `CertificateDetailSheet`'s `@AppStorage(wrappedValue: true, ...)`
	/// on the same key. `UserDefaults` has no notion of "not yet set" once read
	/// through `@AppStorage` — it just returns the wrapped default — so this
	/// reads the raw value directly rather than through the property wrapper,
	/// which only the view owns an instance of.
	static func isEnabled(for id: UUID) -> Bool {
		let key = defaultsKey(for: id)
		guard UserDefaults.standard.object(forKey: key) != nil else { return true }
		return UserDefaults.standard.bool(forKey: key)
	}

	/// Cancels whatever this certificate has pending, then rebuilds it from
	/// scratch if there is anything to warn about. Always removing first is
	/// what makes calling this again for the same certificate a replace
	/// rather than a pile-up — re-importing under the same id, or the sheet's
	/// toggle flipping back on, both just call this again.
	///
	/// Assumes authorization has already been decided one way or the other;
	/// callers are the only ones who know whether asking is appropriate.
	private static func reschedule(for certificate: StoredCertificate) {
		let center = UNUserNotificationCenter.current()
		center.removePendingNotificationRequests(withIdentifiers: identifiers(for: certificate.id))

		guard isEnabled(for: certificate.id), let expiresAt = certificate.expiresAt else { return }

		let calendar = Calendar.current
		let now = Date()

		for lead in leadTimes {
			guard let fireDate = calendar.date(byAdding: .day, value: -lead.days, to: expiresAt),
				  fireDate > now
			else { continue } // already past — nothing to fire, so nothing is scheduled for it

			let content = UNMutableNotificationContent()
			content.title = t("certs.notify.title")
			content.body = String(format: t(lead.bodyKey), certificate.name)
			content.sound = .default

			// Every field down to the second, not just year/month/day: a
			// `UNCalendarNotificationTrigger` fires the next moment its date
			// components match, and a trigger built from only the date part
			// matches at midnight — every midnight, forever, since `repeats`
			// defaults to matching whenever the components recur. Filling in
			// the time as well pins it to the single instant `fireDate` names,
			// and `repeats: false` on top means it fires there once and is done.
			let components = calendar.dateComponents(
				[.year, .month, .day, .hour, .minute, .second],
				from: fireDate
			)
			let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

			let request = UNNotificationRequest(
				identifier: "\(certificate.id.uuidString).expiry.\(lead.idSuffix)",
				content: content,
				trigger: trigger
			)
			center.add(request)
		}
	}

	/// One certificate changed on its own — imported just now, or its toggle
	/// in the detail sheet flipped. Scoped permission handling: asks only if
	/// this certificate is the reason to ask (enabled, and has a date to warn
	/// about), so flipping a toggle off never triggers a prompt.
	static func apply(to certificate: StoredCertificate) {
		Task {
			let center = UNUserNotificationCenter.current()
			let settings = await center.notificationSettings()

			switch settings.authorizationStatus {
			case .denied:
				// Removing pending requests needs no permission, so turning
				// the toggle off still does something even though iOS was
				// never going to deliver anything either way.
				center.removePendingNotificationRequests(withIdentifiers: identifiers(for: certificate.id))
			case .notDetermined:
				guard isEnabled(for: certificate.id), certificate.expiresAt != nil else { return }
				guard let granted = try? await center.requestAuthorization(options: [.alert, .sound, .badge]),
					  granted
				else { return }
				reschedule(for: certificate)
			default:
				// .authorized, .provisional, .ephemeral, and any case Apple
				// adds later — all of them mean "already decided, and not
				// denied", which is the only distinction scheduling cares
				// about.
				reschedule(for: certificate)
			}
		}
	}

	/// The whole store at once — on launch, as a resync, and after an import
	/// or a delete changes which certificates exist. Only place that removes
	/// a *deleted* certificate's leftover requests: `apply(to:)` only ever
	/// hears about a certificate that still exists.
	static func sync(_ certificates: [StoredCertificate]) {
		Task {
			let center = UNUserNotificationCenter.current()

			let liveIDs = Set(certificates.map { $0.id.uuidString })
			let pending = await center.pendingNotificationRequests()
			let stale = pending.map(\.identifier).filter { identifier in
				// Identifiers are "<uuid>.expiry.<suffix>" — the uuid never
				// contains a ".", so the first component is always it.
				guard let idPart = identifier.split(separator: ".").first else { return false }
				return !liveIDs.contains(String(idPart))
			}
			if !stale.isEmpty {
				center.removePendingNotificationRequests(withIdentifiers: stale)
			}

			let settings = await center.notificationSettings()
			switch settings.authorizationStatus {
			case .denied:
				return
			case .notDetermined:
				// Nothing pushy about asking on a bare launch with no
				// certificates yet — there is nothing to warn about, so
				// nothing prompts. The first import with an expiry date is
				// what actually asks.
				let needsPermission = certificates.contains { isEnabled(for: $0.id) && $0.expiresAt != nil }
				guard needsPermission else { return }
				guard let granted = try? await center.requestAuthorization(options: [.alert, .sound, .badge]),
					  granted
				else { return }
				certificates.forEach(reschedule)
			default:
				certificates.forEach(reschedule)
			}
		}
	}
}
