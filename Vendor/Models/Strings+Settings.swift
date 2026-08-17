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

		// Storage
		"settings.storage": (en: "Storage", es: "Almacenamiento"),
		"settings.storageDetail": (
			en: "Vendor keeps artwork from apps and repositories on disk so it does not refetch it on every visit.",
			es: "Vendor guarda en el dispositivo las miniaturas de apps y repositorios para no volver a descargarlas cada vez."
		),
		"settings.clearCache":   (en: "Clear cached images", es: "Borrar imágenes en caché"),
		"settings.cacheCleared": (en: "Cache cleared",        es: "Caché borrada"),
	]
}
