#!/usr/bin/env python3
"""Convert movie/TV CSV exports into Movie Manager import JSON.

The output matches the backup import schema accepted by:
POST /api/backup/import
"""

from __future__ import annotations

import argparse
import asyncio
import csv
import json
import os
import re
import time
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

import httpx

TMDB_BASE_URL = "https://api.themoviedb.org/3"
DEFAULT_COLOR = "#0a84ff"


@dataclass
class MovieEntry:
    title: str
    media_type: str
    watched: bool
    recommenders: set[str] = field(default_factory=set)
    source_rows: list[str] = field(default_factory=list)


@dataclass
class ResolvedMovie:
    title: str
    media_type: str
    tmdb_id: int
    imdb_id: str
    year: str | None


class RateLimiter:
    def __init__(self, requests_per_second: float) -> None:
        self._min_interval = 1.0 / requests_per_second
        self._lock = asyncio.Lock()
        self._next_allowed = 0.0

    async def wait(self) -> None:
        async with self._lock:
            now = time.monotonic()
            sleep_for = self._next_allowed - now
            if sleep_for > 0:
                await asyncio.sleep(sleep_for)
                now = time.monotonic()
            self._next_allowed = max(now, self._next_allowed) + self._min_interval


class TMDBResolver:
    def __init__(
        self,
        *,
        api_key: str,
        requests_per_second: float,
        concurrency: int,
        timeout_seconds: float,
    ) -> None:
        self._api_key = api_key
        self._limiter = RateLimiter(requests_per_second)
        self._semaphore = asyncio.Semaphore(concurrency)
        self._timeout = timeout_seconds

    async def _request_json(
        self,
        client: httpx.AsyncClient,
        path: str,
        params: dict[str, Any],
    ) -> dict[str, Any]:
        full_params = {"api_key": self._api_key, **params}
        backoff_seconds = 0.5
        last_error: Exception | None = None
        for _attempt in range(4):
            try:
                await self._limiter.wait()
                response = await client.get(path, params=full_params, timeout=self._timeout)
                if response.status_code == 429:
                    retry_after = response.headers.get("Retry-After")
                    sleep_seconds = float(retry_after) if retry_after else backoff_seconds
                    await asyncio.sleep(sleep_seconds)
                    backoff_seconds = min(backoff_seconds * 2, 4.0)
                    continue
                response.raise_for_status()
                return response.json()
            except (httpx.RequestError, httpx.HTTPStatusError) as exc:
                last_error = exc
                await asyncio.sleep(backoff_seconds)
                backoff_seconds = min(backoff_seconds * 2, 4.0)
        raise RuntimeError(f"TMDB request failed for {path}: {last_error}")

    def _choose_best_result(self, title: str, results: list[dict[str, Any]]) -> dict[str, Any] | None:
        if not results:
            return None
        target = _normalize_title_key(title)

        def score(item: dict[str, Any]) -> tuple[int, float]:
            candidate_title = str(item.get("title") or item.get("name") or "")
            candidate = _normalize_title_key(candidate_title)
            value = 0
            if candidate == target:
                value += 100
            elif candidate.startswith(target) or target.startswith(candidate):
                value += 60
            elif target in candidate or candidate in target:
                value += 30
            popularity = float(item.get("popularity") or 0.0)
            return value, popularity

        return max(results, key=score)

    async def resolve_entry(
        self,
        client: httpx.AsyncClient,
        entry: MovieEntry,
    ) -> tuple[ResolvedMovie | None, str | None]:
        endpoint = "/search/tv" if entry.media_type == "tv" else "/search/movie"
        search_payload = await self._request_json(
            client,
            endpoint,
            {"query": entry.title, "include_adult": "false", "page": 1},
        )
        best = self._choose_best_result(entry.title, list(search_payload.get("results", [])))
        if not best:
            return None, "no TMDB search result"

        tmdb_id = best.get("id")
        if not isinstance(tmdb_id, int):
            return None, "TMDB result missing id"

        details_endpoint = f"/tv/{tmdb_id}" if entry.media_type == "tv" else f"/movie/{tmdb_id}"
        details = await self._request_json(
            client,
            details_endpoint,
            {"append_to_response": "external_ids"},
        )
        imdb_id = str((details.get("external_ids") or {}).get("imdb_id") or "").strip()
        if not imdb_id:
            return None, "TMDB details missing IMDb id"

        year_source = (
            str(best.get("first_air_date") or "")
            if entry.media_type == "tv"
            else str(best.get("release_date") or "")
        )
        year = year_source[:4] if len(year_source) >= 4 else None

        title = str(best.get("name") if entry.media_type == "tv" else best.get("title") or entry.title).strip()
        return (
            ResolvedMovie(
                title=title or entry.title,
                media_type=entry.media_type,
                tmdb_id=tmdb_id,
                imdb_id=imdb_id,
                year=year,
            ),
            None,
        )

    async def resolve_all(
        self,
        entries: list[MovieEntry],
    ) -> tuple[list[tuple[MovieEntry, ResolvedMovie]], list[tuple[MovieEntry, str]]]:
        resolved: list[tuple[MovieEntry, ResolvedMovie]] = []
        unresolved: list[tuple[MovieEntry, str]] = []
        async with httpx.AsyncClient(base_url=TMDB_BASE_URL) as client:
            tasks = [self._resolve_with_guard(client, entry) for entry in entries]
            for entry, result, reason in await asyncio.gather(*tasks):
                if result:
                    resolved.append((entry, result))
                else:
                    unresolved.append((entry, reason or "unknown error"))
        return resolved, unresolved

    async def _resolve_with_guard(
        self,
        client: httpx.AsyncClient,
        entry: MovieEntry,
    ) -> tuple[MovieEntry, ResolvedMovie | None, str | None]:
        async with self._semaphore:
            try:
                result, reason = await self.resolve_entry(client, entry)
                return entry, result, reason
            except Exception as exc:  # noqa: BLE001
                return entry, None, str(exc)


def _normalize_header(value: str) -> str:
    return re.sub(r"[^a-z0-9]+", "", value.lower())


def _normalize_title_key(value: str) -> str:
    return re.sub(r"[^a-z0-9]+", "", value.lower())


def _parse_bool_watched(value: str) -> bool:
    text = value.strip().lower()
    return text in {"yes", "y", "true", "t", "1", "watched"}


def _split_recommenders(raw: str) -> list[str]:
    if not raw:
        return []
    parts = [piece.strip() for piece in re.split(r"[;,]", raw) if piece.strip()]
    return parts


def _load_tmdb_api_key(explicit_key: str | None) -> str:
    if explicit_key:
        return explicit_key.strip()
    env_key = os.getenv("TMDB_API_KEY")
    if env_key:
        return env_key.strip()

    env_file = Path(__file__).resolve().parents[1] / ".env"
    if env_file.exists():
        for line in env_file.read_text(encoding="utf-8").splitlines():
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            key, value = line.split("=", 1)
            if key.strip() == "TMDB_API_KEY":
                return value.strip().strip("\"'")
    raise ValueError(
        "TMDB_API_KEY not found. Pass --tmdb-api-key or set TMDB_API_KEY in env/backend .env."
    )


def _normalize_cli_path(path_value: Path | None) -> Path | None:
    if path_value is None:
        return None

    raw = str(path_value).strip()
    if len(raw) >= 2 and raw[0] == raw[-1] and raw[0] in {"'", '"'}:
        raw = raw[1:-1]

    # Accept accidental escaped spaces from copied shell paths.
    while "\\ " in raw:
        raw = raw.replace("\\ ", " ")
    return Path(raw).expanduser()


def _read_csv_entries(
    csv_path: Path,
    *,
    media_type: str,
    default_recommender: str | None,
) -> list[MovieEntry]:
    with csv_path.open(newline="", encoding="utf-8-sig") as handle:
        reader = csv.DictReader(handle)
        if not reader.fieldnames:
            return []

        normalized_fields = {_normalize_header(name): name for name in reader.fieldnames}
        name_col = normalized_fields.get("name")
        watched_col = normalized_fields.get("watched")
        recommender_col = (
            normalized_fields.get("recommendedby")
            or normalized_fields.get("recommendby")
            or normalized_fields.get("recommender")
        )
        if not name_col:
            raise ValueError(f"{csv_path} is missing required 'Name' column")

        entries: list[MovieEntry] = []
        for index, row in enumerate(reader, start=2):
            title = str(row.get(name_col) or "").strip()
            if not title:
                continue
            watched_value = str(row.get(watched_col) or "") if watched_col else ""
            recommenders = set(_split_recommenders(str(row.get(recommender_col) or ""))) if recommender_col else set()
            if not recommenders and default_recommender:
                recommenders.add(default_recommender)
            entries.append(
                MovieEntry(
                    title=title,
                    media_type=media_type,
                    watched=_parse_bool_watched(watched_value),
                    recommenders=recommenders,
                    source_rows=[f"{csv_path}:{index}"],
                )
            )
    return entries


def _merge_entries(entries: list[MovieEntry]) -> list[MovieEntry]:
    merged: dict[tuple[str, str], MovieEntry] = {}
    for entry in entries:
        key = (entry.media_type, _normalize_title_key(entry.title))
        existing = merged.get(key)
        if not existing:
            merged[key] = entry
            continue
        existing.watched = existing.watched or entry.watched
        existing.recommenders.update(entry.recommenders)
        existing.source_rows.extend(entry.source_rows)
    return list(merged.values())


def _build_import_payload(resolved_rows: list[tuple[MovieEntry, ResolvedMovie]]) -> dict[str, Any]:
    now = time.time()

    unique_people = sorted(
        {name for entry, _resolved in resolved_rows for name in entry.recommenders},
        key=str.lower,
    )

    movies: list[dict[str, Any]] = []
    for entry, resolved in sorted(resolved_rows, key=lambda pair: pair[0].title.lower()):
        recommendations = [
            {
                "person_name": recommender,
                "date_recommended": now,
                "vote_type": True,
            }
            for recommender in sorted(entry.recommenders, key=str.lower)
        ]
        movies.append(
            {
                "imdb_id": resolved.imdb_id,
                "media_type": resolved.media_type,
                "status": "watched" if entry.watched else "toWatch",
                "custom_list_id": None,
                "last_modified": now,
                "tmdb_data": {
                    "tmdbId": resolved.tmdb_id,
                    "imdbId": resolved.imdb_id,
                    "title": resolved.title,
                    "year": resolved.year,
                    "mediaType": resolved.media_type,
                },
                "omdb_data": None,
                "recommendations": recommendations,
                "watch_history": None,
            }
        )

    people = [
        {
            "name": name,
            "is_trusted": False,
            "color": DEFAULT_COLOR,
            "emoji": None,
            "last_modified": now,
        }
        for name in unique_people
    ]

    return {
        "version": 2,
        "exported_at": now,
        "movies": movies,
        "people": people,
        "lists": [],
    }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Convert movie and TV CSV files into app import JSON with TMDB IMDb resolution."
    )
    parser.add_argument("--movies-csv", type=Path, help="Path to movies CSV file")
    parser.add_argument("--tv-csv", type=Path, help="Path to TV shows CSV file")
    parser.add_argument(
        "--output",
        type=Path,
        default=Path("for_importing/converted-import.json"),
        help="Output JSON path (default: for_importing/converted-import.json)",
    )
    parser.add_argument(
        "--unresolved-report",
        type=Path,
        default=Path("for_importing/converted-import.unresolved.json"),
        help="Where unresolved rows report is written",
    )
    parser.add_argument("--default-recommender", default=None, help="Fallback recommender name")
    parser.add_argument("--tmdb-api-key", default=None, help="TMDB API key override")
    parser.add_argument(
        "--rps",
        type=float,
        default=30.0,
        help="Max TMDB requests per second (default: 30.0)",
    )
    parser.add_argument(
        "--concurrency",
        type=int,
        default=12,
        help="Concurrent TMDB request workers (default: 12)",
    )
    parser.add_argument(
        "--timeout",
        type=float,
        default=12.0,
        help="HTTP timeout seconds for TMDB calls (default: 12.0)",
    )
    parser.add_argument(
        "--fail-on-unresolved",
        action="store_true",
        help="Exit non-zero if any titles cannot be resolved to IMDb ids",
    )
    return parser.parse_args()


async def main() -> int:
    args = parse_args()
    movies_csv = _normalize_cli_path(args.movies_csv)
    tv_csv = _normalize_cli_path(args.tv_csv)
    output_path = _normalize_cli_path(args.output)
    unresolved_report_path = _normalize_cli_path(args.unresolved_report)

    if not movies_csv and not tv_csv:
        raise ValueError("Provide at least one input: --movies-csv and/or --tv-csv")

    all_entries: list[MovieEntry] = []
    if movies_csv:
        all_entries.extend(
            _read_csv_entries(
                movies_csv,
                media_type="movie",
                default_recommender=args.default_recommender,
            )
        )
    if tv_csv:
        all_entries.extend(
            _read_csv_entries(
                tv_csv,
                media_type="tv",
                default_recommender=args.default_recommender,
            )
        )

    merged_entries = _merge_entries(all_entries)
    if not merged_entries:
        raise ValueError("No valid rows found in input CSV(s)")

    tmdb_api_key = _load_tmdb_api_key(args.tmdb_api_key)
    resolver = TMDBResolver(
        api_key=tmdb_api_key,
        requests_per_second=args.rps,
        concurrency=args.concurrency,
        timeout_seconds=args.timeout,
    )
    resolved_rows, unresolved_rows = await resolver.resolve_all(merged_entries)

    payload = _build_import_payload(resolved_rows)
    if output_path is None:
        raise ValueError("Output path is required")
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(payload, indent=2), encoding="utf-8")

    unresolved_payload = [
        {
            "title": entry.title,
            "media_type": entry.media_type,
            "reason": reason,
            "sources": entry.source_rows,
        }
        for entry, reason in unresolved_rows
    ]
    if unresolved_report_path is None:
        raise ValueError("Unresolved report path is required")
    unresolved_report_path.parent.mkdir(parents=True, exist_ok=True)
    unresolved_report_path.write_text(json.dumps(unresolved_payload, indent=2), encoding="utf-8")

    print(f"Resolved: {len(resolved_rows)}")
    print(f"Unresolved: {len(unresolved_rows)}")
    print(f"Import JSON: {output_path}")
    print(f"Unresolved report: {unresolved_report_path}")

    if args.fail_on_unresolved and unresolved_rows:
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(asyncio.run(main()))
