"""External API proxy routes.

Provides endpoints for proxying requests to external movie databases (TMDB, OMDB)
with caching to reduce external API calls.
"""

from __future__ import annotations

from typing import Any

from app.services.external_apis import (
    discover_tmdb_movies_by_category,
    discover_tmdb_movies_by_genre,
    discover_tmdb_movies_by_person,
    get_cache_info,
    get_omdb_movie,
    get_tmdb_movie_details,
    get_tmdb_tv_details,
    search_tmdb_multi,
)
from auth import get_required_user
from fastapi import APIRouter, Depends, Query
from models import User

router = APIRouter(prefix="/external", tags=["external"])


@router.get("/tmdb/search")
async def tmdb_search(
    q: str = Query(..., min_length=1, description="Search query"),
    year: int | None = Query(None, ge=1800, le=2100, description="Optional release year"),
    _user: User = Depends(get_required_user),
) -> list[dict[str, Any]]:
    """Search for movies, TV shows, and people on TMDB.

    Args:
        q: Search query string
        _user: Authenticated user (required)

    Returns:
        List of normalized multi-search results
    """
    results = await search_tmdb_multi(q)
    if year is None:
        return results
    return [item for item in results if str(item.get("year")) == str(year)]


@router.get("/tmdb/discover/genre")
async def tmdb_discover_by_genre(
    q: str = Query(..., min_length=1, description="Genre search query"),
    _user: User = Depends(get_required_user),
) -> list[dict[str, Any]]:
    """Discover movies by genre."""
    return await discover_tmdb_movies_by_genre(q)


@router.get("/tmdb/discover/person")
async def tmdb_discover_by_person(
    q: str = Query(..., min_length=1, description="Person name"),
    role: str = Query("actor", pattern="^(actor|director)$", description="Discovery role"),
    _user: User = Depends(get_required_user),
) -> list[dict[str, Any]]:
    """Discover movies by actor or director."""
    return await discover_tmdb_movies_by_person(q, role=role)


@router.get("/tmdb/discover/list")
async def tmdb_discover_list(
    kind: str = Query(
        ...,
        pattern="^(coming_soon|now_playing|popular|top_rated|trending)$",
        description="List category",
    ),
    region: str = Query("US", min_length=2, max_length=2, description="ISO 3166-1 region"),
    days: int = Query(30, ge=1, le=90, description="Days ahead for coming soon"),
    time_window: str = Query("day", pattern="^(day|week)$", description="Trending window"),
    _user: User = Depends(get_required_user),
) -> list[dict[str, Any]]:
    """Discover curated TMDB movie lists."""
    return await discover_tmdb_movies_by_category(
        kind=kind,
        region=region,
        days=days,
        time_window=time_window,
    )


@router.get("/tmdb/movie/{tmdb_id}")
async def tmdb_movie_details(
    tmdb_id: int,
    _user: User = Depends(get_required_user),
) -> dict[str, Any]:
    """Get movie details from TMDB by ID.

    Args:
        tmdb_id: TMDB movie ID
        _user: Authenticated user (required)

    Returns:
        Movie details
    """
    return await get_tmdb_movie_details(tmdb_id)


@router.get("/tmdb/tv/{tmdb_id}")
async def tmdb_tv_details(
    tmdb_id: int,
    _user: User = Depends(get_required_user),
) -> dict[str, Any]:
    """Get TV show details from TMDB by ID."""
    return await get_tmdb_tv_details(tmdb_id)


@router.get("/omdb/movie/{imdb_id}")
async def omdb_movie_details(
    imdb_id: str,
    _user: User = Depends(get_required_user),
) -> dict[str, Any]:
    """Get movie details from OMDB by IMDb ID.

    Args:
        imdb_id: IMDb ID (e.g., "tt1234567")
        _user: Authenticated user (required)

    Returns:
        Movie details
    """
    return await get_omdb_movie(imdb_id)


@router.get("/cache/info")
async def cache_info(
    _user: User = Depends(get_required_user),
) -> dict[str, Any]:
    """Get cache statistics.

    Args:
        _user: Authenticated user (required)

    Returns:
        Cache information including size and TTL
    """
    return get_cache_info()
