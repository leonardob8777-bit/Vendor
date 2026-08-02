#!/bin/bash
#
# install-on-iphone.sh — compila Vendor y la instala en el iPhone conectado.
#
# Sirve para reinstalar cada 7 días sin pelearse con la interfaz de Xcode.
# La primera vez tienes que elegir el Team a mano en Xcode; a partir de ahí
# queda guardado en el proyecto y este script se encarga del resto.
#

set -uo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$RAIZ"

echo "==> Buscando el iPhone"
DESTINO=$(xcodebuild -project Vendor.xcodeproj -scheme Vendor -showdestinations 2>/dev/null \
	| grep "platform:iOS," | grep -v "Simulator" | grep -v "placeholder" | head -1)

if [ -z "$DESTINO" ]; then
	echo
	echo "No veo ningún iPhone conectado."
	echo "  · Conéctalo por cable y desbloquéalo"
	echo "  · Si sale el aviso, toca Confiar en este ordenador"
	echo "  · Comprueba que aparece en Xcode › Window › Devices and Simulators"
	exit 1
fi

ID=$(echo "$DESTINO" | sed -n 's/.*id:\([^,}]*\).*/\1/p' | tr -d ' ')
NOMBRE=$(echo "$DESTINO" | sed -n 's/.*name:\(.*\)}.*/\1/p' | sed 's/ *$//')
echo "    $NOMBRE ($ID)"

EQUIPO=$(grep -m1 "DEVELOPMENT_TEAM = " Vendor.xcodeproj/project.pbxproj | sed 's/.*= *"\{0,1\}\([^";]*\)"\{0,1\};.*/\1/')
if [ -z "$EQUIPO" ]; then
	cat <<'FIN'

El proyecto no tiene equipo de firma configurado todavía.

Ábrelo una vez en Xcode:
  Vendor.xcodeproj › target Vendor › Signing & Capabilities
  › Automatically manage signing ✓
  › Team: tu nombre (Personal Team)

Xcode lo guarda en el proyecto y este script ya funcionará solo.

FIN
	exit 1
fi
echo "==> Equipo: $EQUIPO"

echo "==> Compilando e instalando (puede tardar la primera vez)"
xcodebuild \
	-project Vendor.xcodeproj \
	-scheme Vendor \
	-configuration Debug \
	-destination "id=$ID" \
	-allowProvisioningUpdates \
	build 2>&1 | grep -viE "^$|note:|warning:.*was built for newer" | tail -25

ESTADO=${PIPESTATUS[0]}
echo
if [ "$ESTADO" = "0" ]; then
	echo "Compilado. Para lanzarla en el iPhone:"
	echo "  xcrun devicectl device install app --device $ID <ruta al .app>"
	echo
	echo "O simplemente pulsa Play en Xcode, que hace las dos cosas."
	echo
	echo "Si el iPhone dice que el desarrollador no es de confianza:"
	echo "  Ajustes › General › VPN y gestión de dispositivos › tu Apple ID › Confiar"
else
	echo "Falló. El error suele estar en las últimas líneas de arriba."
fi
exit "$ESTADO"
