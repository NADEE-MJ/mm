#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MOBILE_DIR="$ROOT_DIR/mobile"
BACKEND_DIR="$ROOT_DIR/backend"

log() {
  echo "[server-pilot-cli] $*"
}

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    log "Missing required command: $cmd"
    exit 1
  fi
}

run_in_dir() {
  local dir="$1"
  shift
  (cd "$dir" && "$@")
}

find_simulator_udid() {
  local device_name="$1"

  xcrun simctl list devices iOS | awk -v name="$device_name" '
    {
      line = $0
      sub(/^[[:space:]]+/, "", line)
      if (index(line, name " (") == 1 && line !~ /unavailable/) {
        split(line, parts, "(")
        split(parts[2], idparts, ")")
        print idparts[1]
        exit
      }
    }
  '
}

swift_xcconfig() {
  log "Generating Env.generated.xcconfig from .env"
  run_in_dir "$MOBILE_DIR" bash scripts/generate-env-xcconfig.sh
}

swift_xcodegen() {
  require_cmd xcodegen
  log "Generating Xcode project from project.yml"
  run_in_dir "$MOBILE_DIR" xcodegen generate
  log "Xcode project generated"
}

swift_build() {
  require_cmd xcodebuild
  local scheme="ServerPilot"
  local configuration="Debug"
  local destination="platform=iOS Simulator,name=iPhone 17 Pro"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --scheme)
        scheme="$2"
        shift 2
        ;;
      --configuration)
        configuration="$2"
        shift 2
        ;;
      --destination)
        destination="$2"
        shift 2
        ;;
      *)
        log "Unknown swift:build option: $1"
        exit 1
        ;;
    esac
  done

  log "Building Swift app (scheme=$scheme, config=$configuration)"
  run_in_dir "$MOBILE_DIR" xcodebuild \
    -project ServerPilot.xcodeproj \
    -scheme "$scheme" \
    -configuration "$configuration" \
    -destination "$destination" \
    build
}

swift_run() {
  require_cmd xcodebuild
  local scheme="ServerPilot"
  local configuration="Debug"
  local device_name="iPhone 17 Pro"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --scheme)
        scheme="$2"
        shift 2
        ;;
      --configuration)
        configuration="$2"
        shift 2
        ;;
      --device)
        device_name="$2"
        shift 2
        ;;
      *)
        log "Unknown swift:run option: $1"
        exit 1
        ;;
    esac
  done

  log "Building Swift app (scheme=$scheme, config=$configuration)"
  local build_dir="$MOBILE_DIR/build"
  run_in_dir "$MOBILE_DIR" xcodebuild \
    -project ServerPilot.xcodeproj \
    -scheme "$scheme" \
    -configuration "$configuration" \
    -destination "platform=iOS Simulator,name=$device_name" \
    -derivedDataPath "$build_dir" \
    build

  local app_path
  app_path=$(find "$build_dir" -name "*.app" -type d | head -n 1)

  if [[ -z "$app_path" ]]; then
    log "Failed to find built app bundle"
    exit 1
  fi

  log "Installing and launching app in simulator: $device_name"
  local device_id
  device_id="$(find_simulator_udid "$device_name")"

  if [[ -n "$device_id" ]]; then
    xcrun simctl boot "$device_id" 2>/dev/null || true
    open -a Simulator --args -CurrentDeviceUDID "$device_id"
    xcrun simctl install "$device_id" "$app_path"
    xcrun simctl launch "$device_id" "com.nadeem.serverpilot"
    log "App launched in simulator"
  else
    log "Could not find simulator: $device_name"
    log "Run 'simulator:list' to see available simulators"
    exit 1
  fi
}

simulator_list() {
  require_cmd xcrun
  log "Available iOS simulators:"
  xcrun simctl list devices iOS
}

simulator_boot() {
  require_cmd xcrun
  local device_name="${1:-iPhone 17 Pro}"

  log "Booting simulator: $device_name"
  local device_id
  device_id="$(find_simulator_udid "$device_name")"

  if [[ -z "$device_id" ]]; then
    log "Simulator not found: $device_name"
    log "Available simulators:"
    xcrun simctl list devices iOS
    exit 1
  fi

  if ! xcrun simctl boot "$device_id" 2>/dev/null; then
    if ! xcrun simctl list devices iOS | grep -q "$device_id.*(Booted)"; then
      log "Failed to boot simulator: $device_name ($device_id)"
      exit 1
    fi
    log "Simulator already booted"
  fi

  open -a Simulator --args -CurrentDeviceUDID "$device_id"
  log "Simulator booted: $device_name ($device_id)"
}

backend_dev() {
  require_cmd bun
  log "Starting backend in dev mode"
  run_in_dir "$BACKEND_DIR" bun run dev
}

backend_start() {
  require_cmd bun
  log "Starting backend"
  run_in_dir "$BACKEND_DIR" bun run start
}

backend_migrate() {
  require_cmd bun
  log "Running database migrations"
  run_in_dir "$BACKEND_DIR" bun run db:migrate
}

usage() {
  cat <<USAGE
Usage: $(basename "$0") <command>

Mobile commands:
  swift:xcconfig     Generate Config/Env.generated.xcconfig from mobile/.env
  swift:xcodegen     Generate Xcode project from project.yml
  swift:build        Build the Swift iOS app (opts: --scheme, --configuration, --destination)
  swift:run          Build and run the app in simulator (opts: --scheme, --configuration, --device)

Simulator commands:
  simulator:list     List available iOS simulators
  simulator:boot     Boot an iOS simulator (default: iPhone 17 Pro, or pass device name)

Backend commands:
  backend:dev        Start backend in watch/dev mode (bun run dev)
  backend:start      Start backend in production mode (bun run start)
  backend:migrate    Run database migrations

  help               Show this message
USAGE
}

COMMAND="${1:-help}"
shift || true

case "$COMMAND" in
  swift:xcconfig)
    swift_xcconfig
    ;;
  swift:xcodegen)
    swift_xcodegen
    ;;
  swift:build)
    swift_build "$@"
    ;;
  swift:run|swift:dev)
    swift_run "$@"
    ;;
  simulator:list)
    simulator_list
    ;;
  simulator:boot)
    simulator_boot "$@"
    ;;
  backend:dev)
    backend_dev
    ;;
  backend:start)
    backend_start
    ;;
  backend:migrate)
    backend_migrate
    ;;
  help|-h|--help)
    usage
    ;;
  *)
    log "Unknown command: $COMMAND"
    usage
    exit 1
    ;;
esac
