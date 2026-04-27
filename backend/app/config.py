"""Application configuration loaded from environment variables."""

from __future__ import annotations

import os
from pathlib import Path

from dotenv import load_dotenv

BACKEND_DIR = Path(__file__).resolve().parent.parent
ENV_FILE = BACKEND_DIR / ".env"
if ENV_FILE.exists():
    load_dotenv(ENV_FILE)


class Config:
    SECRET_KEY: str = os.getenv("SECRET_KEY", "gymbo-secret-key-change-in-production")
    ADMIN_TOKEN: str | None = os.getenv("ADMIN_TOKEN")

    DATABASE_URL: str = os.getenv("DATABASE_URL", "sqlite:///./app.db")

    HOST: str = os.getenv("HOST", "0.0.0.0")
    PORT: int = int(os.getenv("PORT", "8002"))

    CORS_ORIGINS: list[str] = [
        origin.strip()
        for origin in os.getenv(
            "CORS_ORIGINS",
            "http://localhost:5173,http://localhost:3000",
        ).split(",")
        if origin.strip()
    ]


config = Config()

__all__ = ["config", "Config"]
