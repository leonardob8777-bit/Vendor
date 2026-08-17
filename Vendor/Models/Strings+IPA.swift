//
//  Strings+IPA.swift
//  Vendor
//
//  Strings owned by the IPA area. Kept apart from the core table so this
//  screen can gain wording without touching the file every other screen uses.
//

import Foundation

extension Strings {
	static let ipaExtras: [String: Entry] = [

		// MARK: The four steps

		"ipa.stepImported":    (en: "Imported",    es: "Importada"),
		"ipa.stepCertificate": (en: "Certificate", es: "Certificado"),
		"ipa.stepSign":        (en: "Sign",        es: "Firmar"),
		"ipa.stepInstall":     (en: "Install",     es: "Instalar"),
		// Read aloud in place of the strip, which is a picture of a sentence.
		"ipa.stepOf": (en: "Step %@ of %@: %@", es: "Paso %@ de %@: %@"),
		"ipa.stepCertificateWhy": (
			en: "Choose which identity signs this package.",
			es: "Elige con qué identidad se firma este paquete."
		),
		"ipa.stepSignWhy": (
			en: "Everything is ready. Signing takes a minute or two.",
			es: "Todo listo. Firmar tarda un minuto o dos."
		),
		"ipa.stepInstallWhy": (
			en: "Signed and waiting. Install puts it on this iPhone.",
			es: "Firmada y esperando. Instalar la pone en este iPhone."
		),

		// MARK: The package's own details

		"ipa.details":          (en: "The package",  es: "El paquete"),
		"ipa.fieldSize":        (en: "Size",         es: "Tamaño"),
		"ipa.fieldAdded":       (en: "Added",        es: "Añadida"),
		"ipa.fieldMinimumOS":   (en: "Requires",     es: "Requiere"),
		"ipa.fieldFrameworks":  (en: "Frameworks",   es: "Frameworks"),
		"ipa.fieldExtensions":  (en: "Extensions",   es: "Extensiones"),
		"ipa.fieldSignedWith":  (en: "Signed with",  es: "Firmada con"),
		"ipa.unknownValue":     (en: "Unknown",      es: "Se desconoce"),
		"ipa.reading":          (en: "Reading the package…", es: "Leyendo el paquete…"),
		"ipa.copyBundleID":     (en: "Copy the bundle ID", es: "Copiar el bundle ID"),
		"ipa.copied":           (en: "Copied",       es: "Copiado"),
		"ipa.extensionsWhy": (
			en: "App extensions need App IDs of their own. A free Apple ID certificate normally cannot sign them, and the app installs without them.",
			es: "Las extensiones necesitan App IDs propios. Un certificado de Apple ID gratuito no suele poder firmarlas, y la app se instala sin ellas."
		),
		"ipa.tooNewForDevice": (
			en: "Built for iOS %@ and this iPhone runs %@. It will install and then refuse to open.",
			es: "Hecha para iOS %@ y este iPhone tiene %@. Se instalará y luego se negará a abrir."
		),

		// MARK: Row and queue

		"ipa.needsCertificate": (en: "Needs a certificate", es: "Falta el certificado"),
		"ipa.openPackage":      (en: "Open this package",   es: "Abrir este paquete"),
		"ipa.deleteLabel":      (en: "Delete this package",  es: "Eliminar este paquete"),
		"ipa.cancelQueued":     (en: "Take out of the queue", es: "Sacar de la cola"),
		"ipa.working":          (en: "Working on it",         es: "Trabajando en ella"),
		"ipa.queuedNext":       (en: "%@ goes next",          es: "%@ va después"),

		// MARK: Importing

		"ipa.addTitle": (en: "Add a package", es: "Añadir un paquete"),
		"ipa.addDetail": (
			en: "Vendor signs .ipa files. Take one from Files, or paste a direct link to one.",
			es: "Vendor firma archivos .ipa. Coge uno de Archivos o pega un enlace directo a uno."
		),
		"ipa.chooseFile":     (en: "Choose a file",  es: "Elegir archivo"),
		"ipa.orPasteLink":    (en: "or paste a link", es: "o pega un enlace"),
		"ipa.linkPlaceholder": (en: "https://…/app.ipa", es: "https://…/app.ipa"),
		"ipa.paste":          (en: "Paste",          es: "Pegar"),
		"ipa.download":       (en: "Download",       es: "Descargar"),
		"ipa.downloading":    (en: "Downloading…",   es: "Descargando…"),
		"ipa.badLink": (
			en: "That is not a link Vendor can download. It has to start with https.",
			es: "Ese no es un enlace que Vendor pueda descargar. Tiene que empezar por https."
		),
		"ipa.close":          (en: "Close",          es: "Cerrar"),
		"ipa.flowSummary": (
			en: "Import → pick a certificate → sign → install.",
			es: "Importar → elegir certificado → firmar → instalar."
		),
		"ipa.emptyImported":  (en: "Nothing waiting", es: "Nada pendiente"),
		"ipa.emptyImportedDetail": (
			en: "Every package on the shelf is already signed.",
			es: "Todos los paquetes de la estantería ya están firmados."
		),

		// MARK: Problems
		//
		// Every failure this screen can show is split three ways: what it is
		// called, what the engine said, and what to do about it. The third part
		// is the one that was missing — a raw `localizedDescription` names the
		// fault and leaves the user holding it.

		"ipa.problemImport":  (en: "That file could not be imported", es: "No se pudo importar ese archivo"),
		"ipa.problemSign":    (en: "Signing stopped",       es: "La firma se detuvo"),
		"ipa.problemInstall": (en: "The install stopped",   es: "La instalación se detuvo"),
		"ipa.problemGeneric": (en: "Something went wrong",  es: "Algo salió mal"),
		"ipa.dismissNotice":  (en: "Dismiss",               es: "Descartar"),

		"ipa.fixWrongType": (
			en: "Vendor signs .ipa packages only. A .zip or a bare .app has to be packed as an .ipa first.",
			es: "Vendor solo firma paquetes .ipa. Un .zip o un .app suelto hay que empaquetarlo como .ipa antes."
		),
		"ipa.fixNoSpace": (
			en: "Free some space and try again. Signing needs about three times the size of the package while it works.",
			es: "Libera espacio e inténtalo otra vez. Firmar necesita unas tres veces el tamaño del paquete mientras trabaja."
		),
		"ipa.fixCorrupt": (
			en: "The file is damaged or came down incomplete. Delete it here and fetch it again.",
			es: "El archivo está dañado o llegó incompleto. Bórralo aquí y vuelve a traerlo."
		),
		"ipa.fixCertFiles": (
			en: "One of the certificate's two files is missing. Import it again on the Certificates tab.",
			es: "Falta uno de los dos archivos del certificado. Vuelve a importarlo en la pestaña Certificados."
		),
		"ipa.fixEngine": (
			en: "Almost always the .p12 password. Import the certificate again with the right one.",
			es: "Casi siempre es la contraseña del .p12. Vuelve a importar el certificado con la correcta."
		),
		"ipa.fixTweak": (
			en: "Take that tweak out of the list above and sign without it.",
			es: "Quita ese tweak de la lista de arriba y firma sin él."
		),
		"ipa.fixTrust": (
			en: "This iPhone has to trust Vendor once, in Settings, before iOS will install anything from it.",
			es: "Este iPhone tiene que confiar en Vendor una vez, en Ajustes, antes de que iOS instale nada suyo."
		),
		"ipa.fixInstallRefused": (
			en: "Try again. If iOS keeps refusing, sign the package once more — the signature may have gone stale.",
			es: "Inténtalo otra vez. Si iOS sigue negándose, vuelve a firmar el paquete: puede que la firma haya caducado."
		),
		"ipa.fixCancelled": (
			en: "Nothing was lost. The signed build is still here whenever you want it.",
			es: "No se ha perdido nada. La versión firmada sigue aquí para cuando quieras."
		),
		"ipa.fixNoBuild": (
			en: "Sign the package first, then install what comes out.",
			es: "Firma el paquete primero y luego instala lo que salga."
		),
		"ipa.fixNoBundleID": (
			en: "Type a bundle ID in the options above and sign again.",
			es: "Escribe un bundle ID en las opciones de arriba y vuelve a firmar."
		),

		// MARK: Progress ring

		"ipa.ringProgress": (en: "Progress", es: "Progreso"),
		"ipa.ringStopped":  (en: "Stopped",  es: "Detenido"),

		// MARK: Sign options

		"sign.groupIdentity": (en: "How it looks",    es: "Cómo se ve"),
		"sign.groupInstall":  (en: "How it installs", es: "Cómo se instala"),
		"sign.nameWhy": (
			en: "What you read under the icon on the Home Screen.",
			es: "Lo que se lee bajo el icono en la pantalla de inicio."
		),
		"sign.versionWhy": (
			en: "Cosmetic. iOS shows it in Settings and on the install prompt.",
			es: "Solo cosmético. iOS lo enseña en Ajustes y al pedirte instalar."
		),
		"sign.bundleIDWhy": (
			en: "Its name to iOS. Leave it and this replaces the copy already installed; change it and the two live side by side.",
			es: "Su nombre para iOS. Si lo dejas, sustituye a la copia ya instalada; si lo cambias, las dos conviven."
		),
		"sign.iconWhy": (
			en: "Any square image, so two copies of the same app are not the same picture twice.",
			es: "Cualquier imagen cuadrada, para que dos copias de la misma app no sean el mismo dibujo dos veces."
		),
		"sign.badIdentifier": (
			en: "Letters, numbers, dots and hyphens only.",
			es: "Solo letras, números, puntos y guiones."
		),
		"sign.revertField": (en: "Back to the original", es: "Volver al original"),
		"sign.changeOne":   (en: "1 change",  es: "1 cambio"),
		"sign.changeMany":  (en: "%@ changes", es: "%@ cambios"),
		"sign.resetAll":    (en: "Reset",     es: "Restablecer"),
		"sign.untouched": (
			en: "Nothing changed — it will be signed exactly as it arrived.",
			es: "Sin cambios: se firmará tal y como llegó."
		),
		"sign.componentsWhy": (
			en: "Dropping a library makes the package smaller and breaks whatever needed it. Leave them alone unless you know one is the problem.",
			es: "Quitar una librería hace el paquete más pequeño y rompe lo que dependiera de ella. Déjalas en paz salvo que sepas que una da problemas."
		),
		"sign.componentRemove": (en: "Drop %@", es: "Quitar %@"),
		"sign.componentKeep":   (en: "Keep %@", es: "Conservar %@"),

		// MARK: Re-signing after a certificate change

		"ipa.resignAllA11yOne": (
			en: "Re-sign 1 package with the active certificate",
			es: "Volver a firmar 1 paquete con el certificado activo"
		),
		"ipa.resignAllA11yMany": (
			en: "Re-sign %d packages with the active certificate",
			es: "Volver a firmar %d paquetes con el certificado activo"
		),
		"ipa.resignAllTitleOne": (en: "Re-sign this package?", es: "¿Volver a firmar este paquete?"),
		"ipa.resignAllTitleMany": (en: "Re-sign %d packages?", es: "¿Volver a firmar %d paquetes?"),
		"ipa.resignAllDetailOne": (
			en: "It was signed with a certificate that isn't active anymore. It will be re-signed and reinstalled with %@ instead.",
			es: "Se firmó con un certificado que ya no está activo. Se volverá a firmar y a instalar con %@."
		),
		"ipa.resignAllDetailMany": (
			en: "They were signed with a certificate that isn't active anymore. All %d will be re-signed and reinstalled with %@ — packages sign one at a time, so this can take a while.",
			es: "Se firmaron con un certificado que ya no está activo. Los %d se volverán a firmar e instalar con %@ — los paquetes se firman de uno en uno, así que puede tardar."
		),
		"ipa.resignAllConfirm": (en: "Re-sign all", es: "Volver a firmar todo"),
		"ipa.resigningProgress": (en: "Re-signing %d of %d", es: "Firmando %d de %d"),
		"ipa.resignAllFailedOne": (
			en: "1 package could not be re-signed: %@",
			es: "1 paquete no se pudo volver a firmar: %@"
		),
		"ipa.resignAllFailedMany": (
			en: "%d packages could not be re-signed: %@",
			es: "%d paquetes no se pudieron volver a firmar: %@"
		),
	]
}
