//
//  Localization.swift
//  Vendor
//
//  In-app language switching. Deliberately not .strings files: those follow the
//  system language and only change when the user leaves the app for Settings,
//  and the whole point here is a switch inside Vendor that takes effect at once.
//
//  Reading `Localizer.shared.language` inside a view body registers the view as
//  an observer, so flipping the language redraws every screen immediately.
//

import Foundation
import Observation

enum Language: String, CaseIterable, Identifiable {
	case english = "en"
	case spanish = "es"

	var id: String { rawValue }

	/// Shown in the picker, each in its own language.
	var name: String {
		switch self {
		case .english: return "English"
		case .spanish: return "Español"
		}
	}

	var shortCode: String {
		switch self {
		case .english: return "EN"
		case .spanish: return "ES"
		}
	}

	var flag: String {
		switch self {
		case .english: return "🇬🇧"
		case .spanish: return "🇪🇸"
		}
	}
}

@Observable
final class Localizer {
	static let shared = Localizer()

	private static let key = "vendor.language"

	var language: Language {
		didSet {
			guard language != oldValue else { return }
			UserDefaults.standard.set(language.rawValue, forKey: Self.key)
		}
	}

	private init() {
		// First launch follows the device, so a Spanish phone opens in Spanish.
		if let stored = UserDefaults.standard.string(forKey: Self.key),
		   let saved = Language(rawValue: stored) {
			language = saved
		} else {
			let preferred = Locale.preferredLanguages.first ?? "en"
			language = preferred.hasPrefix("es") ? .spanish : .english
		}
	}

	func string(_ key: String) -> String {
		guard let entry = Strings.table[key] else {
			// A missing key shows itself rather than silently rendering blank.
			assertionFailure("Missing translation for \(key)")
			return key
		}
		switch language {
		case .english: return entry.en
		case .spanish: return entry.es
		}
	}
}

/// Shorthand used throughout the views.
func t(_ key: String) -> String { Localizer.shared.string(key) }

// MARK: - Table

enum Strings {
	static let table: [String: (en: String, es: String)] = [

		// Tabs
		"tab.home":         (en: "Home",         es: "Inicio"),
		"tab.apps":         (en: "Apps",         es: "Apps"),
		"tab.ipa":          (en: "IPA",          es: "IPA"),
		"tab.certificates": (en: "Certificates", es: "Certificados"),
		"tab.guide":        (en: "Guide",        es: "Guía"),

		// Home
		"home.tagline":        (en: "Leonardo Bt · iOS Hub", es: "Leonardo Bt · iOS Hub"),
		"home.quickActions":   (en: "Quick Actions",         es: "Acciones rápidas"),
		"home.signingIdentity": (en: "Signing identity",     es: "Identidad de firma"),
		"home.noCertificate":  (en: "No certificate",        es: "Sin certificado"),
		"home.nothingToSign":  (en: "Nothing to sign with yet.", es: "Aún no hay con qué firmar."),
		"home.importCertificate": (en: "Import certificate", es: "Importar certificado"),
		"home.active":         (en: "Active",                es: "Activo"),
		"home.expired":        (en: "Expired",               es: "Caducado"),
		"home.expiringSoon":   (en: "Expiring soon",         es: "Caduca pronto"),
		"home.rejected":       (en: "Rejected",              es: "Rechazado"),
		"home.privateByDesign": (en: "Private by design",    es: "Privado por diseño"),
		"home.recommended":    (en: "Recommended",           es: "Recomendado"),
		"home.stayUpdated":    (en: "Stay updated",          es: "Mantente al día"),
		"home.telegram":       (en: "Join the Telegram channel", es: "Únete al canal de Telegram"),
		"home.telegramDetail": (
			en: "New IPAs, certificates and updates first",
			es: "IPAs, certificados y novedades antes que nadie"
		),
		"home.websiteDetail":  (
			en: "Signed IPAs, certificates and guides",
			es: "IPAs firmadas, certificados y guías"
		),
		"home.disclaimer":     (
			en: "Not affiliated with Apple Inc. Use at your own risk.",
			es: "Sin relación con Apple Inc. Úsalo bajo tu propia responsabilidad."
		),

		"home.expiring":       (en: "Expiring",             es: "Caducando"),
		"home.validUntil":     (en: "Valid until %@",       es: "Válido hasta %@"),
		"home.expiredOn":      (en: "Expired on %@",        es: "Caducó el %@"),
		"home.resignWarning":  (
			en: "Re-sign your apps before this certificate expires.",
			es: "Vuelve a firmar tus apps antes de que caduque este certificado."
		),
		"home.engineLoaded":   (en: "the engine loaded",     es: "el motor cargado"),
		"home.engineMissing":  (en: "no engine available",   es: "sin motor disponible"),
		"home.signingRuns":    (
			en: "Signing runs on your device with %@. Your certificates never leave the phone.",
			es: "La firma se ejecuta en tu dispositivo con %@. Tus certificados nunca salen del teléfono."
		),
		"home.day":            (en: "day",  es: "día"),
		"home.days":           (en: "days", es: "días"),
		"home.noAccount":      (en: "No account",   es: "Sin cuenta"),
		"home.noAnalytics":    (en: "No analytics", es: "Sin analíticas"),
		"home.noTracking":     (en: "No tracking",  es: "Sin rastreo"),

		// Quick actions
		"quick.ipa":           (en: "IPA",             es: "IPA"),
		"quick.ipaDetail":     (en: "Sign your own",   es: "Firma las tuyas"),
		"quick.certs":         (en: "Certificates",    es: "Certificados"),
		"quick.certsDetail":   (en: "Manage identities", es: "Gestiona identidades"),
		"quick.apps":          (en: "Apps",            es: "Apps"),
		"quick.appsDetail":    (en: "Browse the source", es: "Explora la fuente"),
		"quick.guides":        (en: "Guides",          es: "Guías"),
		"quick.guidesDetail":  (en: "Step by step",    es: "Paso a paso"),

		// Language picker
		"language.title":   (en: "Language",        es: "Idioma"),
		"language.detail":  (en: "Choose the language Vendor uses.", es: "Elige el idioma de Vendor."),

		// Apps
		"apps.loading":     (en: "Loading apps…",       es: "Cargando apps…"),
		"apps.failed":      (en: "Could not load apps", es: "No se pudieron cargar las apps"),
		"apps.tryAgain":    (en: "Try again",           es: "Reintentar"),
		"apps.noMatches":   (en: "No matches",          es: "Sin resultados"),
		"apps.search":      (en: "Search apps...",      es: "Buscar apps..."),
		"apps.get":         (en: "Get",                 es: "Obtener"),
		"apps.source":      (en: "Source",              es: "Fuente"),
		"apps.downloadFailed": (en: "Download failed",  es: "Falló la descarga"),
		"apps.cancelDownload": (en: "Cancel download",  es: "Cancelar descarga"),
		"err.bundled.missing": (
			en: "That app is missing from this build of Vendor.",
			es: "Esa app no viene incluida en esta versión de Vendor."
		),
		"apps.about":       (en: "About",               es: "Acerca de"),
		"apps.whatsNew":    (en: "What's New",          es: "Novedades"),
		"apps.preview":     (en: "Preview",             es: "Vista previa"),
		"apps.version":     (en: "Version",             es: "Versión"),
		"apps.size":        (en: "Size",                es: "Tamaño"),
		"apps.released":    (en: "Released",            es: "Publicado"),

		// IPA
		"ipa.all":          (en: "All",       es: "Todas"),
		"ipa.imported":     (en: "Imported",  es: "Importadas"),
		"ipa.signed":       (en: "Signed",    es: "Firmadas"),
		"ipa.noPackages":   (en: "No packages", es: "Sin paquetes"),
		"ipa.nothingSigned": (en: "Nothing signed yet", es: "Nada firmado todavía"),
		"ipa.emptyDetail":  (
			en: "Import an .ipa to sign it with your own certificate.",
			es: "Importa un .ipa para firmarlo con tu propio certificado."
		),
		"ipa.signedEmptyDetail": (
			en: "Signed packages will appear here.",
			es: "Los paquetes firmados aparecerán aquí."
		),
		"ipa.import":       (en: "Import IPA",  es: "Importar IPA"),
		"ipa.importing":    (en: "Importing…",  es: "Importando…"),
		"ipa.certificate":  (en: "Signing certificate", es: "Certificado de firma"),
		"ipa.noCertificates": (
			en: "No certificates imported yet.",
			es: "Aún no has importado ningún certificado."
		),
		"ipa.tweaks":       (en: "Tweaks to inject", es: "Tweaks a inyectar"),
		"ipa.add":          (en: "Add",              es: "Añadir"),
		"ipa.noTweaks":     (
			en: "None. Add a .dylib or .deb to inject it on signing.",
			es: "Ninguno. Añade un .dylib o .deb para inyectarlo al firmar."
		),
		"ipa.sign":         (en: "Sign",        es: "Firmar"),
		"ipa.signAgain":    (en: "Sign again",  es: "Firmar de nuevo"),
		"ipa.install":      (en: "Install",   es: "Instalar"),
		"ipa.stateImported": (en: "Imported", es: "Importada"),
		"ipa.stateSigned":   (en: "Signed",   es: "Firmada"),

		// MARK: Sign options

		"sign.options":   (en: "Before signing",   es: "Antes de firmar"),
		"sign.name":      (en: "Name",             es: "Nombre"),
		"sign.bundleID":  (en: "Bundle ID",        es: "Bundle ID"),
		"sign.version":   (en: "Version",          es: "Versión"),
		"sign.icon":      (en: "App icon",         es: "Icono de la app"),
		"sign.iconChoose": (en: "Choose",          es: "Elegir"),
		"sign.iconClear":  (en: "Reset",           es: "Quitar"),
		"sign.duplicate": (en: "Install as duplicate", es: "Instalar como copia"),
		"sign.duplicateWhy": (
			en: "Signs under its own bundle ID so it sits beside the installed copy.",
			es: "Firma con un bundle ID propio para que quede junto a la copia instalada."
		),
		"sign.jit":       (en: "Enable JIT",       es: "Activar JIT"),
		"sign.jitWhy": (
			en: "Adds get-task-allow, which lets a debugger or JIT runtime attach.",
			es: "Añade get-task-allow, que permite enganchar un depurador o un runtime JIT."
		),
		"sign.advanced":  (en: "Advanced",         es: "Avanzado"),
		"sign.components": (
			en: "Embedded libraries",
			es: "Librerías embebidas"
		),
		"sign.noComponents": (
			en: "This package embeds none.",
			es: "Este paquete no lleva ninguna."
		),

		// MARK: Pre-sign check

		"preflight.noCert": (
			en: "Pick a signing certificate above to enable signing.",
			es: "Elige arriba un certificado de firma para poder firmar."
		),
		"preflight.lowSpace": (
			en: "Only %@ free — signing this needs about %@.",
			es: "Solo quedan %@ libres — firmar esto necesita unos %@."
		),
		"err.store.notAPackage": (
			en: "That file is not an .ipa. The download probably returned an error page instead of the app.",
			es: "Ese archivo no es un .ipa. La descarga probablemente devolvió una página de error en vez de la app."
		),
		"err.install.simulator": (
			en: "The simulator cannot install apps — itms-services only exists on a real device. Run this on your iPhone.",
			es: "El simulador no puede instalar apps: itms-services solo existe en un dispositivo real. Pruébalo en tu iPhone."
		),
		"err.prepare.icon": (
			en: "That image could not be used as an icon.",
			es: "Esa imagen no se pudo usar como icono."
		),
		"err.prepare.entitlements": (
			en: "The entitlements file could not be written.",
			es: "No se pudo escribir el archivo de entitlements."
		),
		"task.installedOK": (en: "All done",  es: "Todo listo"),
		"task.installedDetail": (
			en: "%@ is signed and installed on your device.",
			es: "%@ está firmada e instalada en tu dispositivo."
		),
		"task.openApp":     (en: "Open app",  es: "Abrir app"),

		"ipa.pickCertFirst": (
			en: "Choose a certificate for %@ first.",
			es: "Elige antes un certificado para %@."
		),
		"ipa.certRejected": (
			en: "%@ was rejected by the signing engine.",
			es: "El motor de firma rechazó %@."
		),
		"ipa.pickIpaOnly":   (en: "Pick an .ipa file.", es: "Elige un archivo .ipa."),
		"ipa.tweakTypeOnly": (
			en: "Tweaks must be .dylib or .deb.",
			es: "Los tweaks deben ser .dylib o .deb."
		),

		// Certificates
		"certs.new":        (en: "New Certificate", es: "Nuevo certificado"),
		"certs.newDetail":  (
			en: "Import your .p12 certificate and mobile provisioning profile.",
			es: "Importa tu certificado .p12 y tu perfil de aprovisionamiento."
		),
		"certs.empty":      (en: "No certificates", es: "Sin certificados"),
		"certs.emptyDetail": (
			en: "Import a .p12 and a .mobileprovision to start signing.",
			es: "Importa un .p12 y un .mobileprovision para empezar a firmar."
		),
		"certs.passwordHint": (
			en: "Leave the password empty if your private key does not require one.",
			es: "Deja la contraseña vacía si tu clave privada no la necesita."
		),
		"certs.save":       (en: "Save",     es: "Guardar"),
		"certs.password":   (en: "Password", es: "Contraseña"),
		"certs.nickname":   (en: "Nickname", es: "Apodo"),
		"certs.none":       (en: "None",     es: "Ninguno"),
		"certs.groupRevoked":    (en: "Revoked",    es: "Revocados"),
		"certs.groupDeveloper":  (en: "Developer",  es: "Desarrollador"),
		"certs.groupEnterprise": (en: "Enterprise", es: "Empresarial"),

		// Progress
		"task.downloading": (en: "Downloading", es: "Descargando"),
		"task.unpacking":   (en: "Unpacking",   es: "Descomprimiendo"),
		"task.signing":     (en: "Signing",     es: "Firmando"),
		"task.packaging":   (en: "Packaging",   es: "Empaquetando"),
		"task.installing":  (en: "Installing",  es: "Instalando"),
		"task.done":        (en: "Done",        es: "Listo"),
		"task.failed":      (en: "Couldn't finish", es: "No se pudo terminar"),
		"task.keepOpen":    (en: "Please keep Vendor open.", es: "Mantén Vendor abierto."),
		"task.dontClose":   (en: "Don't close the app",      es: "No cierres la app"),
		"task.doneButton":  (en: "Done",        es: "Hecho"),
		"task.cancelButton": (en: "Cancel",     es: "Cancelar"),
		"task.confirmPrompt": (
			en: "Confirm the install in the iOS prompt.",
			es: "Confirma la instalación en el aviso de iOS."
		),

		// Guide

		// Errors — these surface in the UI, so they carry the language too.
		"err.pipeline.noPayload": (
			en: "This package has no Payload folder, so it is not a valid .ipa.",
			es: "Este paquete no tiene carpeta Payload, así que no es un .ipa válido."
		),
		"err.pipeline.noExecutable": (
			en: "The app bundle does not name an executable.",
			es: "El paquete de la app no indica ningún ejecutable."
		),
		"err.pipeline.certMissing": (
			en: "The certificate files are missing. Import the certificate again.",
			es: "Faltan los archivos del certificado. Vuelve a importarlo."
		),
		"err.engine.rejected": (
			en: "The signing engine refused the request.",
			es: "El motor de firma rechazó la petición."
		),
		"err.zip.unreadable": (
			en: "The package could not be opened.",
			es: "No se pudo abrir el paquete."
		),
		"err.zip.corrupt":    (en: "The package is damaged: %@", es: "El paquete está dañado: %@"),
		"err.zip.cannotWrite": (
			en: "Could not write the package: %@",
			es: "No se pudo escribir el paquete: %@"
		),
		"err.zip.tooLarge": (
			en: "This app is too big for the package format: over 4 GB or more than 65,535 files.",
			es: "Esta app es demasiado grande para el formato de paquete: pasa de 4 GB o de 65.535 archivos."
		),
		"err.store.unreadable": (
			en: "That file could not be opened.",
			es: "No se pudo abrir ese archivo."
		),
		"err.store.cannotWrite": (
			en: "Could not save the package: %@",
			es: "No se pudo guardar el paquete: %@"
		),
		"err.cert.unreadable": (
			en: "The selected file could not be opened.",
			es: "No se pudo abrir el archivo seleccionado."
		),
		"err.cert.cannotWrite": (
			en: "Could not save the certificate: %@",
			es: "No se pudo guardar el certificado: %@"
		),
		"err.download.badStatus": (
			en: "The download failed (HTTP %@).",
			es: "La descarga falló (HTTP %@)."
		),
		"err.download.cannotWrite": (
			en: "Could not write the downloaded file.",
			es: "No se pudo escribir el archivo descargado."
		),
		"err.source.badStatus": (
			en: "The source responded with HTTP %@.",
			es: "La fuente respondió con HTTP %@."
		),
		"err.source.malformed": (
			en: "The source did not return a readable app list.",
			es: "La fuente no devolvió una lista de apps legible."
		),

		// Installing
		"ipa.export": (en: "Export a copy instead", es: "Exportar una copia"),
		"err.install.noBuild": (
			en: "There is no signed build to install. Sign the package first.",
			es: "No hay ninguna versión firmada que instalar. Firma el paquete primero."
		),
		"err.install.noBundleID": (
			en: "This package has no bundle identifier, so iOS cannot install it.",
			es: "Este paquete no tiene identificador, así que iOS no puede instalarlo."
		),
		"err.install.notTrusted": (
			en: "Vendor's install certificate is not trusted on this device yet.",
			es: "El certificado de instalación de Vendor aún no es de confianza en este dispositivo."
		),
		"err.install.refused": (
			en: "iOS refused to start the install.",
			es: "iOS se negó a iniciar la instalación."
		),
		"err.install.cancelled": (
			en: "Install cancelled. The signed build is still here — tap Install to try again.",
			es: "Instalación cancelada. La app firmada sigue aquí: toca Instalar para reintentarlo."
		),
		"err.server.identity": (
			en: "Could not prepare the local install certificate.",
			es: "No se pudo preparar el certificado de instalación local."
		),
		"err.server.listen": (
			en: "Could not start the local install server: %@",
			es: "No se pudo iniciar el servidor de instalación local: %@"
		),
		"err.local.key": (
			en: "Could not create the install key.",
			es: "No se pudo crear la clave de instalación."
		),
		"err.local.sign": (
			en: "Could not sign the install certificate.",
			es: "No se pudo firmar el certificado de instalación."
		),
		"err.local.identity": (
			en: "Could not assemble the install identity.",
			es: "No se pudo montar la identidad de instalación."
		),

		"err.pack.unreachable": (
			en: "Could not reach the install certificate service. Check your connection.",
			es: "No se pudo contactar con el servicio de certificados. Revisa tu conexión."
		),
		"err.pack.malformed": (
			en: "The install certificate service returned something unreadable.",
			es: "El servicio de certificados devolvió algo ilegible."
		),
		"err.pack.expired": (
			en: "The install certificate has expired. Try again later.",
			es: "El certificado de instalación caducó. Inténtalo más tarde."
		),
		"err.pack.invalid": (
			en: "The install certificate could not be used.",
			es: "No se pudo usar el certificado de instalación."
		),

		// Trust setup
		"trust.title":  (en: "One-time setup", es: "Configuración inicial"),
		"trust.detail": (
			en: "To install apps directly, iOS needs to trust Vendor's own certificate. You only do this once.",
			es: "Para instalar apps directamente, iOS necesita confiar en el certificado de Vendor. Esto se hace una sola vez."
		),
		"trust.step1": (
			en: "Tap Download certificate below, then choose Save to Files or open it — iOS will say the profile was downloaded.",
			es: "Toca Descargar certificado abajo y elige Guardar en Archivos o ábrelo — iOS dirá que se descargó el perfil."
		),
		"trust.step2": (
			en: "Settings › Profile Downloaded › Install (top right). Enter your passcode and confirm.",
			es: "Ajustes › Perfil descargado › Instalar (arriba a la derecha). Escribe tu código y confirma."
		),
		"trust.step3": (
			en: "Settings › General › About › Certificate Trust Settings, then turn on Vendor Local Authority.",
			es: "Ajustes › General › Información › Ajustes de confianza de certificados, y activa Vendor Local Authority."
		),
		"trust.why": (
			en: "This certificate is generated on your device and never leaves it. It only lets Vendor hand packages to iOS over a connection to itself.",
			es: "Este certificado se genera en tu dispositivo y nunca sale de él. Solo permite que Vendor entregue paquetes a iOS por una conexión consigo mismo."
		),
		"trust.download": (en: "Download certificate", es: "Descargar certificado"),
		"trust.done":     (en: "I've done it — continue", es: "Ya está — continuar"),
		"trust.later":    (en: "Later", es: "Más tarde"),

		// Debian packages
		"deb.notArchive": (
			en: "That file is not a readable .deb package.",
			es: "Ese archivo no es un paquete .deb legible."
		),
		"deb.noPayload": (
			en: "The .deb has no data payload to install.",
			es: "El .deb no tiene contenido que instalar."
		),
		"deb.unsupported": (
			en: "This .deb uses %@ compression, which Vendor cannot read. Ask for a .dylib instead.",
			es: "Este .deb usa compresión %@, que Vendor no puede leer. Pide un .dylib en su lugar."
		),
		"deb.corrupt": (en: "The .deb is damaged: %@", es: "El .deb está dañado: %@"),
		"deb.noTweakInside": (
			en: "%@ contains no tweak to inject.",
			es: "%@ no contiene ningún tweak que inyectar."
		),

		"guide.install.title":  (en: "How to install apps", es: "Cómo instalar apps"),
		"guide.install.detail": (
			en: "From certificate to a working app on your Home Screen",
			es: "Del certificado a una app funcionando en tu pantalla de inicio"
		),
		"guide.install.p1": (
			en: "iOS only runs apps that carry a valid signature. Vendor signs an app with your own certificate so your device will accept it.",
			es: "iOS solo ejecuta apps con una firma válida. Vendor firma la app con tu propio certificado para que tu dispositivo la acepte."
		),
		"guide.install.h1": (en: "Before you start", es: "Antes de empezar"),
		"guide.install.s1": (
			en: "Import a signing identity: a .p12 private key and its matching .mobileprovision profile.",
			es: "Importa una identidad de firma: una clave privada .p12 y su perfil .mobileprovision correspondiente."
		),
		"guide.install.s2": (
			en: "Check the Home screen — the certificate must show days remaining, not Expired or Rejected.",
			es: "Mira la pantalla de inicio: el certificado debe mostrar días restantes, no Caducado ni Rechazado."
		),
		"guide.install.h2": (en: "Install an app", es: "Instalar una app"),
		"guide.install.s3": (
			en: "Pick an app from the Apps tab, or import an .ipa file you already have.",
			es: "Elige una app en la pestaña Apps, o importa un archivo .ipa que ya tengas."
		),
		"guide.install.s4": (
			en: "Vendor unpacks it, signs it with your certificate and hands it to iOS.",
			es: "Vendor la descomprime, la firma con tu certificado y se la entrega a iOS."
		),
		"guide.install.s5": (
			en: "Approve the install prompt on your device.",
			es: "Acepta el aviso de instalación en tu dispositivo."
		),
		"guide.install.s6": (
			en: "If iOS says the developer is not trusted, follow the trust guide.",
			es: "Si iOS dice que el desarrollador no es de confianza, sigue la guía de confianza."
		),
		"guide.install.note": (
			en: "The device you install on must be listed in the provisioning profile. A profile made for a different device will sign fine and then refuse to open.",
			es: "El dispositivo donde instales debe figurar en el perfil de aprovisionamiento. Un perfil hecho para otro dispositivo firmará sin problema y luego se negará a abrir."
		),
		"guide.install.warn": (
			en: "Developer Mode is required for development-signed apps on iOS 16 and later. Settings › Privacy & Security › Developer Mode, then restart. Apps signed with a distribution certificate do not need it.",
			es: "El Modo Desarrollador es obligatorio para apps firmadas en desarrollo desde iOS 16. Ajustes › Privacidad y seguridad › Modo Desarrollador, y reinicia. Las apps firmadas con un certificado de distribución no lo necesitan."
		),

		"guide.trust.title":  (en: "How to trust a certificate", es: "Cómo confiar en un certificado"),
		"guide.trust.detail": (
			en: "Tell iOS the developer behind your app is allowed to run",
			es: "Dile a iOS que el desarrollador de tu app tiene permiso para ejecutarse"
		),
		"guide.trust.p1": (
			en: "The first time you install an app signed outside the App Store, iOS blocks it until you confirm you trust whoever signed it.",
			es: "La primera vez que instalas una app firmada fuera de la App Store, iOS la bloquea hasta que confirmes que confías en quien la firmó."
		),
		"guide.trust.h1": (en: "Steps", es: "Pasos"),
		"guide.trust.s1": (
			en: "Open Settings › General › VPN & Device Management.",
			es: "Abre Ajustes › General › VPN y gestión de dispositivos."
		),
		"guide.trust.s2": (
			en: "Under Enterprise App, tap the developer name shown for your app.",
			es: "En App empresarial, toca el nombre del desarrollador que aparece para tu app."
		),
		"guide.trust.s3": (
			en: "Tap Trust \"[developer name]\".",
			es: "Toca Confiar en \"[nombre del desarrollador]\"."
		),
		"guide.trust.s4": (
			en: "On iOS 18 and later, tap Allow & Restart. Your device will reboot.",
			es: "En iOS 18 o posterior, toca Permitir y reiniciar. Tu dispositivo se reiniciará."
		),
		"guide.trust.s5": (
			en: "After it restarts, unlock the phone and follow the prompt to finish.",
			es: "Cuando se reinicie, desbloquea el teléfono y sigue el aviso para terminar."
		),
		"guide.trust.warn": (
			en: "You must be online. iOS contacts Apple to check the certificate has not been revoked before it lets you trust it.",
			es: "Necesitas conexión. iOS consulta a Apple para comprobar que el certificado no está revocado antes de dejarte confiar en él."
		),
		"guide.trust.note": (
			en: "Do not confuse this with Certificate Trust Settings, further down in Settings › General › About. That screen is for root certificates and is not part of installing an app.",
			es: "No lo confundas con Ajustes de confianza de certificados, más abajo en Ajustes › General › Información. Esa pantalla es para certificados raíz y no interviene en la instalación de una app."
		),

		"guide.refresh.title":  (en: "How to refresh apps", es: "Cómo renovar las apps"),
		"guide.refresh.detail": (
			en: "Why sideloaded apps stop opening, and how to keep them alive",
			es: "Por qué las apps instaladas por fuera dejan de abrir, y cómo mantenerlas vivas"
		),
		"guide.refresh.p1": (
			en: "Every signature carries an expiry date. When it passes, the app stops launching. Nothing is broken — it simply has to be signed again.",
			es: "Toda firma lleva una fecha de caducidad. Cuando pasa, la app deja de abrirse. No está rota: simplemente hay que volver a firmarla."
		),
		"guide.refresh.h1": (en: "How long you get", es: "Cuánto tiempo tienes"),
		"guide.refresh.s1": (
			en: "Free Apple ID: 7 days. Up to 3 apps at once, and about 10 new app IDs per 7 days.",
			es: "Apple ID gratuito: 7 días. Hasta 3 apps a la vez, y unos 10 identificadores nuevos cada 7 días."
		),
		"guide.refresh.s2": (en: "Paid developer account: 1 year.", es: "Cuenta de desarrollador de pago: 1 año."),
		"guide.refresh.s3": (
			en: "Enterprise certificate: 1 year, but Apple can revoke it at any time.",
			es: "Certificado empresarial: 1 año, pero Apple puede revocarlo en cualquier momento."
		),
		"guide.refresh.h2": (en: "Refreshing", es: "Renovar"),
		"guide.refresh.s4": (
			en: "Open Vendor and check the days left on the Home screen.",
			es: "Abre Vendor y mira los días restantes en la pantalla de inicio."
		),
		"guide.refresh.s5": (
			en: "Sign the app again with a valid certificate before the counter reaches zero.",
			es: "Vuelve a firmar la app con un certificado válido antes de que el contador llegue a cero."
		),
		"guide.refresh.s6": (
			en: "Install over the existing app — your data stays.",
			es: "Instala encima de la app existente: tus datos se conservan."
		),
		"guide.refresh.note": (
			en: "Vendor turns the counter amber below 30 days so the deadline does not take you by surprise.",
			es: "Vendor pone el contador en ámbar por debajo de 30 días para que la fecha no te pille por sorpresa."
		),
		"guide.refresh.warn": (
			en: "If the app stopped working before its expiry date, the certificate was probably revoked rather than expired. Re-signing with the same certificate will not help; you need a different one.",
			es: "Si la app dejó de funcionar antes de su fecha de caducidad, lo más probable es que el certificado fuera revocado, no que caducara. Volver a firmar con el mismo certificado no servirá: necesitas otro."
		),

		"guide.faq.title":  (en: "Frequently asked questions", es: "Preguntas frecuentes"),
		"guide.faq.detail": (en: "Signing, revocations and privacy", es: "Firma, revocaciones y privacidad"),
		"guide.faq.h1": (
			en: "My app suddenly closes on launch",
			es: "Mi app se cierra de golpe al abrirla"
		),
		"guide.faq.p1": (
			en: "Two causes look identical from the outside: the signature expired, or the certificate was revoked. Check the days remaining in Vendor. If there is still time left, the certificate was revoked.",
			es: "Dos causas se ven idénticas desde fuera: la firma caducó, o el certificado fue revocado. Mira los días restantes en Vendor. Si todavía queda tiempo, el certificado fue revocado."
		),
		"guide.faq.h2": (en: "Why does Apple revoke certificates?", es: "¿Por qué Apple revoca certificados?"),
		"guide.faq.p2": (
			en: "Enterprise certificates are meant for a company's own staff. Using one to hand apps to the public skips App Review, so Apple cancels those accounts — often within days. Revocation waves in 2025 also caught developers who had done nothing wrong.",
			es: "Los certificados empresariales son para el personal de una empresa. Usar uno para repartir apps al público se salta la revisión de la App Store, así que Apple cancela esas cuentas, a menudo en cuestión de días. Las oleadas de revocación de 2025 también se llevaron por delante a desarrolladores que no habían hecho nada malo."
		),
		"guide.faq.h3": (en: "Do my certificates leave the phone?", es: "¿Mis certificados salen del teléfono?"),
		"guide.faq.p3": (
			en: "No. Signing runs on the device. Your .p12 and its password are stored in Vendor's own folder and are never uploaded. Vendor has no account system and collects no analytics.",
			es: "No. La firma se ejecuta en el dispositivo. Tu .p12 y su contraseña se guardan en la carpeta propia de Vendor y nunca se suben. Vendor no tiene sistema de cuentas ni recoge analíticas."
		),
		"guide.faq.h4": (en: "Can I get this from the App Store?", es: "¿Puedo conseguir esto en la App Store?"),
		"guide.faq.p4": (
			en: "No. Apple does not allow apps that install other apps, so tools like this are distributed as signed .ipa files instead.",
			es: "No. Apple no permite apps que instalen otras apps, así que herramientas como esta se distribuyen como archivos .ipa firmados."
		),
		"guide.faq.h5": (en: "Is a free Apple ID enough?", es: "¿Basta con un Apple ID gratuito?"),
		"guide.faq.p5": (
			en: "For personal use, yes — with 7-day signatures and a 3-app ceiling. Anything beyond that needs a paid developer account or an enterprise certificate.",
			es: "Para uso personal, sí: con firmas de 7 días y un tope de 3 apps. Cualquier cosa más allá requiere una cuenta de desarrollador de pago o un certificado empresarial."
		),
		"guide.faq.warn": (
			en: "Vendor is not affiliated with Apple Inc. Sideloading is at your own risk.",
			es: "Vendor no tiene relación con Apple Inc. Instalar apps por fuera es bajo tu propia responsabilidad."
		),
	]
}
