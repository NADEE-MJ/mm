#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FRONTEND_DIR="$ROOT_DIR/frontend"
BACKEND_DIR="$ROOT_DIR/backend"

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
  log "Frontend and backend dependencies installed"
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
  build:frontend     Build the frontend bundle
  frontend:dev       Start the frontend dev server (opts: --host, --port, use -- to pass extra Vite args)
  backend:migrate    Apply the latest Alembic migrations
  backend:start      Start the FastAPI backend (opts: --host, --port, --no-reload, use -- for uvicorn args)
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
