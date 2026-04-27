#!/usr/bin/env bash
set -euo pipefail
# API_BASE_URL was removed when authentication switched to SSH tunneling.
# The app connects to localhost via an SSH port-forward at runtime; no
# static base URL is needed at build time.  This script is retained as a
# no-op so any tooling that calls it does not break.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
OUTPUT_PATH="${OUTPUT_PATH:-$ROOT_DIR/Config/Env.generated.xcconfig}"

mkdir -p "$(dirname "$OUTPUT_PATH")"

cat > "$OUTPUT_PATH" <<'EOF_XCCONFIG'
// Generated file. No build-time variables required (SSH tunnel auth).
EOF_XCCONFIG

echo "✅ Generated xcconfig: $OUTPUT_PATH"
