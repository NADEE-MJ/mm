import { useState } from "react";
import { Star, Film, CheckCircle, Trash2, Sparkles, Image as ImageIcon, X } from "lucide-react";
import { getPoster, getMoviePosterSource, formatRating } from "../../../utils/helpers";
import { MOVIE_STATUS } from "../../../utils/constants";

function RottenTomatoesBadge({ rating }) {
  const isFresh = rating >= 75;
  const isMixed = rating >= 60 && rating < 75;
  const colorClasses = isFresh || isMixed ? "bg-ios-green/20 text-ios-green" : "bg-ios-red/20 text-ios-red";
  return (
    <div className={`flex items-center gap-1 px-2.5 py-1 rounded-lg text-sm font-medium ${colorClasses}`}>
      {isMixed ? <span aria-hidden="true">🍅</span> : <Sparkles className="w-4 h-4" />}
      <span>{rating}%</span>
    </div>
  );
}

export default function MovieHeader({ movie, omdb, tmdb, onChangePoster }) {
  const [showPosterPicker, setShowPosterPicker] = useState(false);
  const title = omdb.title || tmdb.title || "Unknown";
  const year = omdb.year || tmdb.year || "";
  const poster = getPoster(getMoviePosterSource(movie));
  const posterChoices = [
    { key: "tmdb", label: "TMDB", url: tmdb.poster },
    { key: "omdb", label: "OMDb", url: omdb.poster },
  ].filter((choice) => choice.url);
  const imdbRating = omdb.imdbRating;
  const rtRating = omdb.rtRating;
  const mediaType = movie.mediaType || tmdb.mediaType || "movie";
  const runtime = omdb.runtime || (tmdb.runtime ? `${tmdb.runtime} min` : null);
  const seasons = tmdb.numberOfSeasons;
  const episodes = tmdb.numberOfEpisodes;
  const tvMeta =
    mediaType === "tv" && (seasons || episodes)
      ? `${seasons || "?"} seasons \u00b7 ${episodes || "?"} episodes`
      : null;
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
          <div className="relative flex-shrink-0">
            <img
              src={poster}
              alt={title}
              className="w-28 h-42 sm:w-32 sm:h-48 object-cover rounded-2xl shadow-2xl border-2 border-ios-bg"
            />
            {onChangePoster && posterChoices.length > 1 && (
              <button
                type="button"
                onClick={() => setShowPosterPicker((v) => !v)}
                className="absolute bottom-1 right-1 inline-flex items-center justify-center rounded-full bg-black/70 p-1.5 text-white"
                aria-label="Change poster"
              >
                <ImageIcon className="w-3.5 h-3.5" />
              </button>
            )}
          </div>

          {/* Basic Info */}
          <div className="flex-1 min-w-0 pt-20">
            <h1 className="text-ios-title2 font-bold text-ios-label leading-tight mb-1">
              {title}
            </h1>
            <p className="text-ios-body text-ios-secondary-label mb-2">
              {year}
              {(tvMeta || runtime) && ` • ${tvMeta || runtime}`}
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
              {rtRating != null && <RottenTomatoesBadge rating={rtRating} />}
              <div className={`flex items-center gap-1.5 px-2.5 py-1 rounded-lg text-sm font-medium ${statusInfo.color}`}>
                <StatusIcon className="w-4 h-4" />
                {statusInfo.text}
              </div>
            </div>
          </div>
        </div>

        {showPosterPicker && (
          <div className="ios-card mt-4 p-3 space-y-2">
            <div className="flex items-center justify-between">
              <p className="text-ios-caption1 font-semibold text-ios-secondary-label uppercase tracking-wide">
                Choose Poster
              </p>
              <button type="button" onClick={() => setShowPosterPicker(false)} aria-label="Close">
                <X className="w-4 h-4 text-ios-secondary-label" />
              </button>
            </div>
            <div className="flex gap-3">
              {posterChoices.map((choice) => {
                const isActive = movie.posterOverride
                  ? movie.posterOverride === choice.url
                  : choice.key === "omdb"
                    ? Boolean(omdb.poster)
                    : !omdb.poster;
                return (
                  <button
                    key={choice.key}
                    type="button"
                    onClick={async () => {
                      await onChangePoster(choice.url);
                      setShowPosterPicker(false);
                    }}
                    className={`flex-1 rounded-xl border-2 p-1.5 text-center ${
                      isActive ? "border-ios-blue" : "border-transparent"
                    }`}
                  >
                    <img
                      src={getPoster(choice.url)}
                      alt={choice.label}
                      className="w-full h-32 object-cover rounded-lg mb-1"
                    />
                    <span className="text-ios-caption2 text-ios-secondary-label">{choice.label}</span>
                  </button>
                );
              })}
            </div>
          </div>
        )}
      </div>
    </>
  );
}
