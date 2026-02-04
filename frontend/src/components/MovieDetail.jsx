/**
 * MovieDetail component - iOS Style
 * Shows full movie details with actions
 */

import { useState } from "react";
import {
  X,
  Star,
  Calendar,
  Users,
  Trash2,
  RotateCcw,
  CheckCircle,
  Film,
  ChevronRight,
  ArrowUpRight,
} from "lucide-react";
import { getPoster, formatDate, formatRating } from "../utils/helpers";
import { MOVIE_STATUS } from "../utils/constants";

export default function MovieDetail({ movie, onClose, onMarkWatched, onUpdateStatus }) {
  const [showRating, setShowRating] = useState(false);
  const [rating, setRating] = useState(7.0);

  if (!movie) return null;

  const tmdb = movie.tmdbData || {};
  const omdb = movie.omdbData || {};

  const title = omdb.title || tmdb.title || "Unknown";
  const year = omdb.year || tmdb.year || "";
  const poster = getPoster(omdb.poster || tmdb.poster);
  const plot = omdb.plot || tmdb.plot || "No plot available";
  const genres = omdb.genres || tmdb.genres || [];
  const cast = omdb.actors || tmdb.cast || [];
  const director = omdb.director || "";
  const imdbRating = omdb.imdbRating;
  const rtRating = omdb.rtRating;
  const runtime = omdb.runtime || (tmdb.runtime ? `${tmdb.runtime} min` : null);
  const recommenders = movie.recommendations || [];
  const watchHistory = movie.watchHistory;

  const handleMarkWatched = async () => {
    await onMarkWatched(movie.imdbId, rating);
    setShowRating(false);
  };

  const handleStatusChange = async (newStatus) => {
    await onUpdateStatus(movie.imdbId, newStatus);
  };

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

  // Quick rating buttons for common values
  const quickRatings = [5.0, 6.0, 7.0, 7.5, 8.0, 8.5, 9.0, 9.5, 10.0];

  return (
    <div className="fixed inset-0 bg-ios-bg z-50 overflow-y-auto ios-fade-in">
      <div className="min-h-screen">
        {/* Header with backdrop */}
        <div className="relative">
          {/* Backdrop Image */}
          <div
            className="absolute inset-0 h-72 bg-cover bg-center"
            style={{ backgroundImage: `url(${poster})` }}
          />
          <div className="absolute inset-0 h-72 bg-gradient-to-b from-black/60 via-black/40 to-ios-bg" />

          {/* Close Button */}
          <button
            onClick={onClose}
            className="absolute top-4 right-4 z-10 p-2 bg-ios-fill/80 backdrop-blur-xl rounded-full transition-all active:scale-95 safe-area-top"
          >
            <X className="w-6 h-6 text-white" />
          </button>

          {/* Status Badge */}
          <div className="absolute top-4 left-4 z-10 safe-area-top">
            <span
              className={`inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full text-sm font-medium backdrop-blur-xl ${statusInfo.color}`}
            >
              <StatusIcon className="w-4 h-4" />
              {statusInfo.text}
            </span>
          </div>

          {/* Movie Info Header */}
          <div className="relative pt-36 px-4 pb-4">
            <div className="flex gap-4">
              {/* Poster */}
              <img
                src={poster}
                alt={title}
                className="w-28 h-42 sm:w-36 sm:h-54 object-cover rounded-2xl shadow-2xl flex-shrink-0 -mt-16 ring-1 ring-white/10"
              />

              {/* Basic Info */}
              <div className="flex-1 pt-2">
                <h2 className="text-ios-title1 font-bold leading-tight text-white">{title}</h2>
                <p className="text-ios-secondary-label mt-1">
                  {year}
                  {runtime && ` • ${runtime}`}
                </p>

                {/* Ratings */}
                <div className="flex flex-wrap gap-2 mt-3">
                  {watchHistory && (
                    <div className="flex items-center gap-1 bg-ios-blue/20 text-ios-blue px-2.5 py-1 rounded-lg text-sm font-medium">
                      <Star className="w-4 h-4 fill-current" />
                      <span>{formatRating(watchHistory.myRating)}</span>
                    </div>
                  )}
                  {imdbRating && (
                    <div className="bg-ios-yellow/20 text-ios-yellow px-2.5 py-1 rounded-lg text-sm font-medium">
                      IMDb {formatRating(imdbRating)}
                    </div>
                  )}
                  {rtRating && (
                    <div className="bg-ios-red/20 text-ios-red px-2.5 py-1 rounded-lg text-sm font-medium">
                      🍅 {rtRating}%
                    </div>
                  )}
                </div>
              </div>
            </div>
          </div>
        </div>

        {/* Content */}
        <div className="px-4 pb-32 space-y-6">
          {/* Genres */}
          {genres.length > 0 && (
            <div className="flex flex-wrap gap-2">
              {genres.map((genre) => (
                <span
                  key={genre}
                  className="px-3 py-1.5 bg-ios-secondary-fill rounded-full text-sm text-ios-label"
                >
                  {genre}
                </span>
              ))}
            </div>
          )}

          {/* Plot */}
          <div className="ios-card p-4">
            <h3 className="text-ios-caption1 font-semibold text-ios-secondary-label uppercase tracking-wider mb-2">
              Plot
            </h3>
            <p className="text-ios-body text-ios-label leading-relaxed">{plot}</p>
          </div>

          {/* Info Grid */}
          <div className="ios-list">
            {director && director !== "N/A" && (
              <div className="ios-list-item py-3">
                <span className="text-ios-secondary-label">Director</span>
                <span className="text-ios-label">{director}</span>
              </div>
            )}
            {cast.length > 0 && (
              <div className="ios-list-item py-3">
                <span className="text-ios-secondary-label">Cast</span>
                <span className="text-ios-label text-right flex-1 ml-4 truncate">
                  {cast.slice(0, 4).join(", ")}
                </span>
              </div>
            )}
          </div>

          {/* Recommenders */}
          {recommenders.length > 0 && (
            <div>
              <h3 className="text-ios-caption1 font-semibold text-ios-secondary-label uppercase tracking-wider mb-3">
                Recommended by
              </h3>
              <div className="ios-list">
                {recommenders.map((rec) => (
                  <div key={rec.id || rec.person} className="ios-list-item py-3">
                    <div className="flex items-center gap-3">
                      <div className="w-8 h-8 rounded-full bg-ios-fill flex items-center justify-center">
                        <span className="text-sm font-medium text-ios-secondary-label">
                          {rec.person.charAt(0).toUpperCase()}
                        </span>
                      </div>
                      <span className="text-ios-label font-medium">{rec.person}</span>
                    </div>
                    {rec.date_recommended && (
                      <span className="text-ios-caption1 text-ios-tertiary-label">
                        {formatDate(rec.date_recommended * 1000)}
                      </span>
                    )}
                  </div>
                ))}
              </div>
            </div>
          )}

          {/* Watch History */}
          {watchHistory && (
            <div className="ios-card p-4 bg-ios-green/10 border border-ios-green/20">
              <div className="flex items-center gap-2 text-ios-green mb-2">
                <CheckCircle className="w-5 h-5" />
                <span className="font-medium">Watched</span>
              </div>
              <div className="text-ios-caption1 text-ios-secondary-label flex items-center gap-3">
                <span className="flex items-center gap-1">
                  <Calendar className="w-4 h-4" />
                  {formatDate(watchHistory.dateWatched)}
                </span>
                <span className="flex items-center gap-1 text-ios-blue">
                  <Star className="w-4 h-4" />
                  Rated {formatRating(watchHistory.myRating)}/10
                </span>
              </div>
            </div>
          )}
        </div>

        {/* Fixed Bottom Actions */}
        <div className="fixed bottom-0 left-0 right-0 p-4 bg-ios-bg/95 backdrop-blur-xl border-t border-ios-separator safe-area-bottom">
          {!watchHistory ? (
            !showRating ? (
              <div className="flex gap-3">
                <button
                  onClick={() => setShowRating(true)}
                  className="flex-1 btn-ios-primary py-3.5"
                >
                  <CheckCircle className="w-5 h-5 mr-2" />
                  Mark as Watched
                </button>
                {movie.status !== MOVIE_STATUS.DELETED && (
                  <button
                    onClick={() => handleStatusChange(MOVIE_STATUS.DELETED)}
                    className="p-3.5 bg-ios-red/10 rounded-xl transition-all active:scale-95"
                    title="Delete"
                  >
                    <Trash2 className="w-5 h-5 text-ios-red" />
                  </button>
                )}
              </div>
            ) : (
              <div className="space-y-4">
                {/* Rating Display */}
                <div className="flex items-center justify-between">
                  <span className="text-ios-secondary-label">Your Rating</span>
                  <span className="text-3xl font-bold text-ios-blue">{rating.toFixed(1)}</span>
                </div>

                {/* Quick Rating Buttons */}
                <div className="flex flex-wrap gap-2 justify-center">
                  {quickRatings.map((r) => (
                    <button
                      key={r}
                      onClick={() => setRating(r)}
                      className={`px-3 py-2 rounded-xl text-sm font-medium transition-all ${
                        rating === r
                          ? "bg-ios-blue text-white"
                          : "bg-ios-fill text-ios-label active:bg-ios-secondary-fill"
                      }`}
                    >
                      {r.toFixed(1)}
                    </button>
                  ))}
                </div>

                {/* Fine-tune Slider */}
                <div className="space-y-2">
                  <label className="text-ios-caption2 text-ios-tertiary-label">
                    Fine-tune (0.1 increments)
                  </label>
                  <input
                    type="range"
                    min="1"
                    max="10"
                    step="0.1"
                    value={rating}
                    onChange={(e) => setRating(parseFloat(e.target.value))}
                    className="w-full h-2 bg-ios-fill rounded-lg appearance-none cursor-pointer accent-ios-blue"
                  />
                  <div className="flex justify-between text-ios-caption2 text-ios-tertiary-label">
                    <span>1.0</span>
                    <span>10.0</span>
                  </div>
                </div>

                {/* Action Buttons */}
                <div className="flex gap-3">
                  <button
                    onClick={() => setShowRating(false)}
                    className="flex-1 btn-ios-secondary py-3"
                  >
                    Cancel
                  </button>
                  <button onClick={handleMarkWatched} className="flex-1 btn-ios-primary py-3">
                    Save Rating
                  </button>
                </div>
              </div>
            )
          ) : (
            <div className="flex gap-3">
              {movie.status === MOVIE_STATUS.DELETED ? (
                <button
                  onClick={() => handleStatusChange(MOVIE_STATUS.TO_WATCH)}
                  className="flex-1 btn-ios-primary py-3.5"
                >
                  <RotateCcw className="w-5 h-5 mr-2" />
                  Restore to To Watch
                </button>
              ) : movie.status === MOVIE_STATUS.WATCHED ? (
                <button
                  onClick={() => setShowRating(true)}
                  className="flex-1 btn-ios-secondary py-3.5"
                >
                  <Star className="w-5 h-5 mr-2" />
                  Update Rating
                </button>
              ) : (
                <>
                  <button
                    onClick={() => setShowRating(true)}
                    className="flex-1 btn-ios-primary py-3.5"
                  >
                    <CheckCircle className="w-5 h-5 mr-2" />
                    Mark as Watched
                  </button>
                  <button
                    onClick={() => handleStatusChange(MOVIE_STATUS.DELETED)}
                    className="p-3.5 bg-ios-red/10 rounded-xl transition-all active:scale-95"
                  >
                    <Trash2 className="w-5 h-5 text-ios-red" />
                  </button>
                </>
              )}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
