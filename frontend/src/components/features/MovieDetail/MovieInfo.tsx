import { Calendar, Users, Film, ArrowUpRight } from "lucide-react";

function splitPeopleList(value) {
  return (value || "")
    .split(",")
    .map((name) => name.trim())
    .filter(Boolean);
}

export default function MovieInfo({ omdb, tmdb, onOpenPerson, onOpenGenre, onOpenCompany }) {
  const plot = omdb.plot || tmdb.plot || "No plot available";
  const genres = omdb.genres || tmdb.genres || [];
  const cast = omdb.actors || tmdb.cast || [];
  const directors = splitPeopleList(omdb.director);
  const companies = tmdb.productionCompanies?.length
    ? tmdb.productionCompanies
    : splitPeopleList(omdb.production);

  return (
    <div className="px-4 space-y-5">
      {/* Genres */}
      {genres.length > 0 && (
        <div>
          <div className="flex flex-wrap gap-2">
            {genres.map((genre) => (
              <button
                type="button"
                key={genre}
                onClick={() => onOpenGenre?.(genre)}
                disabled={!onOpenGenre}
                className="px-3 py-1.5 bg-ios-fill rounded-full text-ios-label text-sm font-medium disabled:cursor-default enabled:hover:bg-ios-fill-secondary enabled:active:scale-95 transition-transform"
              >
                {genre}
              </button>
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
        {directors.length > 0 && (
          <div className="flex items-center gap-3 px-4 py-3">
            <Film className="w-5 h-5 text-ios-tertiary-label" />
            <div className="flex-1 min-w-0">
              <p className="text-ios-caption1 text-ios-tertiary-label">Director</p>
              <p className="text-ios-body text-ios-label">
                {directors.map((name, idx) => (
                  <span key={name}>
                    {idx > 0 && ", "}
                    <button
                      type="button"
                      onClick={() => onOpenPerson?.(name, "director")}
                      disabled={!onOpenPerson}
                      className="disabled:cursor-default enabled:text-ios-blue enabled:hover:underline"
                    >
                      {name}
                    </button>
                  </span>
                ))}
              </p>
            </div>
          </div>
        )}

        {cast.length > 0 && (
          <div className="flex items-center gap-3 px-4 py-3">
            <Users className="w-5 h-5 text-ios-tertiary-label" />
            <div className="flex-1 min-w-0">
              <p className="text-ios-caption1 text-ios-tertiary-label">Cast</p>
              <p className="text-ios-body text-ios-label">
                {cast.slice(0, 3).map((name, idx) => (
                  <span key={name}>
                    {idx > 0 && ", "}
                    <button
                      type="button"
                      onClick={() => onOpenPerson?.(name, "actor")}
                      disabled={!onOpenPerson}
                      className="disabled:cursor-default enabled:text-ios-blue enabled:hover:underline"
                    >
                      {name}
                    </button>
                  </span>
                ))}
              </p>
            </div>
          </div>
        )}

        {companies.length > 0 && (
          <div className="flex items-center gap-3 px-4 py-3">
            <Film className="w-5 h-5 text-ios-tertiary-label" />
            <div className="flex-1 min-w-0">
              <p className="text-ios-caption1 text-ios-tertiary-label">Studio</p>
              <p className="text-ios-body text-ios-label">
                {companies.slice(0, 3).map((name, idx) => (
                  <span key={name}>
                    {idx > 0 && ", "}
                    <button
                      type="button"
                      onClick={() => onOpenCompany?.(name)}
                      disabled={!onOpenCompany}
                      className="disabled:cursor-default enabled:text-ios-blue enabled:hover:underline"
                    >
                      {name}
                    </button>
                  </span>
                ))}
              </p>
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
