#!/bin/bash
#
# export-certificate.sh — saca tu certificado de desarrollador del llavero
# y lo deja como .p12 + .mobileprovision, listos para importar dentro de Vendor.
#
# Requisito previo: haber añadido tu Apple ID en Xcode y haber compilado Vendor
# en el iPhone al menos una vez. Eso es lo que crea el certificado.
#
# Uso:  ./Tools/export-certificate.sh [carpeta-destino]
#

set -euo pipefail

DESTINO="${1:-$HOME/Desktop/VendorCert}"
PERFILES="$HOME/Library/Developer/Xcode/UserData/Provisioning Profiles"

echo "==> Buscando identidades de firma"
IDENTIDADES=$(security find-identity -v -p codesigning 2>/dev/null | grep "Apple Development" || true)

if [ -z "$IDENTIDADES" ]; then
	cat <<'FIN'

Todavía no hay certificado de desarrollador en este Mac.

Añadir el Apple ID en Xcode NO crea el certificado por sí solo: se crea la
primera vez que compilas en un iPhone de verdad, porque una cuenta gratuita
necesita un dispositivo registrado para emitir el perfil.

Haz esto (una sola vez):
  1. Conecta el iPhone por cable y desbloquéalo. Acepta "Confiar" si lo pide.
  2. Xcode › Settings › Accounts — comprueba que tu Apple ID aparece y que NO
     dice "sign in required". Si lo dice, vuelve a iniciar sesión.
  3. Abre Vendor.xcodeproj › target Vendor › Signing & Capabilities
  4. "Automatically manage signing" marcado, y en Team elige tu nombre
     seguido de "(Personal Team)".
  5. Arriba, selecciona tu iPhone como destino y pulsa Play.

La primera vez el iPhone dirá que el desarrollador no es de confianza:
  Ajustes › General › VPN y gestión de dispositivos › toca tu Apple ID › Confiar

Luego vuelve a ejecutar este script para sacar el .p12.

FIN
	exit 1
fi

echo "$IDENTIDADES"
echo

HUELLA=$(echo "$IDENTIDADES" | head -1 | awk '{print $2}')
NOMBRE=$(echo "$IDENTIDADES" | head -1 | sed 's/.*"\(.*\)".*/\1/')

mkdir -p "$DESTINO"

echo "==> Exportando la clave privada como .p12"
echo "    Se te pedirá una contraseña. Apúntala: la necesitas al importar en Vendor."
echo "    (También te pedirá la contraseña de tu Mac para abrir el llavero.)"
echo

security export \
	-t identities \
	-f pkcs12 \
	-o "$DESTINO/certificado.p12" \
	-k "$HOME/Library/Keychains/login.keychain-db" \
	2>/dev/null || {
		echo "La exportación automática falló. Hazlo a mano:"
		echo "  Acceso a Llaveros › Certificados › clic derecho en \"$NOMBRE\" › Exportar"
		exit 1
	}

echo "==> Buscando el perfil de aprovisionamiento del iPhone"
if [ -d "$PERFILES" ]; then
	ENCONTRADO=0
	for perfil in "$PERFILES"/*.mobileprovision; do
		[ -e "$perfil" ] || continue
		# El perfil es un plist firmado; security lo descifra para poder leerlo.
		TEXTO=$(security cms -D -i "$perfil" 2>/dev/null || true)
		if echo "$TEXTO" | grep -q "com.leonardob8777bit.vendor"; then
			cp "$perfil" "$DESTINO/perfil.mobileprovision"
			ENCONTRADO=1
			echo "    Copiado: $(basename "$perfil")"
			break
		fi
	done
	if [ "$ENCONTRADO" = "0" ]; then
		# Sin coincidencia exacta, el más reciente suele ser el bueno.
		RECIENTE=$(ls -t "$PERFILES"/*.mobileprovision 2>/dev/null | head -1 || true)
		if [ -n "$RECIENTE" ]; then
			cp "$RECIENTE" "$DESTINO/perfil.mobileprovision"
			echo "    Sin coincidencia exacta; copiado el más reciente: $(basename "$RECIENTE")"
		else
			echo "    No hay perfiles. Compila Vendor en el iPhone desde Xcode y reintenta."
		fi
	fi
else
	echo "    Carpeta de perfiles inexistente. Compila una vez en el iPhone primero."
fi

echo
echo "==> Listo. Archivos en: $DESTINO"
ls -la "$DESTINO"
echo
echo "Pásalos al iPhone (AirDrop es lo más rápido) e impórtalos en Vendor:"
echo "  Certificates › + › elige certificado.p12 y perfil.mobileprovision"
echo "  Escribe la contraseña que pusiste arriba."
echo
echo "Recuerda: con Apple ID gratuito el certificado dura 7 días."
