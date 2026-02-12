#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FRONTEND_DIR="$ROOT_DIR/frontend"
BACKEND_DIR="$ROOT_DIR/backend"
MOBILE_SWIFT_DIR="$ROOT_DIR/mobile-swift"

log() {
  echo "[mm-cli] $*"
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

install_frontend() {
  require_cmd npm
  log "Installing frontend dependencies"
  run_in_dir "$FRONTEND_DIR" npm install
}

install_backend() {
  require_cmd uv
  log "Installing backend dependencies"
  run_in_dir "$BACKEND_DIR" uv sync
}

install_sync() {
  require_cmd npm
  require_cmd uv
  log "Syncing frontend dependencies (npm ci)"
  run_in_dir "$FRONTEND_DIR" npm ci
  log "Syncing backend dependencies (uv sync)"
  run_in_dir "$BACKEND_DIR" uv sync
  log "All dependencies synced"
}

build_frontend() {
  require_cmd npm
  log "Building frontend"
  run_in_dir "$FRONTEND_DIR" npm run build
}

frontend_dev() {
  require_cmd npm
  local host="0.0.0.0"
  local port="5173"
  local extra_args=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --host)
        if [[ $# -lt 2 ]]; then
          log "Missing value for --host"
          exit 1
        fi
        host="$2"
        shift 2
        ;;
      --host=*)
        host="${1#--host=}"
        shift
        ;;
      --port)
        if [[ $# -lt 2 ]]; then
          log "Missing value for --port"
          exit 1
        fi
        port="$2"
        shift 2
        ;;
      --port=*)
        port="${1#--port=}"
        shift
        ;;
      --)
        shift
        extra_args=("$@")
        break
        ;;
      *)
        log "Unknown frontend:dev option: $1"
        exit 1
        ;;
    esac
  done

  log "Starting frontend dev server (host=$host port=$port)"
  local cmd=(npm run dev -- --host "$host" --port "$port")
  if [[ ${#extra_args[@]} -gt 0 ]]; then
    cmd+=("${extra_args[@]}")
  fi

  run_in_dir "$FRONTEND_DIR" "${cmd[@]}"
}

backend_migrate() {
  require_cmd uv
  log "Applying latest database migrations"
  run_in_dir "$BACKEND_DIR" uv run alembic upgrade head
}

backend_start() {
  require_cmd uv
  local host="0.0.0.0"
  local port="8155"
  local reload="true"
  local extra_args=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --host)
        if [[ $# -lt 2 ]]; then
          log "Missing value for --host"
          exit 1
        fi
        host="$2"
        shift 2
        ;;
      --host=*)
        host="${1#--host=}"
        shift
        ;;
      --port)
        if [[ $# -lt 2 ]]; then
          log "Missing value for --port"
          exit 1
        fi
        port="$2"
        shift 2
        ;;
      --port=*)
        port="${1#--port=}"
        shift
        ;;
      --reload)
        reload="true"
        shift
        ;;
      --no-reload)
        reload="false"
        shift
        ;;
      --)
        shift
        extra_args=("$@")
        break
        ;;
      *)
        log "Unknown backend:start option: $1"
        exit 1
        ;;
    esac
  done

  log "Starting backend FastAPI server (host=$host port=$port reload=$reload)"
  local cmd=(uv run uvicorn main:app --host "$host" --port "$port")
  if [[ "$reload" == "true" ]]; then
    cmd+=(--reload)
  fi
  if [[ ${#extra_args[@]} -gt 0 ]]; then
    cmd+=("${extra_args[@]}")
  fi

  run_in_dir "$BACKEND_DIR" "${cmd[@]}"
}

stack_install() {
  install_frontend
  install_backend
  log "All dependencies installed"
}

swift_xcodegen() {
  require_cmd xcodegen
  log "Generating Xcode project from project.yml"
  run_in_dir "$MOBILE_SWIFT_DIR" xcodegen generate
  log "Xcode project generated"
}

swift_build() {
  require_cmd xcodebuild
  local scheme="MobileSwift"
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
  run_in_dir "$MOBILE_SWIFT_DIR" xcodebuild -project MobileSwift.xcodeproj -scheme "$scheme" -configuration "$configuration" -destination "$destination" build
}

swift_run() {
  require_cmd xcodebuild
  local scheme="MobileSwift"
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
        log "Unknown swift:run option: $1"
        exit 1
        ;;
    esac
  done

  log "Building and running Swift app in simulator (scheme=$scheme, config=$configuration)"

  # Build and get the app path
  local build_dir="$MOBILE_SWIFT_DIR/build"
  run_in_dir "$MOBILE_SWIFT_DIR" xcodebuild -project MobileSwift.xcodeproj -scheme "$scheme" -configuration "$configuration" -destination "$destination" -derivedDataPath "$build_dir" build

  # Find the app bundle
  local app_path=$(find "$build_dir" -name "*.app" -type d | head -n 1)

  if [[ -z "$app_path" ]]; then
    log "Failed to find built app bundle"
    exit 1
  fi

  log "Installing and launching app"
  # Boot the simulator if needed
  local device_id=$(xcrun simctl list devices | grep "iPhone 17 Pro" | grep -v "unavailable" | head -n 1 | sed 's/.*(\([^)]*\)).*/\1/')
  if [[ -n "$device_id" ]]; then
    xcrun simctl boot "$device_id" 2>/dev/null || true
    xcrun simctl install "$device_id" "$app_path"
    xcrun simctl launch "$device_id" "com.moviemanager.mobileswift"
    log "App launched in simulator"
  else
    log "Could not find iPhone 17 Pro simulator"
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
  local device_id=$(xcrun simctl list devices | grep "$device_name" | grep -v "unavailable" | head -n 1 | sed 's/.*(\([^)]*\)).*/\1/')

  if [[ -z "$device_id" ]]; then
    log "Simulator not found: $device_name"
    log "Available simulators:"
    xcrun simctl list devices iOS
    exit 1
  fi

  xcrun simctl boot "$device_id" 2>/dev/null || log "Simulator already booted"
  open -a Simulator
  log "Simulator booted: $device_name ($device_id)"
}

stack_start() {
  build_frontend
  backend_start "$@"
}

usage() {
  cat <<USAGE
Usage: $(basename "$0") <command>

Commands:
  install:all        Install frontend and backend dependencies
  install:frontend   Install only frontend dependencies
  install:backend    Install only backend dependencies
  install:sync       Sync frontend (npm ci) and backend (uv sync) dependencies from lock files
  build:frontend     Build the frontend bundle
  frontend:dev       Start the frontend dev server (opts: --host, --port, use -- to pass extra Vite args)
  backend:migrate    Apply the latest Alembic migrations
  backend:start      Start the FastAPI backend (opts: --host, --port, --no-reload, use -- for uvicorn args)
  swift:xcodegen     Generate Xcode project from project.yml
  swift:build        Build the Swift iOS app (opts: --scheme, --configuration, --destination)
  swift:run          Build and run the Swift iOS app in simulator (opts: --scheme, --configuration, --destination)
  simulator:list     List available iOS simulators
  simulator:boot     Boot an iOS simulator (default: iPhone 17 Pro, or pass device name)
  start              Build frontend, then start backend (accepts backend:start opts)
  help               Show this message
USAGE
}

COMMAND="${1:-help}"
shift || true

case "$COMMAND" in
  install:all)
    stack_install
    ;;
  install:frontend)
    install_frontend
    ;;
  install:backend)
    install_backend
    ;;
  install:sync)
    install_sync
    ;;
  build:frontend)
    build_frontend
    ;;
  frontend:dev)
    frontend_dev "$@"
    ;;
  backend:migrate)
    backend_migrate
    ;;
  backend:start)
    backend_start "$@"
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
  start|stack:start)
    stack_start "$@"
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
