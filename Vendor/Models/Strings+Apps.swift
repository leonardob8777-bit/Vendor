//
//  Strings+Apps.swift
//  Vendor
//
//  Strings owned by the Apps area. Kept apart from the core table so this
//  screen can gain wording without touching the file every other screen uses.
//

import Foundation

extension Strings {
	static let appsExtras: [String: Entry] = [

		// The pinned apps need a heading of their own. Without one they sat above
		// the first repository's header and read as belonging to it — which is
		// the one thing they are not.
		"apps.featured": (en: "Featured", es: "Destacadas"),

		// Searching
		"apps.clearSearch": (en: "Clear search", es: "Borrar búsqueda"),
		"apps.results":     (en: "%d results",   es: "%d resultados"),
		"apps.resultsOne":  (en: "1 result",     es: "1 resultado"),
		"apps.noMatchesDetail": (
			en: "Nothing in the loaded repositories matches “%@”.",
			es: "Nada en los repositorios cargados coincide con «%@»."
		),

		// Ordering. A repository publishes in whatever order it likes, and one of
		// the shipped ones runs to hundreds of entries — long enough that finding
		// anything by eye needs the alphabet.
		"apps.sort":     (en: "Sort",           es: "Ordenar"),
		"apps.sortFeed": (en: "As published",   es: "Orden del repositorio"),
		"apps.sortName": (en: "Name A–Z",       es: "Nombre A–Z"),
		"apps.sortSize": (en: "Biggest first",  es: "Más grandes primero"),

		// Folding a repository away
		"apps.hideApps": (en: "Hide these apps", es: "Ocultar estas apps"),
		"apps.showApps": (en: "Show these apps", es: "Mostrar estas apps"),

		// A download that died. The pill says it in one word; the reason is a tap
		// away rather than in an alert thrown over a list being scrolled.
		"apps.retry": (en: "Retry", es: "Reintentar"),
		"apps.downloadFailedHint": (
			en: "Download failed. Tap to see why.",
			es: "Falló la descarga. Toca para ver el motivo."
		),
	]
}
