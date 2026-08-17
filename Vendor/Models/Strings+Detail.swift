//
//  Strings+Detail.swift
//  Vendor
//
//  Strings owned by the Detail area. Kept apart from the core table so this
//  screen can gain wording without touching the file every other screen uses.
//
//  The repositories panel writes its new wording here too: it is the other half
//  of the same job — where the apps come from, and what one of them is — and
//  splitting the two across tables would mean editing a shared file to rename a
//  button.
//

import Foundation

extension Strings {
	static let detailExtras: [String: Entry] = [

		// MARK: App detail

		// What Get actually does, spelled out beside the button. The control
		// itself can only fit one word, and the word is the wrong end of the
		// story: fetching a package is not installing it, and the screen where
		// signing happens is somewhere else entirely.
		"detail.getNote": (
			en: "Get downloads it into Vendor. Signing and installing happen on the IPA tab.",
			es: "Obtener la descarga dentro de Vendor. Firmarla e instalarla se hace en la pestaña IPA."
		),
		"detail.onShelf": (
			en: "Already downloaded. Install takes you to the IPA tab to sign it.",
			es: "Ya está descargada. Instalar te lleva a la pestaña IPA para firmarla."
		),
		"detail.onShelfSigned": (
			en: "Downloaded and signed. Install takes you to its card on the IPA tab.",
			es: "Descargada y firmada. Instalar te lleva a su ficha en la pestaña IPA."
		),
		"detail.downloading": (
			en: "Downloading. Tap the ring to call it off.",
			es: "Descargando. Toca el círculo para cancelarla."
		),
		"detail.noDownload": (
			en: "This repository lists the app but publishes no download link for it.",
			es: "Este repositorio lista la app pero no publica ningún enlace de descarga."
		),
		"detail.noInfo": (
			en: "This entry carries no description.",
			es: "Esta entrada no trae descripción."
		),
		"detail.readMore": (en: "Read more",  es: "Leer más"),
		"detail.readLess": (en: "Show less",  es: "Leer menos"),

		"detail.history": (en: "Version history", es: "Historial de versiones"),
		"detail.latest":  (en: "Latest",          es: "Actual"),
		"detail.historyNote": (
			en: "What the repository still lists. Get always fetches the newest one.",
			es: "Lo que el repositorio sigue listando. Obtener siempre trae la más reciente."
		),

		"detail.copyID":  (en: "Copy bundle ID", es: "Copiar el bundle ID"),
		"detail.copied":  (en: "Copied",         es: "Copiado"),

		"detail.shotFailed": (en: "Wouldn't load", es: "No se pudo cargar"),
		"detail.shot":       (en: "Screenshot %d of %d", es: "Captura %d de %d"),
		"detail.viewShot":   (
			en: "View this screenshot full size",
			es: "Ver esta captura a tamaño completo"
		),

		// MARK: Repositories

		"sources.addTitle": (en: "Add a repository", es: "Añadir un repositorio"),
		"sources.addedOK":  (en: "%@ added",         es: "%@ añadido"),
		"sources.failTitle": (en: "Could not add it", es: "No se pudo añadir"),
		"sources.clearField": (en: "Clear the address", es: "Borrar la dirección"),

		"sources.emptyTitle": (en: "None of your own yet", es: "Todavía ninguno tuyo"),
		"sources.emptyDetail": (
			en: "Vendor already shows what it ships with. Paste an address above to add somebody else's — it has to publish a source in AltStore format, usually a link ending in .json.",
			es: "Vendor ya muestra lo que trae de serie. Pega arriba una dirección para añadir la de otra persona: tiene que publicar una fuente en formato AltStore, normalmente un enlace acabado en .json."
		),

		"sources.appsCount":  (en: "%d apps", es: "%d apps"),
		"sources.oneApp":     (en: "1 app",   es: "1 app"),
		"sources.noApps":     (
			en: "Answered, but lists no apps",
			es: "Respondió, pero no lista ninguna app"
		),
		"sources.checkingNow":   (en: "Reading it…",       es: "Leyéndolo…"),
		// Both of these follow the app count, after a middle dot, so they carry
		// on the same sentence rather than starting a new one.
		"sources.checkedNow":    (en: "checked just now",  es: "comprobado ahora"),
		"sources.checkedAgo":    (en: "checked %@",        es: "comprobado %@"),
		"sources.didNotRespond": (en: "Did not respond",   es: "No respondió"),
		"sources.addedOnDate":   (en: "Added %@",          es: "Añadido el %@"),
		"sources.recheck":       (
			en: "Check every repository again",
			es: "Volver a comprobar los repositorios"
		),

		"sources.removeConfirm": (en: "Remove %@?", es: "¿Quitar %@?"),
		"sources.removeConfirmDetail": (
			en: "Its apps leave the Apps tab. Anything you have already downloaded stays where it is, and you can add the repository again with the same address.",
			es: "Sus apps desaparecen de la pestaña Apps. Lo que ya hayas descargado se queda donde está, y puedes volver a añadirlo con la misma dirección."
		),

		"sources.showAllOn": (
			en: "Its whole catalogue is in the Apps tab. Turn it off if the list feels endless.",
			es: "Todo su catálogo está en la pestaña Apps. Apágalo si la lista se te hace interminable."
		),
	]
}
