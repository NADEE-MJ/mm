"""FastAPI application factory and top-level routes."""

from __future__ import annotations

import logging
from pathlib import Path

from app.api.router import register_routers
from app.config import config
from database import engine
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles
from models import Base

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

APP_DIR = Path(__file__).resolve().parent
BACKEND_DIR = APP_DIR.parent
PROJECT_ROOT = BACKEND_DIR.parent
STATIC_PATH = PROJECT_ROOT / "frontend" / "dist"


def create_app() -> FastAPI:
    """Create and configure the FastAPI application."""
    Base.metadata.create_all(bind=engine)

    application = FastAPI(title="Movie Recommendations API", version="2.0.0")
    configure_cors(application)
    register_routers(application)
    configure_static_routes(application)
    return application


def configure_cors(app: FastAPI) -> None:
    """Apply CORS configuration from environment."""
    app.add_middleware(
        CORSMiddleware,
        allow_origins=config.CORS_ORIGINS,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )


def configure_static_routes(app: FastAPI) -> None:
    """Mount built frontend assets if they exist."""
    if STATIC_PATH.exists():
        assets_path = STATIC_PATH / "assets"
        if assets_path.exists():
            app.mount("/assets", StaticFiles(directory=str(assets_path)), name="assets")
        logger.info("Static files mounted from: %s", STATIC_PATH)
    else:
        logger.warning("Static directory not found. Looked for: %s", STATIC_PATH)


app = create_app()


@app.get("/manifest.json")
async def serve_manifest() -> FileResponse:
    """Serve PWA manifest."""
    manifest_file = STATIC_PATH / "manifest.json"
    if manifest_file.exists():
        return FileResponse(str(manifest_file), media_type="application/json")
    raise HTTPException(status_code=404, detail="Manifest not found")


@app.get("/sw.js")
async def serve_service_worker() -> FileResponse:
    """Serve service worker."""
    sw_file = STATIC_PATH / "sw.js"
    if sw_file.exists():
        return FileResponse(str(sw_file), media_type="application/javascript")
    raise HTTPException(status_code=404, detail="Service worker not found")


@app.get("/icon-{size}.png")
async def serve_icon(size: str) -> FileResponse:
    """Serve PWA icons."""
    icon_file = STATIC_PATH / f"icon-{size}.png"
    if icon_file.exists():
        return FileResponse(str(icon_file), media_type="image/png")
    favicon_file = STATIC_PATH / "vite.svg"
    if favicon_file.exists():
        return FileResponse(str(favicon_file), media_type="image/svg+xml")
    raise HTTPException(status_code=404, detail="Icon not found")


@app.get("/vite.svg")
async def serve_vite_svg() -> FileResponse:
    """Serve favicon."""
    favicon_file = STATIC_PATH / "vite.svg"
    if favicon_file.exists():
        return FileResponse(str(favicon_file), media_type="image/svg+xml")
    raise HTTPException(status_code=404, detail="Favicon not found")


@app.get("/{full_path:path}")
async def serve_frontend(full_path: str) -> FileResponse:
    """Serve the built SPA for non-API routes."""
    if full_path.startswith(("api/", "docs", "redoc", "openapi.json")):
        raise HTTPException(status_code=404, detail="Endpoint not found")

    index_file = STATIC_PATH / "index.html"
    if index_file.exists():
        return FileResponse(str(index_file))

    raise HTTPException(
        status_code=500,
        detail="Frontend not built. Run 'cd frontend && npm run build' first.",
    )


__all__ = ["app", "create_app"]
