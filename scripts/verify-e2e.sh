#!/bin/bash
# ==============================================================================
# Verificación End-to-End de AguaFix (Paso 5 - Persona 3)
# Valida:
#   1. Salud de la API por dominio No-IP o IP (GET /)
#   2. Registro de usuario con JWT (POST /api/auth/register)
#   3. Login con JWT (POST /api/auth/login)
#   4. Creación de reporte con imagen PNG en S3 (POST /api/reports)
#   5. Acceso público HTTP 200 a la imagen en S3
#   6. Persistencia del reporte en PostgreSQL (GET /api/reports)
#
# Uso:
#   ./scripts/verify-e2e.sh http://aguafix-equipo.ddns.net
# ==============================================================================
set -euo pipefail

if [ $# -lt 1 ]; then
  echo "Uso: $0 <hostname-noip-o-url>" >&2
  echo "Ejemplo: $0 http://aguafix-equipo.ddns.net" >&2
  exit 1
fi

RAW_TARGET="$1"
case "$RAW_TARGET" in
  http://*|https://*) BASE_URL="${RAW_TARGET%/}" ;;
  *) BASE_URL="http://${RAW_TARGET%/}" ;;
esac

TMP_PNG=$(mktemp "${TMPDIR:-/tmp}/aguafix-e2e-XXXXXX.png")
trap 'rm -f "$TMP_PNG"' EXIT

# PNG válido de 1x1 píxel para probar subida multipart a S3
printf '%s' 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+X2dIAAAAASUVORK5CYII=' \
  | base64 -d > "$TMP_PNG"

RUN_ID=$(date +%s)
TEST_EMAIL="e2e.${RUN_ID}@aguafix.test"
TEST_PASS="AguaFixE2E!${RUN_ID}"

echo "=== Verificación End-to-End contra ${BASE_URL} ==="

echo "[1/6] Probando salud de la API (GET /)..."
HEALTH_BODY=$(curl -fsS "${BASE_URL}/")
echo "  Respuesta: ${HEALTH_BODY}"
echo "$HEALTH_BODY" | grep -q '"status":"ok"' || {
  echo "ERROR: La respuesta de salud no contiene status=ok." >&2
  exit 1
}

echo "[2/6] Probando registro de usuario (POST /api/auth/register)..."
REGISTER_BODY=$(curl -fsS -X POST "${BASE_URL}/api/auth/register" \
  -H "Content-Type: application/json" \
  -d "{\"name\":\"Prueba E2E\",\"email\":\"${TEST_EMAIL}\",\"password\":\"${TEST_PASS}\"}")
echo "$REGISTER_BODY" | grep -q '"token":"' || {
  echo "ERROR: Registro no devolvió un token JWT: ${REGISTER_BODY}" >&2
  exit 1
}
echo "  OK: Usuario ${TEST_EMAIL} registrado con JWT."

echo "[3/6] Probando login (POST /api/auth/login)..."
LOGIN_BODY=$(curl -fsS -X POST "${BASE_URL}/api/auth/login" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"${TEST_EMAIL}\",\"password\":\"${TEST_PASS}\"}")
JWT_TOKEN=$(printf '%s' "$LOGIN_BODY" | sed -n 's/.*"token":"\([^"]*\)".*/\1/p')
if [ -z "$JWT_TOKEN" ]; then
  echo "ERROR: Login no devolvió un token JWT: ${LOGIN_BODY}" >&2
  exit 1
fi
echo "  OK: Login exitoso (JWT recibido)."

echo "[4/6] Creando reporte con imagen hacia S3 (POST /api/reports)..."
REPORT_BODY=$(curl -fsS -X POST "${BASE_URL}/api/reports" \
  -H "Authorization: Bearer ${JWT_TOKEN}" \
  -F "address=Av. Prueba E2E #${RUN_ID}" \
  -F "description=Reporte de verificación automática End-to-End" \
  -F "severity=medium" \
  -F "reporterPhone=4771234567" \
  -F "photo=@${TMP_PNG};type=image/png")

PHOTO_URL=$(printf '%s' "$REPORT_BODY" | sed -n 's/.*"photoUrl":"\([^"]*\)".*/\1/p')
if [ -z "$PHOTO_URL" ]; then
  echo "ERROR: No se encontró photoUrl en la respuesta: ${REPORT_BODY}" >&2
  exit 1
fi
echo "  OK: Reporte creado. photoUrl=${PHOTO_URL}"

echo "[5/6] Verificando acceso público a la imagen en S3..."
S3_STATUS=$(curl -sS -o /dev/null -w "%{http_code}" "$PHOTO_URL")
if [ "$S3_STATUS" != "200" ]; then
  echo "ERROR: La imagen en S3 devolvió HTTP ${S3_STATUS} (se esperaba 200)." >&2
  exit 1
fi
echo "  OK: Imagen accesible públicamente en S3 (HTTP 200)."

echo "[6/6] Verificando persistencia en PostgreSQL (GET /api/reports)..."
REPORTS_LIST=$(curl -fsS "${BASE_URL}/api/reports")
echo "$REPORTS_LIST" | grep -q "$PHOTO_URL" || {
  echo "ERROR: El reporte recién creado no aparece en GET /api/reports." >&2
  exit 1
}
echo "  OK: Reporte listado correctamente desde PostgreSQL."

echo ""
echo "=== Pruebas automáticas completadas con éxito ==="
echo "Recordatorios manuales pendientes del Paso 5:"
echo "  - Confirmar recepción del correo en MAINTENANCE_EMAIL."
echo "  - Validar CI/CD con un push a main en el repo de la API."
echo "  - Ejecutar 'terraform destroy' al terminar las pruebas/video."
