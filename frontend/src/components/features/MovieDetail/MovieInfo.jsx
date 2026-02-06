import { Calendar, Users, Film, ArrowUpRight } from "lucide-react";

export default function MovieInfo({ omdb, tmdb }) {
  const plot = omdb.plot || tmdb.plot || "No plot available";
  const genres = omdb.genres || tmdb.genres || [];
  const cast = omdb.actors || tmdb.cast || [];
  const director = omdb.director || "";

  return (
    <div className="px-4 space-y-5">
      {/* Genres */}
      {genres.length > 0 && (
        <div>
          <div className="flex flex-wrap gap-2">
            {genres.map((genre) => (
              <span
                key={genre}
                className="px-3 py-1.5 bg-ios-fill rounded-full text-ios-label text-sm font-medium"
              >
                {genre}
              </span>
            ))}
          </div>
        </div>
      )}

      {/* Plot */}
      <div>
        <h2 className="text-ios-headline font-semibold text-ios-label mb-2">Plot</h2>
        <p className="text-ios-body text-ios-secondary-label leading-relaxed">{plot}</p>
      </div>

      {/* Info Grid */}
      <div className="ios-card divide-y divide-ios-separator">
        {director && (
          <div className="flex items-center gap-3 px-4 py-3">
            <Film className="w-5 h-5 text-ios-tertiary-label" />
            <div className="flex-1">
              <p className="text-ios-caption1 text-ios-tertiary-label">Director</p>
              <p className="text-ios-body text-ios-label">{director}</p>
            </div>
          </div>
        )}

        {cast.length > 0 && (
          <div className="flex items-center gap-3 px-4 py-3">
            <Users className="w-5 h-5 text-ios-tertiary-label" />
            <div className="flex-1">
              <p className="text-ios-caption1 text-ios-tertiary-label">Cast</p>
              <p className="text-ios-body text-ios-label">{cast.slice(0, 3).join(", ")}</p>
            </div>
          </div>
        )}

        {omdb.imdbId && (
          <a
            href={`https://www.imdb.com/title/${omdb.imdbId}`}
            target="_blank"
            rel="noopener noreferrer"
            className="flex items-center gap-3 px-4 py-3 active:bg-ios-fill-tertiary transition-colors"
          >
            <ArrowUpRight className="w-5 h-5 text-ios-blue" />
            <div className="flex-1">
              <p className="text-ios-body text-ios-blue">View on IMDb</p>
            </div>
          </a>
        )}
      </div>
    </div>
  );
}
