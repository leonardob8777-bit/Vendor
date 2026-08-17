//
//  Strings+Home.swift
//  Vendor
//
//  Strings owned by the Home area. Kept apart from the core table so this
//  screen can gain wording without touching the file every other screen uses.
//

import Foundation

extension Strings {
	static let homeExtras: [String: Entry] = [

		// Masthead
		"home.heroSubtitle": (
			en: "Sign and install apps on your iPhone",
			es: "Firma e instala apps en tu iPhone"
		),
		// Spoken, so the pill can stay as short as "v0.3.2" on screen.
		"home.version": (en: "Version %@", es: "Versión %@"),

		// Signing identity
		"home.openCertificates": (
			en: "Opens the Certificates tab",
			es: "Abre la pestaña Certificados"
		),
		// Takes the whole "12 days" so the count keeps its plural.
		"home.a11yExpiry": (en: "Expires in %@", es: "Caduca en %@"),
		"home.noExpiry":   (en: "No date",       es: "Sin fecha"),
		"home.expiredWarning": (
			en: "Apps signed with this certificate have stopped opening. Import one that still works and sign them again.",
			es: "Las apps firmadas con este certificado han dejado de abrirse. Importa uno que siga funcionando y vuelve a firmarlas."
		),

		// The empty state, which is the first thing a new install sees and the
		// only place on this screen that has to teach rather than report.
		"home.noCertificateWhy": (
			en: "iOS only opens apps signed by an identity it recognises. Import a .p12 and its profile — Vendor signs with them on the phone, and neither is ever uploaded.",
			es: "iOS solo abre apps firmadas por una identidad que reconoce. Importa un .p12 y su perfil: Vendor firma con ellos en el teléfono y no sube ninguno de los dos."
		),
		"home.howToGetOne": (en: "How to get one", es: "Cómo conseguir uno"),

		// Quick actions. Counts rather than a slogan wherever there is something
		// to count, so a tile says what is behind it instead of describing it.
		"home.onePackage":  (en: "%d package",   es: "%d paquete"),
		"home.packages":    (en: "%d packages",  es: "%d paquetes"),
		"home.oneIdentity": (en: "%d identity",  es: "%d identidad"),
		"home.identities":  (en: "%d identities", es: "%d identidades"),
		// The lit edge on one tile is invisible to VoiceOver on its own.
		"home.nextStep":    (en: "Suggested next step", es: "Siguiente paso sugerido"),
	]
}
