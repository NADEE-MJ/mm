#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="${ENV_FILE:-$ROOT_DIR/.env}"
OUTPUT_PATH="${OUTPUT_PATH:-$ROOT_DIR/Config/Env.generated.xcconfig}"

trim() {
  echo "$1" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//'
}

read_dotenv_value() {
  local key="$1"
  local line

  if [ ! -f "$ENV_FILE" ]; then
    return 1
  fi

  line=$(grep -E "^[[:space:]]*${key}[[:space:]]*=" "$ENV_FILE" | tail -n 1 || true)
  if [ -z "$line" ]; then
    return 1
  fi

  local value="${line#*=}"
  value="$(trim "$value")"

  if [[ "$value" =~ ^\".*\"$ || "$value" =~ ^\'.*\'$ ]]; then
    value="${value:1:${#value}-2}"
  fi

  printf '%s' "$value"
}

normalize_boolean_for_xcconfig() {
  local raw="$1"
  local value

  value="$(trim "$raw")"
  value="$(echo "$value" | tr '[:upper:]' '[:lower:]')"

  case "$value" in
    yes)
      printf '%s' "YES"
      ;;
    no)
      printf '%s' "NO"
      ;;
    "")
      printf '%s' "NO"
      ;;
    *)
      echo "❌ ERROR: FILE_LOGGING_ENABLED must be YES or NO." >&2
      echo "Received: $raw" >&2
      exit 1
      ;;
  esac
}

API_BASE_URL_VALUE="${API_BASE_URL:-}"
API_BASE_URL_VALUE="$(trim "$API_BASE_URL_VALUE")"

if [ -z "$API_BASE_URL_VALUE" ]; then
  API_BASE_URL_VALUE="$(read_dotenv_value API_BASE_URL || true)"
fi

if [ -z "$API_BASE_URL_VALUE" ]; then
  API_BASE_URL_VALUE="$(read_dotenv_value MOBILE_API_BASE_URL || true)"
fi

API_BASE_URL_VALUE="$(trim "$API_BASE_URL_VALUE")"

if [ -z "$API_BASE_URL_VALUE" ]; then
  echo "❌ ERROR: API_BASE_URL is missing."
  echo "Set API_BASE_URL in environment, or add API_BASE_URL (or MOBILE_API_BASE_URL) to $ENV_FILE."
  exit 1
fi

if [[ ! "$API_BASE_URL_VALUE" =~ ^https?:// ]]; then
  echo "❌ ERROR: API_BASE_URL must start with http:// or https://"
  echo "Received: $API_BASE_URL_VALUE"
  exit 1
fi

# Allow localhost for local development; CI validates separately via the workflow
IS_LOCALHOST=false
if [[ "$API_BASE_URL_VALUE" =~ localhost|127\.0\.0\.1|::1 ]]; then
  IS_LOCALHOST=true
fi

if [[ "$API_BASE_URL_VALUE" =~ /api/?$ ]]; then
  API_BASE_URL_VALUE="${API_BASE_URL_VALUE%/}"
elif [[ "$API_BASE_URL_VALUE" =~ ^https?://[^/]+(:[0-9]+)?/?$ ]]; then
  API_BASE_URL_VALUE="${API_BASE_URL_VALUE%/}/api"
else
  echo "❌ ERROR: API_BASE_URL must be a base host URL (http(s)://host[:port]) or end with /api."
  echo "Received: $API_BASE_URL_VALUE"
  exit 1
fi

if [[ "$API_BASE_URL_VALUE" == *'$('* || "$API_BASE_URL_VALUE" == *'${'* ]]; then
  echo "❌ ERROR: API_BASE_URL contains unresolved variable syntax."
  echo "Received: $API_BASE_URL_VALUE"
  exit 1
fi

API_BASE_URL_XCCONFIG_VALUE="$(printf '%s' "$API_BASE_URL_VALUE" | sed 's,/,$(FORWARD_SLASH),g')"

FILE_LOGGING_ENABLED_VALUE="${FILE_LOGGING_ENABLED:-}"
FILE_LOGGING_ENABLED_VALUE="$(trim "$FILE_LOGGING_ENABLED_VALUE")"

if [ -z "$FILE_LOGGING_ENABLED_VALUE" ]; then
  FILE_LOGGING_ENABLED_VALUE="$(read_dotenv_value FILE_LOGGING_ENABLED || true)"
fi

if [ -z "$FILE_LOGGING_ENABLED_VALUE" ]; then
  FILE_LOGGING_ENABLED_VALUE="$(read_dotenv_value MOBILE_FILE_LOGGING_ENABLED || true)"
fi

FILE_LOGGING_ENABLED_VALUE="$(normalize_boolean_for_xcconfig "$FILE_LOGGING_ENABLED_VALUE")"

mkdir -p "$(dirname "$OUTPUT_PATH")"

cat > "$OUTPUT_PATH" <<EOF_XCCONFIG
// Generated file. Do not commit secrets.
API_BASE_URL = $API_BASE_URL_XCCONFIG_VALUE
FILE_LOGGING_ENABLED = $FILE_LOGGING_ENABLED_VALUE
EOF_XCCONFIG

echo "✅ Generated xcconfig: $OUTPUT_PATH"
echo "✅ API_BASE_URL: $API_BASE_URL_VALUE"
echo "✅ FILE_LOGGING_ENABLED: $FILE_LOGGING_ENABLED_VALUE"
