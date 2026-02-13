"""External movie API integrations with caching.

This module provides an interface to TMDB and OMDB APIs with in-memory caching
to reduce external API calls and improve response times.
"""

from __future__ import annotations

from datetime import date, datetime, timedelta
from typing import Any

import httpx
from cachetools import TTLCache
from fastapi import HTTPException, status

from app.config import config

# Cache configuration: 500 items, 1 hour TTL
# This cache is shared across all requests and lives in memory
_cache: TTLCache = TTLCache(maxsize=500, ttl=3600)

# API configuration from environment
TMDB_API_KEY = config.TMDB_API_KEY
OMDB_API_KEY = config.OMDB_API_KEY
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


async def _fetch_tmdb_genres() -> list[dict[str, Any]]:
    """Fetch TMDB movie genres with caching."""
    if not TMDB_API_KEY:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="TMDB API key not configured",
        )

    cache_key = _get_cache_key("tmdb_genres")
    if cache_key in _cache:
        return _cache[cache_key]

    url = f"{TMDB_BASE_URL}/genre/movie/list"
    params = {"api_key": TMDB_API_KEY}

    async with httpx.AsyncClient() as client:
        try:
            response = await client.get(url, params=params, timeout=10.0)
            response.raise_for_status()
            data = response.json()
            genres = data.get("genres", [])
            _cache[cache_key] = genres
            return genres
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


def _to_simple_movie_result(movie: dict[str, Any]) -> dict[str, Any]:
    """Normalize a TMDB movie payload to the app's shared result format."""
    release_date = movie.get("release_date")
    return {
        "id": movie.get("id"),
        "title": movie.get("title"),
        "year": release_date[:4] if release_date else None,
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


async def discover_tmdb_movies_by_genre(genre_query: str) -> list[dict[str, Any]]:
    """Discover TMDB movies by genre name match."""
    if not TMDB_API_KEY:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="TMDB API key not configured",
        )

    query = genre_query.strip().lower()
    if not query:
        return []

    cache_key = _get_cache_key("tmdb_discover_genre", query)
    if cache_key in _cache:
        return _cache[cache_key]

    genres = await _fetch_tmdb_genres()
    exact = [g for g in genres if str(g.get("name", "")).strip().lower() == query]
    partial = [
        g
        for g in genres
        if query in str(g.get("name", "")).strip().lower()
    ]
    matched = exact if exact else partial
    genre_ids = [str(g["id"]) for g in matched if g.get("id") is not None]
    if not genre_ids:
        return []

    url = f"{TMDB_BASE_URL}/discover/movie"
    params = {
        "api_key": TMDB_API_KEY,
        "with_genres": "|".join(genre_ids),
        "sort_by": "popularity.desc",
        "include_adult": "false",
        "page": 1,
    }

    async with httpx.AsyncClient() as client:
        try:
            response = await client.get(url, params=params, timeout=10.0)
            response.raise_for_status()
            data = response.json()
            results = [
                _to_simple_movie_result(movie)
                for movie in data.get("results", [])
                if movie.get("id") and movie.get("title")
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


async def discover_tmdb_movies_by_person(
    person_query: str, *, role: str = "actor"
) -> list[dict[str, Any]]:
    """Discover TMDB movies by actor/director name."""
    if not TMDB_API_KEY:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="TMDB API key not configured",
        )

    normalized_role = role.strip().lower()
    if normalized_role not in {"actor", "director"}:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="role must be either 'actor' or 'director'",
        )

    query = person_query.strip().lower()
    if not query:
        return []

    cache_key = _get_cache_key("tmdb_discover_person", query, normalized_role)
    if cache_key in _cache:
        return _cache[cache_key]

    search_url = f"{TMDB_BASE_URL}/search/person"
    search_params = {"api_key": TMDB_API_KEY, "query": person_query.strip(), "page": 1}

    async with httpx.AsyncClient() as client:
        try:
            search_response = await client.get(search_url, params=search_params, timeout=10.0)
            search_response.raise_for_status()
            people = search_response.json().get("results", [])
            if not people:
                return []

            exact = next(
                (
                    p
                    for p in people
                    if str(p.get("name", "")).strip().lower() == query
                ),
                None,
            )
            selected_person = exact if exact else people[0]
            person_id = selected_person.get("id")
            if person_id is None:
                return []

            credits_url = f"{TMDB_BASE_URL}/person/{person_id}/movie_credits"
            credits_params = {"api_key": TMDB_API_KEY}
            credits_response = await client.get(credits_url, params=credits_params, timeout=10.0)
            credits_response.raise_for_status()
            credits = credits_response.json()

            if normalized_role == "director":
                source_movies = [
                    movie
                    for movie in credits.get("crew", [])
                    if str(movie.get("job", "")).strip().lower() == "director"
                ]
            else:
                source_movies = credits.get("cast", [])

            deduped: dict[int, dict[str, Any]] = {}
            for movie in source_movies:
                movie_id = movie.get("id")
                if movie_id is None:
                    continue
                deduped[movie_id] = movie

            sorted_movies = sorted(
                deduped.values(),
                key=lambda item: (
                    float(item.get("popularity") or 0.0),
                    str(item.get("release_date") or ""),
                ),
                reverse=True,
            )

            results = [
                _to_simple_movie_result(movie)
                for movie in sorted_movies
                if movie.get("id") and movie.get("title")
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


async def discover_tmdb_movies_by_category(
    kind: str,
    *,
    region: str = "US",
    days: int = 30,
    time_window: str = "day",
) -> list[dict[str, Any]]:
    """Discover TMDB movies by curated list category."""
    if not TMDB_API_KEY:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="TMDB API key not configured",
        )

    normalized_kind = kind.strip().lower()
    supported_kinds = {"coming_soon", "now_playing", "popular", "top_rated", "trending"}
    if normalized_kind not in supported_kinds:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"kind must be one of: {', '.join(sorted(supported_kinds))}",
        )

    normalized_region = (region or "US").strip().upper()
    if len(normalized_region) != 2 or not normalized_region.isalpha():
        normalized_region = "US"

    normalized_days = max(1, min(days, 90))
    normalized_time_window = time_window.strip().lower()
    if normalized_time_window not in {"day", "week"}:
        normalized_time_window = "day"

    cache_key = _get_cache_key(
        "tmdb_discover_category",
        normalized_kind,
        normalized_region,
        normalized_days,
        normalized_time_window,
    )
    if cache_key in _cache:
        return _cache[cache_key]

    if normalized_kind == "coming_soon":
        start_date = date.today()
        end_date = start_date + timedelta(days=normalized_days)
        url = f"{TMDB_BASE_URL}/movie/upcoming"
        params = {
            "api_key": TMDB_API_KEY,
            "region": normalized_region,
            "include_adult": "false",
            "page": 1,
        }
    elif normalized_kind == "trending":
        url = f"{TMDB_BASE_URL}/trending/movie/{normalized_time_window}"
        params = {"api_key": TMDB_API_KEY, "page": 1}
    else:
        url = f"{TMDB_BASE_URL}/movie/{normalized_kind}"
        params = {"api_key": TMDB_API_KEY, "region": normalized_region, "page": 1}

    async with httpx.AsyncClient() as client:
        try:
            response = await client.get(url, params=params, timeout=10.0)
            response.raise_for_status()
            data = response.json()
            source_results = data.get("results", [])
            if normalized_kind == "coming_soon":
                filtered_movies: list[dict[str, Any]] = []
                for movie in source_results:
                    release_date_value = str(movie.get("release_date") or "").strip()
                    if not release_date_value:
                        continue
                    try:
                        parsed = datetime.strptime(release_date_value, "%Y-%m-%d").date()
                    except ValueError:
                        continue
                    if start_date <= parsed <= end_date:
                        filtered_movies.append(movie)

                filtered_movies.sort(
                    key=lambda item: str(item.get("release_date") or "")
                )
                source_results = filtered_movies

            results = [
                _to_simple_movie_result(movie)
                for movie in source_results
                if movie.get("id") and movie.get("title")
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


async def get_tmdb_movie_details(
    tmdb_id: int, *, force_refresh: bool = False
) -> dict[str, Any]:
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
    if not force_refresh and cache_key in _cache:
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


async def get_omdb_movie(imdb_id: str, *, force_refresh: bool = False) -> dict[str, Any]:
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
    if not force_refresh and cache_key in _cache:
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
