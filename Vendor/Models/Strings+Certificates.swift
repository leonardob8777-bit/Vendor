//
//  Strings+Certificates.swift
//  Vendor
//
//  Strings owned by the Certificates area. Kept apart from the core table so this
//  screen can gain wording without touching the file every other screen uses.
//
//  Written for the person this app actually has: someone who bought a certificate
//  from a reseller by pasting a UDID into a web form, not someone with a paid
//  developer account. Nothing below assumes the words "provisioning profile" mean
//  anything on their own.
//

import Foundation

extension Strings {
	static let certificatesExtras: [String: Entry] = [

		// MARK: The list

		// Which certificate gets used is a fair question with an awkward answer:
		// nothing is "selected". Vendor puts one forward, and each package can
		// override it. The badge names that, and the note explains it — rather
		// than a switch that would imply a setting there is no such thing as.
		"certs.lead": (en: "Main", es: "Principal"),
		"certs.leadNote": (
			en: "Vendor leads with the valid certificate that expires soonest, and counts it down on Home. Any package can be signed with a different one — pick it on the package's own card in the IPA tab.",
			es: "Vendor propone el certificado válido que caduca antes, y es el que descuenta en Inicio. Cualquier paquete puede firmarse con otro: se elige en la tarjeta del propio paquete, en la pestaña IPA."
		),
		"certs.details": (
			en: "Opens what is inside this certificate",
			es: "Abre lo que contiene este certificado"
		),
		"certs.noExpiry": (en: "No end date", es: "Sin fecha de fin"),

		"certs.team":         (en: "Team",     es: "Equipo"),
		"certs.type":         (en: "Type",     es: "Tipo"),
		"certs.worksOn":      (en: "Installs on", es: "Instala en"),
		"certs.expiresLabel": (en: "Expires",  es: "Caduca"),
		"certs.expiredOnLabel": (en: "Expired", es: "Caducó"),
		"certs.importedLabel": (en: "Imported", es: "Importado"),
		"certs.rejectedReason": (en: "Reason", es: "Motivo"),

		"certs.allDevices": (en: "Any device",   es: "Cualquier dispositivo"),
		"certs.deviceOne":  (en: "1 device",     es: "1 dispositivo"),
		"certs.deviceCount": (en: "%d devices",  es: "%d dispositivos"),
		"certs.deviceNote": (
			en: "It installs only on the devices its profile lists — the UDID you handed over when you bought it.",
			es: "Solo instala en los dispositivos que figuran en su perfil: el UDID que entregaste al comprarlo."
		),
		"certs.profileUnreadable": (
			en: "Its profile could not be read.",
			es: "No se pudo leer su perfil."
		),

		// MARK: Deleting

		"certs.deleteConfirm": (
			en: "Delete this certificate?",
			es: "¿Eliminar este certificado?"
		),
		"certs.deleteConfirmDetail": (
			en: "The .p12, its profile and its password are removed from this phone. Apps you already signed keep working until their date runs out. This cannot be undone, and the files cannot be recovered from here.",
			es: "Se borran de este teléfono el .p12, su perfil y su contraseña. Las apps que ya firmaste seguirán funcionando hasta que se les acabe la fecha. No se puede deshacer, y los archivos no se recuperan desde aquí."
		),

		// MARK: Nothing imported yet

		// Three sentences, in the order they happen. Someone landing here with no
		// certificate cannot use a single thing in the app, so this screen owes
		// them the route rather than the fact that the list is empty.
		"certs.emptyStep1": (
			en: "Get this iPhone's UDID: open udid.tech in Safari, on this phone.",
			es: "Consigue el UDID de este iPhone: abre udid.tech en Safari, en este teléfono."
		),
		"certs.emptyStep2": (
			en: "Buy a certificate with it. You get back three things: a .p12 file, a .mobileprovision profile and a password.",
			es: "Compra un certificado con él. Te devuelven tres cosas: un archivo .p12, un perfil .mobileprovision y una contraseña."
		),
		"certs.emptyStep3": (
			en: "Import those three here. From then on Vendor can sign, and none of it leaves the phone.",
			es: "Importa esas tres cosas aquí. A partir de ahí Vendor ya puede firmar, y nada de eso sale del teléfono."
		),
		"certs.emptyFree": (
			en: "A free Apple ID works too — seven days at a time, three apps at once.",
			es: "Un Apple ID gratuito también sirve: siete días cada vez y tres apps como mucho."
		),
		"certs.emptyGuide": (en: "How to get one", es: "Cómo conseguir uno"),

		// MARK: Importing

		"certs.inside": (en: "Inside these files", es: "Lo que traen estos archivos"),
		"certs.showPassword": (en: "Show password", es: "Mostrar contraseña"),
		"certs.hidePassword": (en: "Hide password", es: "Ocultar contraseña"),
		"certs.missingTitle": (en: "Still needed", es: "Todavía falta"),
		"certs.readyTitle":   (en: "Ready to save", es: "Listo para guardar"),
		"certs.passwordSource": (
			en: "The password is the one that came with the certificate, from whoever sold it to you. Vendor keeps it in the iOS keychain — never beside the key, never uploaded.",
			es: "La contraseña es la que vino con el certificado, de quien te lo vendió. Vendor la guarda en el llavero de iOS: nunca junto a la clave, nunca subida a ningún sitio."
		),
		"certs.nicknameHint": (
			en: "Optional. Left empty, the name comes from the profile.",
			es: "Opcional. Si lo dejas vacío, el nombre sale del perfil."
		),
		"certs.discardTitle": (
			en: "Discard this import?",
			es: "¿Descartar esta importación?"
		),
		"certs.discardDetail": (
			en: "The files you picked and the password you typed are not kept.",
			es: "Los archivos que elegiste y la contraseña que escribiste no se guardan."
		),
		"certs.discard": (en: "Discard", es: "Descartar"),

		// MARK: Trust setup

		"trust.openSettings": (en: "Open Settings", es: "Abrir Ajustes"),
		"trust.openSettingsHint": (
			en: "Settings opens on Vendor's own page. Tap back once to reach the top of Settings, where Profile Downloaded is waiting.",
			es: "Ajustes se abre en la página de Vendor. Toca atrás una vez para llegar al principio de Ajustes, donde te espera Perfil descargado."
		),

		// MARK: Expiry notifications

		"certs.notifyToggle": (
			en: "Notify before this expires",
			es: "Avisar antes de que caduque"
		),
		"certs.notifyToggleNote": (
			en: "A local reminder 7 days and 1 day before — nothing leaves the phone to send it.",
			es: "Un aviso local 7 días antes y 1 día antes: no sale nada del teléfono para enviarlo."
		),
		"certs.notify.title": (en: "Certificate expiring", es: "Certificado por caducar"),
		"certs.notify.body7": (
			en: "%@ expires in 7 days. Re-sign your apps before then.",
			es: "%@ caduca en 7 días. Vuelve a firmar tus apps antes de esa fecha."
		),
		"certs.notify.body1": (
			en: "%@ expires tomorrow. Re-sign your apps before it does.",
			es: "%@ caduca mañana. Vuelve a firmar tus apps antes de que pase."
		),
	]
}
