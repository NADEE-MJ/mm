/**
 * MovieCard component - iOS Style
 * Displays movie card in list view
 */

import { Star, Users, ChevronRight } from "lucide-react";
import { getPoster, formatRating, formatDate } from "../utils/helpers";

export default function MovieCard({ movie, onClick }) {
  const tmdb = movie.tmdbData || {};
  const omdb = movie.omdbData || {};

  const title = omdb.title || tmdb.title || "Unknown";
  const year = omdb.year || tmdb.year || "";
  const poster = getPoster(omdb.poster || tmdb.poster);
  const genres = omdb.genres || tmdb.genres || [];
  const imdbRating = omdb.imdbRating;
  const rtRating = omdb.rtRating;
  const myRating = movie.watchHistory?.myRating;
  const recommenders = movie.recommendations || [];
  const dateAdded =
    recommenders.length > 0
      ? Math.max(...recommenders.map((r) => r.date_recommended || 0)) * 1000
      : null;

  return (
    <button
      onClick={onClick}
      className="ios-card w-full p-3 active:scale-[0.98] transition-all text-left group"
    >
      <div className="flex gap-3">
        {/* Poster */}
        <div className="relative flex-shrink-0">
          <img
            src={poster}
            alt={title}
            className="w-16 h-24 sm:w-20 sm:h-30 object-cover rounded-xl bg-ios-fill"
            loading="lazy"
          />
          {myRating && (
            <div className="absolute -top-1.5 -right-1.5 bg-ios-blue text-white text-xs font-semibold px-1.5 py-0.5 rounded-full flex items-center gap-0.5 shadow-lg">
              <Star className="w-3 h-3 fill-current" />
              {formatRating(myRating)}
            </div>
          )}
        </div>

        {/* Details */}
        <div className="flex-1 min-w-0 flex flex-col py-0.5">
          {/* Title and Year */}
          <h3 className="text-ios-body font-semibold text-ios-label line-clamp-2 leading-tight">
            {title}
            {year && <span className="text-ios-secondary-label font-normal ml-1">({year})</span>}
          </h3>

          {/* Genres */}
          {genres.length > 0 && (
            <div className="flex flex-wrap gap-1 mt-1.5">
              {genres.slice(0, 2).map((genre) => (
                <span
                  key={genre}
                  className="text-ios-caption2 px-2 py-0.5 bg-ios-fill rounded-full text-ios-secondary-label"
                >
                  {genre}
                </span>
              ))}
              {genres.length > 2 && (
                <span className="text-ios-caption2 px-1 text-ios-tertiary-label">
                  +{genres.length - 2}
                </span>
              )}
            </div>
          )}

          {/* Ratings Row */}
          <div className="flex items-center gap-2.5 mt-auto pt-1.5">
            {imdbRating && (
              <span className="text-ios-caption1 text-ios-yellow font-medium">
                IMDb {formatRating(imdbRating)}
              </span>
            )}
            {rtRating && (
              <span className="text-ios-caption1 text-ios-red font-medium">🍅 {rtRating}%</span>
            )}
          </div>

          {/* Recommenders */}
          {recommenders.length > 0 && (
            <div className="flex items-center gap-1.5 mt-1 text-ios-caption1 text-ios-secondary-label">
              <Users className="w-3.5 h-3.5 flex-shrink-0" />
              <span className="truncate">
                {recommenders.length === 1
                  ? recommenders[0].person
                  : `${recommenders[0].person} +${recommenders.length - 1}`}
              </span>
              {dateAdded && (
                <>
                  <span className="text-ios-tertiary-label">•</span>
                  <span className="text-ios-tertiary-label flex-shrink-0">
                    {formatDate(dateAdded)}
                  </span>
                </>
              )}
            </div>
          )}
        </div>

        {/* Chevron */}
        <div className="flex items-center self-center">
          <ChevronRight className="w-5 h-5 text-ios-tertiary-label group-active:text-ios-secondary-label transition-colors" />
        </div>
      </div>
    </button>
  );
}
