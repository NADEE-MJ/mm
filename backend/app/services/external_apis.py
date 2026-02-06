"""External movie API integrations with caching.

This module provides an interface to TMDB and OMDB APIs with in-memory caching
to reduce external API calls and improve response times.
"""

from __future__ import annotations

import os
from typing import Any

import httpx
from cachetools import TTLCache
from fastapi import HTTPException, status

# Cache configuration: 500 items, 1 hour TTL
# This cache is shared across all requests and lives in memory
_cache: TTLCache = TTLCache(maxsize=500, ttl=3600)

# API configuration from environment
TMDB_API_KEY = os.getenv("TMDB_API_KEY")
OMDB_API_KEY = os.getenv("OMDB_API_KEY")
TMDB_BASE_URL = "https://api.themoviedb.org/3"
OMDB_BASE_URL = "https://www.omdbapi.com"
TMDB_IMAGE_BASE = "https://image.tmdb.org/t/p"


def _get_cache_key(prefix: str, *args: Any) -> str:
    """Generate a cache key from prefix and arguments."""
    return f"{prefix}:{'|'.join(str(arg) for arg in args)}"


async def search_tmdb_movies(query: str) -> list[dict[str, Any]]:
    """Search for movies on TMDB with caching.

    Args:
        query: Search query string

    Returns:
        List of movie results

    Raises:
        HTTPException: If API key not configured or API request fails
    """
    if not TMDB_API_KEY:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="TMDB API key not configured",
        )

    cache_key = _get_cache_key("tmdb_search", query.lower().strip())
    if cache_key in _cache:
        return _cache[cache_key]

    url = f"{TMDB_BASE_URL}/search/movie"
    params = {"api_key": TMDB_API_KEY, "query": query}

    async with httpx.AsyncClient() as client:
        try:
            response = await client.get(url, params=params, timeout=10.0)
            response.raise_for_status()
            data = response.json()

            # Transform results to simplified format
            results = [
                {
                    "id": movie["id"],
                    "title": movie["title"],
                    "year": (
                        movie["release_date"][:4] if movie.get("release_date") else None
                    ),
                    "poster": (
                        f"{TMDB_IMAGE_BASE}/w500{movie['poster_path']}"
                        if movie.get("poster_path")
                        else None
                    ),
                    "posterSmall": (
                        f"{TMDB_IMAGE_BASE}/w200{movie['poster_path']}"
                        if movie.get("poster_path")
                        else None
                    ),
                    "overview": movie.get("overview"),
                    "voteAverage": movie.get("vote_average"),
                    "voteCount": movie.get("vote_count"),
                }
                for movie in data.get("results", [])
            ]

            _cache[cache_key] = results
            return results

        except httpx.HTTPStatusError as e:
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail=f"TMDB API error: {e.response.status_code}",
            ) from e
        except httpx.RequestError as e:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail=f"Failed to connect to TMDB: {str(e)}",
            ) from e


async def get_tmdb_movie_details(tmdb_id: int) -> dict[str, Any]:
    """Get movie details from TMDB by ID with caching.

    Args:
        tmdb_id: TMDB movie ID

    Returns:
        Movie details dictionary

    Raises:
        HTTPException: If API key not configured or API request fails
    """
    if not TMDB_API_KEY:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="TMDB API key not configured",
        )

    cache_key = _get_cache_key("tmdb_movie", tmdb_id)
    if cache_key in _cache:
        return _cache[cache_key]

    url = f"{TMDB_BASE_URL}/movie/{tmdb_id}"
    params = {"api_key": TMDB_API_KEY, "append_to_response": "credits,external_ids"}

    async with httpx.AsyncClient() as client:
        try:
            response = await client.get(url, params=params, timeout=10.0)
            response.raise_for_status()
            movie = response.json()

            # Transform to simplified format
            result = {
                "tmdbId": movie["id"],
                "imdbId": movie.get("external_ids", {}).get("imdb_id"),
                "title": movie["title"],
                "year": movie["release_date"][:4] if movie.get("release_date") else None,
                "poster": (
                    f"{TMDB_IMAGE_BASE}/w500{movie['poster_path']}"
                    if movie.get("poster_path")
                    else None
                ),
                "posterSmall": (
                    f"{TMDB_IMAGE_BASE}/w200{movie['poster_path']}"
                    if movie.get("poster_path")
                    else None
                ),
                "plot": movie.get("overview"),
                "genres": [g["name"] for g in movie.get("genres", [])],
                "cast": [
                    c["name"] for c in movie.get("credits", {}).get("cast", [])[:10]
                ],
                "runtime": movie.get("runtime"),
                "voteAverage": movie.get("vote_average"),
                "voteCount": movie.get("vote_count"),
            }

            _cache[cache_key] = result
            return result

        except httpx.HTTPStatusError as e:
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail=f"TMDB API error: {e.response.status_code}",
            ) from e
        except httpx.RequestError as e:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail=f"Failed to connect to TMDB: {str(e)}",
            ) from e


async def get_omdb_movie(imdb_id: str) -> dict[str, Any]:
    """Get movie details from OMDB by IMDb ID with caching.

    Args:
        imdb_id: IMDb ID (e.g., "tt1234567")

    Returns:
        Movie details dictionary

    Raises:
        HTTPException: If API key not configured or API request fails
    """
    if not OMDB_API_KEY:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="OMDB API key not configured",
        )

    cache_key = _get_cache_key("omdb_movie", imdb_id)
    if cache_key in _cache:
        return _cache[cache_key]

    url = OMDB_BASE_URL
    params = {"apikey": OMDB_API_KEY, "i": imdb_id}

    async with httpx.AsyncClient() as client:
        try:
            response = await client.get(url, params=params, timeout=10.0)
            response.raise_for_status()
            data = response.json()

            if data.get("Response") == "False":
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail=data.get("Error", "Movie not found"),
                )

            # Parse Rotten Tomatoes rating
            rt_rating = None
            ratings = data.get("Ratings", [])
            for rating in ratings:
                if rating.get("Source") == "Rotten Tomatoes":
                    try:
                        rt_rating = int(rating["Value"].replace("%", ""))
                    except (ValueError, KeyError):
                        pass
                    break

            # Transform to simplified format
            result = {
                "imdbId": data.get("imdbID"),
                "title": data.get("Title"),
                "year": int(data["Year"]) if data.get("Year", "").isdigit() else None,
                "rated": data.get("Rated"),
                "released": data.get("Released"),
                "runtime": data.get("Runtime"),
                "genres": data.get("Genre", "").split(", ") if data.get("Genre") else [],
                "director": data.get("Director"),
                "writer": data.get("Writer"),
                "actors": (
                    data.get("Actors", "").split(", ") if data.get("Actors") else []
                ),
                "plot": data.get("Plot"),
                "language": data.get("Language"),
                "country": data.get("Country"),
                "awards": data.get("Awards"),
                "poster": data.get("Poster") if data.get("Poster") != "N/A" else None,
                "imdbRating": (
                    float(data["imdbRating"])
                    if data.get("imdbRating")
                    and data["imdbRating"] != "N/A"
                    else None
                ),
                "imdbVotes": data.get("imdbVotes"),
                "rtRating": rt_rating,
                "metascore": (
                    int(data["Metascore"])
                    if data.get("Metascore") and data["Metascore"] != "N/A"
                    else None
                ),
                "boxOffice": data.get("BoxOffice"),
                "production": data.get("Production"),
                "website": data.get("Website"),
            }

            _cache[cache_key] = result
            return result

        except httpx.HTTPStatusError as e:
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail=f"OMDB API error: {e.response.status_code}",
            ) from e
        except httpx.RequestError as e:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail=f"Failed to connect to OMDB: {str(e)}",
            ) from e


def clear_cache() -> None:
    """Clear the entire API cache. Useful for testing or manual cache invalidation."""
    _cache.clear()


def get_cache_info() -> dict[str, Any]:
    """Get cache statistics for monitoring.

    Returns:
        Dictionary with cache size and max size
    """
    return {"current_size": len(_cache), "max_size": _cache.maxsize, "ttl": _cache.ttl}
