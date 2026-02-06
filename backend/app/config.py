"""Application configuration loaded from environment variables."""

from __future__ import annotations

import os
from pathlib import Path

from dotenv import load_dotenv

# Load .env file from backend directory
BACKEND_DIR = Path(__file__).resolve().parent.parent
ENV_FILE = BACKEND_DIR / ".env"

if ENV_FILE.exists():
    load_dotenv(ENV_FILE)


class Config:
    """Configuration class for application settings."""

    # Security
    SECRET_KEY: str = os.getenv("SECRET_KEY", "your-secret-key-change-in-production-please")

    # External API Keys
    TMDB_API_KEY: str | None = os.getenv("TMDB_API_KEY")
    OMDB_API_KEY: str | None = os.getenv("OMDB_API_KEY")

    # Database
    DATABASE_URL: str = os.getenv("DATABASE_URL", "sqlite:///./app.db")

    # Server
    HOST: str = os.getenv("HOST", "0.0.0.0")
    PORT: int = int(os.getenv("PORT", "8001"))

    # CORS
    CORS_ORIGINS: list[str] = [
        origin.strip()
        for origin in os.getenv("CORS_ORIGINS", "http://localhost:5173,http://localhost:3000").split(",")
        if origin.strip()
    ]


# Create a singleton instance
config = Config()

__all__ = ["config", "Config"]
