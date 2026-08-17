//
//  Strings+Settings.swift
//  Vendor
//
//  Strings owned by the Settings panel. Kept apart from the core table so this
//  screen can gain wording without touching the file every other screen uses.
//

import Foundation

extension Strings {
	static let settingsExtras: [String: Entry] = [

		"settings.title":  (en: "Settings", es: "Ajustes"),
		"settings.detail": (
			en: "Appearance, links and what Vendor is built on",
			es: "Apariencia, enlaces y sobre qué está construido Vendor"
		),

		// Appearance
		"settings.appearance": (en: "Appearance", es: "Apariencia"),
		"settings.appearance.system": (en: "System", es: "Sistema"),
		"settings.appearance.light":  (en: "Light",  es: "Claro"),
		"settings.appearance.dark":   (en: "Dark",   es: "Oscuro"),

		// About
		"settings.about":         (en: "About", es: "Acerca de"),
		"settings.versionFormat": (en: "Version %@ (%@)", es: "Versión %@ (%@)"),

		// Links
		"settings.links":    (en: "Links",    es: "Enlaces"),
		"settings.telegram": (en: "Telegram", es: "Telegram"),
		"settings.website":  (en: "Website",  es: "Sitio web"),

		// Open source
		"settings.openSource": (en: "Open Source", es: "Código abierto"),
		"settings.openSourceDetail": (
			en: "The signing engine runs on the libraries below, each used under its own licence.",
			es: "El motor de firma se apoya en las librerías de abajo, cada una bajo su propia licencia."
		),
		"settings.licenseMissing": (
			en: "licence text missing from this build.",
			es: "falta el texto de la licencia en esta versión."
		),

		// Security
		"settings.security": (en: "Security", es: "Seguridad"),
		"settings.appLock": (en: "Require Face ID", es: "Requerir Face ID"),
		"settings.appLockDetail": (
			en: "Lock Vendor whenever it leaves the foreground. Your certificates already never leave the phone — this keeps them from opening on it either, if someone else picks it up.",
			es: "Bloquea Vendor cada vez que deja de estar en primer plano. Tus certificados ya nunca salen del teléfono — esto evita que se abran en él también, si alguien más lo toma."
		),
		"settings.appLockUnavailable": (
			en: "No Face ID, Touch ID or passcode set up on this device.",
			es: "Este dispositivo no tiene Face ID, Touch ID ni código configurado."
		),

		// Storage
		"settings.storage": (en: "Storage", es: "Almacenamiento"),
		"settings.storageDetail": (
			en: "Vendor keeps artwork from apps and repositories on disk so it does not refetch it on every visit.",
			es: "Vendor guarda en el dispositivo las miniaturas de apps y repositorios para no volver a descargarlas cada vez."
		),
		"settings.clearCache":   (en: "Clear cached images", es: "Borrar imágenes en caché"),
		"settings.cacheCleared": (en: "Cache cleared",        es: "Caché borrada"),

		// The lock screen itself — shown over everything else, so it reads
		// apart from the rest of Settings even though the toggle lives there.
		"lock.title":  (en: "Vendor is locked", es: "Vendor está bloqueado"),
		"lock.detail": (
			en: "Unlock to get back to your certificates and packages.",
			es: "Desbloquea para volver a tus certificados y paquetes."
		),
		"lock.unlock": (en: "Unlock", es: "Desbloquear"),
		"lock.reason": (en: "Unlock Vendor", es: "Desbloquear Vendor"),
	]
}
