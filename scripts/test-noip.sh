#!/bin/bash
# ==============================================================================
# Prueba manual de actualización dinámica de No-IP (Paso 1 - Persona 3)
# Uso:
#   NOIP_USERNAME="usuario" NOIP_PASSWORD="password" NOIP_HOSTNAME="host.ddns.net" \
#     ./scripts/test-noip.sh [IP_OPCIONAL]
# ==============================================================================
set -euo pipefail

: "${NOIP_USERNAME:?Define la variable NOIP_USERNAME antes de ejecutar el script}"
: "${NOIP_PASSWORD:?Define la variable NOIP_PASSWORD antes de ejecutar el script}"
: "${NOIP_HOSTNAME:?Define la variable NOIP_HOSTNAME antes de ejecutar el script}"

TARGET_IP="${1:-$(curl -fsS https://checkip.amazonaws.com | tr -d '[:space:]')}"

if [ -z "$TARGET_IP" ]; then
  echo "ERROR: No se pudo determinar la IP objetivo." >&2
  exit 1
fi

echo "Probando actualización en No-IP para ${NOIP_HOSTNAME} -> ${TARGET_IP}..."

RESPONSE=$(curl -fsS \
  -A "AguaFix-Manual-Test/1.0" \
  -u "${NOIP_USERNAME}:${NOIP_PASSWORD}" \
  "https://dynupdate.no-ip.com/nic/update?hostname=${NOIP_HOSTNAME}&myip=${TARGET_IP}")

echo "Respuesta de No-IP: ${RESPONSE}"

case "$RESPONSE" in
  good*|nochg*)
    echo "OK: Actualización dinámica verificada."
    ;;
  *)
    echo "ERROR: No-IP rechazó la actualización (${RESPONSE})." >&2
    exit 1
    ;;
esac
