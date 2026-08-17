//
//  AppLock.swift
//  Vendor
//
//  Whether the app is currently showing its lock screen, and the one place
//  that talks to LocalAuthentication. Not under Vendor/Engine/: this gates
//  the UI, it has nothing to do with signing.
//

import Foundation
import LocalAuthentication
import Combine

@MainActor
final class AppLock: ObservableObject {
	static let shared = AppLock()

	private static let key = "appLockEnabled"

	@Published private(set) var isLocked: Bool

	var enabled: Bool {
		get { UserDefaults.standard.bool(forKey: Self.key) }
		set { UserDefaults.standard.set(newValue, forKey: Self.key) }
	}

	private init() {
		// Locked from the first frame when the preference is already on, not
		// just from the next backgrounding — otherwise turning the app off
		// and back on once, right after enabling it, would skip the lock
		// entirely on that one launch.
		isLocked = UserDefaults.standard.bool(forKey: Self.key)
	}

	/// Whether this device can authenticate at all — Face ID, Touch ID, or a
	/// plain passcode. Checked fresh rather than cached: Settings can change
	/// underneath the app at any time, on a device with none of the three,
	/// `canEvaluatePolicy` is what tells Settings' toggle so.
	func canAuthenticate() -> Bool {
		LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
	}

	/// Called when the app leaves the foreground. A no-op unless the
	/// preference is actually on — flipping the toggle off should not require
	/// also relaunching to stop being asked.
	func lockIfEnabled() {
		guard enabled else { return }
		isLocked = true
	}

	/// `.deviceOwnerAuthentication`, not `...WithBiometrics`: this app has no
	/// login of its own to fall back to, so a passcode has to be an accepted
	/// second path, the same way it is for unlocking the phone itself.
	func authenticate() async {
		let context = LAContext()
		context.localizedReason = t("lock.reason")

		guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil) else {
			// Nothing configured on this device — no biometrics, no passcode.
			// Staying locked here would strand someone with no way out, so
			// this is the one case that unlocks without proving anything.
			isLocked = false
			return
		}

		let success = (try? await context.evaluatePolicy(
			.deviceOwnerAuthentication,
			localizedReason: t("lock.reason")
		)) ?? false

		if success {
			isLocked = false
		}
		// A failure or cancel leaves isLocked true — the lock screen's own
		// Unlock button calls this again rather than retrying on its own.
	}
}
