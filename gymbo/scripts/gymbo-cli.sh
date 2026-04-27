#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FRONTEND_DIR="$ROOT_DIR/frontend"
BACKEND_DIR="$ROOT_DIR/backend"
MOBILE_DIR="$ROOT_DIR/mobile"

log() {
  echo "[gymbo-cli] $*"
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

install_frontend() {
  require_cmd npm
  log "Installing frontend dependencies"
  if ! run_in_dir "$FRONTEND_DIR" npm install; then
    log "npm install failed; retrying with --legacy-peer-deps"
    run_in_dir "$FRONTEND_DIR" npm install --legacy-peer-deps
  fi
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
  if ! run_in_dir "$FRONTEND_DIR" npm ci; then
    log "npm ci failed; retrying with npm install --legacy-peer-deps"
    run_in_dir "$FRONTEND_DIR" npm install --legacy-peer-deps
  fi
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

backend_migrate_status() {
  require_cmd uv
  log "Current Alembic revision"
  run_in_dir "$BACKEND_DIR" uv run alembic current
}

backend_migrate_down() {
  require_cmd uv
  local target="${1:--1}"
  log "Downgrading database migration to: $target"
  run_in_dir "$BACKEND_DIR" uv run alembic downgrade "$target"
}

backend_start() {
  require_cmd uv
  local host="0.0.0.0"
  local port="8002"
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

mobile_env() {
  require_cmd bash
  log "Generating mobile Env.generated.xcconfig from mobile/.env"
  run_in_dir "$MOBILE_DIR" ./scripts/generate-env-xcconfig.sh
}

mobile_release() {
  require_cmd bash
  require_cmd xcodegen
  require_cmd xcodebuild
  require_cmd zip
  require_cmd git

  local scheme="Gymbo"
  local publish="true"
  local deployment_target=""
  local suffix=""
  local api_base_url=""
  local file_logging_enabled=""
  local output_dir="$ROOT_DIR"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --scheme)
        if [[ $# -lt 2 ]]; then
          log "Missing value for --scheme"
          exit 1
        fi
        scheme="$2"
        shift 2
        ;;
      --deployment-target)
        if [[ $# -lt 2 ]]; then
          log "Missing value for --deployment-target"
          exit 1
        fi
        deployment_target="$2"
        shift 2
        ;;
      --suffix)
        if [[ $# -lt 2 ]]; then
          log "Missing value for --suffix"
          exit 1
        fi
        suffix="$2"
        shift 2
        ;;
      --api-base-url)
        if [[ $# -lt 2 ]]; then
          log "Missing value for --api-base-url"
          exit 1
        fi
        api_base_url="$2"
        shift 2
        ;;
      --file-logging)
        if [[ $# -lt 2 ]]; then
          log "Missing value for --file-logging"
          exit 1
        fi
        file_logging_enabled="$2"
        shift 2
        ;;
      --output-dir)
        if [[ $# -lt 2 ]]; then
          log "Missing value for --output-dir"
          exit 1
        fi
        output_dir="$2"
        shift 2
        ;;
      --publish)
        publish="true"
        shift
        ;;
      --no-publish)
        publish="false"
        shift
        ;;
      *)
        log "Unknown mobile:release option: $1"
        exit 1
        ;;
    esac
  done

  if [[ -n "$api_base_url" ]]; then
    export API_BASE_URL="$api_base_url"
  fi
  if [[ -n "$file_logging_enabled" ]]; then
    export FILE_LOGGING_ENABLED="$file_logging_enabled"
  fi

  log "Generating mobile release env config"
  run_in_dir "$MOBILE_DIR" ./scripts/generate-env-xcconfig.sh

  log "Generating Xcode project"
  run_in_dir "$MOBILE_DIR" xcodegen generate

  log "Resolving Swift Package dependencies"
  run_in_dir "$MOBILE_DIR" xcodebuild -project Gymbo.xcodeproj -scheme "$scheme" -resolvePackageDependencies

  local build_dir="$MOBILE_DIR/build/release"
  local xcodebuild_args=(
    -project Gymbo.xcodeproj
    -scheme "$scheme"
    -configuration Release
    -destination "generic/platform=iOS"
    -derivedDataPath "$build_dir"
    CODE_SIGNING_ALLOWED=NO
    CODE_SIGNING_REQUIRED=NO
    CODE_SIGN_IDENTITY=""
    CODE_SIGN_ENTITLEMENTS=""
    PROVISIONING_PROFILE_SPECIFIER=""
    DEVELOPMENT_TEAM=""
    AD_HOC_CODE_SIGNING_ALLOWED=YES
    COMPILER_INDEX_STORE_ENABLE=NO
    build
  )

  if [[ -n "$deployment_target" ]]; then
    local sanitized_deployment_target
    sanitized_deployment_target="$(echo "$deployment_target" | tr -cd '0-9.')"
    if [[ -z "$sanitized_deployment_target" ]]; then
      log "Invalid --deployment-target value: $deployment_target"
      exit 1
    fi
    xcodebuild_args=(
      -project Gymbo.xcodeproj
      -scheme "$scheme"
      -configuration Release
      -destination "generic/platform=iOS"
      -derivedDataPath "$build_dir"
      IPHONEOS_DEPLOYMENT_TARGET="$sanitized_deployment_target"
      CODE_SIGNING_ALLOWED=NO
      CODE_SIGNING_REQUIRED=NO
      CODE_SIGN_IDENTITY=""
      CODE_SIGN_ENTITLEMENTS=""
      PROVISIONING_PROFILE_SPECIFIER=""
      DEVELOPMENT_TEAM=""
      AD_HOC_CODE_SIGNING_ALLOWED=YES
      COMPILER_INDEX_STORE_ENABLE=NO
      build
    )
  fi

  log "Building unsigned Release app"
  run_in_dir "$MOBILE_DIR" xcodebuild "${xcodebuild_args[@]}"

  local app_path
  app_path="$(find "$build_dir/Build/Products/Release-iphoneos" -name "*.app" -type d 2>/dev/null | head -1)"
  if [[ -z "$app_path" ]]; then
    log "No .app bundle produced in $build_dir"
    exit 1
  fi

  local version
  version="$(grep 'MARKETING_VERSION:' "$MOBILE_DIR/project.yml" | head -1 | sed 's/.*MARKETING_VERSION:[[:space:]]*//' | tr -d '[:space:]')"
  if [[ -z "$version" ]]; then
    log "Could not read MARKETING_VERSION from mobile/project.yml"
    exit 1
  fi

  local version_tag
  version_tag="v$(echo "$version" | tr '.' '_')"

  local safe_suffix
  safe_suffix="$(echo "$suffix" | tr -cd '[:alnum:]._-')"

  local ipa_name
  if [[ -n "$safe_suffix" ]]; then
    ipa_name="gymbo-${version_tag}-${safe_suffix}.ipa"
  else
    ipa_name="gymbo-${version_tag}.ipa"
  fi

  mkdir -p "$output_dir"
  local output_dir_abs
  output_dir_abs="$(cd "$output_dir" && pwd)"
  local ipa_path="$output_dir_abs/$ipa_name"

  local payload_dir="$build_dir/Payload"
  rm -rf "$payload_dir"
  mkdir -p "$payload_dir"
  cp -R "$app_path" "$payload_dir/"
  rm -f "$build_dir/$ipa_name"
  run_in_dir "$build_dir" zip -r -9 "$ipa_name" Payload
  mv "$build_dir/$ipa_name" "$ipa_path"

  log "Created IPA: $ipa_path"

  if [[ "$publish" != "true" ]]; then
    log "Skipping GitHub release publish (--no-publish)"
    return
  fi

  require_cmd gh
  if ! gh auth status >/dev/null 2>&1; then
    log "GitHub CLI is not authenticated. Run: gh auth login"
    exit 1
  fi

  local tag="mobile-v${version}"
  local release_title="iOS v${version}"
  local full_sha
  full_sha="$(git -C "$ROOT_DIR" rev-parse HEAD)"
  local short_sha="${full_sha:0:7}"
  local build_time
  build_time="$(TZ=America/Los_Angeles date '+%Y-%m-%d %I:%M %p %Z')"
  local notes
  notes=$(printf 'Unsigned iOS build for v%s.\n\n**Built:** %s\n**Commit:** `%s`' "$version" "$build_time" "$short_sha")

  if gh release view "$tag" >/dev/null 2>&1; then
    gh release edit "$tag" --title "$release_title" --notes "$notes"
  else
    gh release create "$tag" --title "$release_title" --notes "$notes"
  fi

  gh release upload "$tag" "$ipa_path#$ipa_name" --clobber
  local release_url=""
  release_url="$(gh release view "$tag" --json url -q .url 2>/dev/null || true)"
  if [[ -n "$release_url" ]]; then
    log "Published release: $release_url"
  else
    log "Published release tag: $tag"
  fi
}

stack_install() {
  install_frontend
  install_backend
  log "All dependencies installed"
}

swift_xcodegen() {
  require_cmd xcodegen
  log "Generating Xcode project from project.yml"
  run_in_dir "$MOBILE_DIR" xcodegen generate
  log "Xcode project generated"
}

swift_build() {
  require_cmd xcodebuild
  local scheme="Gymbo"
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
  run_in_dir "$MOBILE_DIR" xcodebuild -project Gymbo.xcodeproj -scheme "$scheme" -configuration "$configuration" -destination "$destination" build
}

swift_run() {
  require_cmd xcodebuild
  local scheme="Gymbo"
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

  local build_dir="$MOBILE_DIR/build"
  run_in_dir "$MOBILE_DIR" xcodebuild -project Gymbo.xcodeproj -scheme "$scheme" -configuration "$configuration" -destination "$destination" -derivedDataPath "$build_dir" build

  local app_path
  app_path=$(find "$build_dir" -name "*.app" -type d | head -n 1)

  if [[ -z "$app_path" ]]; then
    log "Failed to find built app bundle"
    exit 1
  fi

  log "Installing and launching app"
  local device_id
  device_id="$(find_simulator_udid "iPhone 17 Pro")"
  if [[ -n "$device_id" ]]; then
    xcrun simctl boot "$device_id" 2>/dev/null || true
    open -a Simulator --args -CurrentDeviceUDID "$device_id"
    xcrun simctl install "$device_id" "$app_path"
    xcrun simctl launch "$device_id" "com.gymbo.app"
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

stack_start() {
  build_frontend
  backend_start "$@"
}

usage() {
  cat <<USAGE
Usage: $(basename "$0") <command>

Commands:
  install:all           Install frontend and backend dependencies
  install:frontend      Install only frontend dependencies
  install:backend       Install only backend dependencies
  install:sync          Sync frontend (npm ci) and backend (uv sync) dependencies from lock files
  build:frontend        Build the frontend bundle
  frontend:dev          Start frontend dev server (opts: --host, --port, use -- to pass extra Vite args)
  backend:migrate       Apply latest Alembic migrations
  backend:migrate:status Show current Alembic revision
  backend:migrate:down  Downgrade Alembic revision (default target: -1)
  backend:start         Start FastAPI backend (opts: --host, --port, --no-reload, use -- for uvicorn args)
  mobile:env            Generate mobile Config/Env.generated.xcconfig
  swift:xcodegen        Generate Xcode project from project.yml
  swift:build           Build the iOS app (opts: --scheme, --configuration, --destination)
  swift:run             Build and run the iOS app in simulator (opts: --scheme, --configuration, --destination)
  mobile:release        Build unsigned Release IPA and publish/update GitHub release
                        opts: [--no-publish] [--suffix TEXT] [--deployment-target 26.0]
                              [--api-base-url URL] [--file-logging YES|NO] [--output-dir PATH]
  simulator:list        List available iOS simulators
  simulator:boot        Boot an iOS simulator (default: iPhone 17 Pro, or pass device name)
  start                 Build frontend, then start backend (accepts backend:start opts)
  help                  Show this message
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
  backend:migrate:status)
    backend_migrate_status
    ;;
  backend:migrate:down)
    backend_migrate_down "$@"
    ;;
  backend:start)
    backend_start "$@"
    ;;
  mobile:env)
    mobile_env
    ;;
  mobile:release)
    mobile_release "$@"
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
