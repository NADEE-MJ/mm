import { Star, Film, CheckCircle, Trash2 } from "lucide-react";
import { getPoster, formatRating } from "../../../utils/helpers";
import { MOVIE_STATUS } from "../../../utils/constants";

export default function MovieHeader({ movie, omdb, tmdb }) {
  const title = omdb.title || tmdb.title || "Unknown";
  const year = omdb.year || tmdb.year || "";
  const poster = getPoster(omdb.poster || tmdb.poster);
  const imdbRating = omdb.imdbRating;
  const rtRating = omdb.rtRating;
  const runtime = omdb.runtime || (tmdb.runtime ? `${tmdb.runtime} min` : null);
  const watchHistory = movie.watchHistory;

  const getStatusInfo = () => {
    switch (movie.status) {
      case MOVIE_STATUS.WATCHED:
        return { color: "bg-ios-green/20 text-ios-green", icon: CheckCircle, text: "Watched" };
      case MOVIE_STATUS.DELETED:
        return { color: "bg-ios-red/20 text-ios-red", icon: Trash2, text: "Deleted" };
      default:
        return { color: "bg-ios-blue/20 text-ios-blue", icon: Film, text: "To Watch" };
    }
  };

  const statusInfo = getStatusInfo();
  const StatusIcon = statusInfo.icon;

  return (
    <>
      {/* Backdrop Image */}
      <div className="relative h-48 bg-gradient-to-b from-ios-bg-secondary to-ios-bg overflow-hidden">
        <img
          src={poster}
          alt={title}
          className="w-full h-full object-cover opacity-20 blur-xl scale-110"
        />
      </div>

      {/* Movie Info Header */}
      <div className="relative px-4 -mt-24 pb-4">
        <div className="flex gap-4">
          {/* Poster */}
          <img
            src={poster}
            alt={title}
            className="w-28 h-42 sm:w-32 sm:h-48 object-cover rounded-2xl shadow-2xl flex-shrink-0 border-2 border-ios-bg"
          />

          {/* Basic Info */}
          <div className="flex-1 min-w-0 pt-20">
            <h1 className="text-ios-title2 font-bold text-ios-label leading-tight mb-1">
              {title}
            </h1>
            <p className="text-ios-body text-ios-secondary-label mb-2">
              {year}
              {runtime && ` • ${runtime}`}
            </p>

            {/* Ratings */}
            <div className="flex flex-wrap gap-2 mt-3">
              {watchHistory && (
                <div className="flex items-center gap-1 bg-ios-yellow/20 text-ios-yellow px-2.5 py-1 rounded-lg text-sm font-bold">
                  <Star className="w-4 h-4 fill-current" />
                  <span>{formatRating(watchHistory.myRating)}</span>
                </div>
              )}
              {imdbRating && (
                <div className="bg-ios-yellow/20 text-ios-yellow px-2.5 py-1 rounded-lg text-sm font-medium">
                  IMDb {imdbRating}
                </div>
              )}
              {rtRating && (
                <div className="bg-ios-red/20 text-ios-red px-2.5 py-1 rounded-lg text-sm font-medium">
                  🍅 {rtRating}%
                </div>
              )}
              <div className={`flex items-center gap-1.5 px-2.5 py-1 rounded-lg text-sm font-medium ${statusInfo.color}`}>
                <StatusIcon className="w-4 h-4" />
                {statusInfo.text}
              </div>
            </div>
          </div>
        </div>
      </div>
    </>
  );
}
