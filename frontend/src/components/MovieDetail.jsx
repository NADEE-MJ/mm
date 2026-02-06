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
  ThumbsUp,
  ThumbsDown,
  Plus,
} from "lucide-react";
import { getPoster, formatDate, formatRating } from "../utils/helpers";
import { MOVIE_STATUS, VOTE_TYPE } from "../utils/constants";

export default function MovieDetail({ movie, onClose, onMarkWatched, onUpdateStatus, onAddVote, people = [], peopleNames = [] }) {
  const [showRating, setShowRating] = useState(false);
  const [rating, setRating] = useState(7.0);
  const [showAddDownvote, setShowAddDownvote] = useState(false);
  const [downvotePersonQuery, setDownvotePersonQuery] = useState("");
  const [selectedDownvotePerson, setSelectedDownvotePerson] = useState(null);

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
  const allVotes = movie.recommendations || [];
  const upvotes = allVotes.filter(v => v.vote_type !== VOTE_TYPE.DOWNVOTE);
  const downvotes = allVotes.filter(v => v.vote_type === VOTE_TYPE.DOWNVOTE);
  const watchHistory = movie.watchHistory;

  // Filter people for downvote selection
  const availablePeople = peopleNames.filter(name =>
    name.toLowerCase().includes(downvotePersonQuery.toLowerCase())
  ).slice(0, 10);

  const handleMarkWatched = async () => {
    await onMarkWatched(movie.imdbId, rating);
    setShowRating(false);
  };

  const handleStatusChange = async (newStatus) => {
    await onUpdateStatus(movie.imdbId, newStatus);
  };

  const handleAddDownvote = async () => {
    if (!selectedDownvotePerson && !downvotePersonQuery.trim()) return;

    const person = selectedDownvotePerson || downvotePersonQuery.trim();
    try {
      await onAddVote(movie.imdbId, person, movie.tmdbData, movie.omdbData, VOTE_TYPE.DOWNVOTE);
      setShowAddDownvote(false);
      setDownvotePersonQuery("");
      setSelectedDownvotePerson(null);
    } catch (error) {
      console.error("Error adding downvote:", error);
    }
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
    <div className="bg-ios-bg min-h-screen">
      {/* Header with back button */}
      <header className="nav-stack-header">
        <button onClick={onClose} className="nav-stack-back-button">
          <ChevronRight className="w-5 h-5 rotate-180" />
          <span>Back</span>
        </button>
        <div className="flex-1" />
        <span className={`inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full text-sm font-medium ${statusInfo.color}`}>
          <StatusIcon className="w-4 h-4" />
          {statusInfo.text}
        </span>
      </header>

      {/* Movie Content */}
      <div className="relative">
        {/* Backdrop Image */}
        <div
          className="absolute inset-0 h-64 bg-cover bg-center"
          style={{ backgroundImage: `url(${poster})` }}
        />
        <div className="absolute inset-0 h-64 bg-gradient-to-b from-black/60 via-black/40 to-ios-bg" />

        {/* Movie Info Header */}
        <div className="relative pt-20 px-4 pb-4">
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
          {/* Votes Section */}
          {allVotes.length > 0 && (
            <div>
              <div className="flex items-center justify-between mb-3">
                <h3 className="text-ios-caption1 font-semibold text-ios-secondary-label uppercase tracking-wider">
                  Votes
                </h3>
                <button
                  onClick={() => setShowAddDownvote(true)}
                  className="text-ios-blue text-sm font-medium flex items-center gap-1"
                >
                  <ThumbsDown className="w-4 h-4" />
                  Add Downvote
                </button>
              </div>

              {/* Upvotes */}
              {upvotes.length > 0 && (
                <div className="mb-4">
                  <div className="flex items-center gap-2 mb-2">
                    <ThumbsUp className="w-4 h-4 text-ios-green" />
                    <span className="text-ios-caption1 text-ios-green font-medium">
                      Upvotes ({upvotes.length})
                    </span>
                  </div>
                  <div className="ios-list">
                    {upvotes.map((vote) => (
                      <div key={vote.id || vote.person} className="ios-list-item py-3">
                        <div className="flex items-center gap-3">
                          <div className="w-8 h-8 rounded-full bg-ios-green/20 flex items-center justify-center">
                            <span className="text-sm font-medium text-ios-green">
                              {vote.person.charAt(0).toUpperCase()}
                            </span>
                          </div>
                          <span className="text-ios-label font-medium">{vote.person}</span>
                        </div>
                        {vote.date_recommended && (
                          <span className="text-ios-caption1 text-ios-tertiary-label">
                            {formatDate(vote.date_recommended * 1000)}
                          </span>
                        )}
                      </div>
                    ))}
                  </div>
                </div>
              )}

              {/* Downvotes */}
              {downvotes.length > 0 && (
                <div>
                  <div className="flex items-center gap-2 mb-2">
                    <ThumbsDown className="w-4 h-4 text-ios-red" />
                    <span className="text-ios-caption1 text-ios-red font-medium">
                      Downvotes ({downvotes.length})
                    </span>
                  </div>
                  <div className="ios-list">
                    {downvotes.map((vote) => (
                      <div key={vote.id || vote.person} className="ios-list-item py-3">
                        <div className="flex items-center gap-3">
                          <div className="w-8 h-8 rounded-full bg-ios-red/20 flex items-center justify-center">
                            <span className="text-sm font-medium text-ios-red">
                              {vote.person.charAt(0).toUpperCase()}
                            </span>
                          </div>
                          <span className="text-ios-label font-medium">{vote.person}</span>
                        </div>
                        {vote.date_recommended && (
                          <span className="text-ios-caption1 text-ios-tertiary-label">
                            {formatDate(vote.date_recommended * 1000)}
                          </span>
                        )}
                      </div>
                    ))}
                  </div>
                </div>
              )}
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

        {/* Bottom Actions */}
        <div className="sticky bottom-0 left-0 right-0 px-4 py-4 mt-6 bg-ios-bg/95 backdrop-blur-xl border-t border-ios-separator">
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

      {/* Add Downvote Modal */}
      {showAddDownvote && (
        <div className="fixed inset-0 z-50">
          <div className="ios-sheet-backdrop" onClick={() => setShowAddDownvote(false)} />
          <div className="ios-sheet ios-slide-up">
            <div className="ios-sheet-handle" />
            <div className="ios-sheet-header">
              <h3 className="ios-sheet-title">Add Downvote</h3>
              <button onClick={() => setShowAddDownvote(false)} className="ios-sheet-close">
                <X className="w-5 h-5" />
              </button>
            </div>
            <div className="ios-sheet-content">
              <p className="text-ios-secondary-label text-sm mb-4">
                Who doesn't recommend this movie?
              </p>
              <input
                type="text"
                placeholder="Type or select a person..."
                value={downvotePersonQuery}
                onChange={(e) => {
                  setDownvotePersonQuery(e.target.value);
                  setSelectedDownvotePerson(null);
                }}
                className="ios-input mb-3"
                autoFocus
              />

              {availablePeople.length > 0 && (
                <div className="ios-list mb-4">
                  {availablePeople.map((name) => (
                    <button
                      key={name}
                      onClick={() => {
                        setSelectedDownvotePerson(name);
                        setDownvotePersonQuery(name);
                      }}
                      className={`ios-list-item ${selectedDownvotePerson === name ? 'bg-ios-fill' : ''}`}
                    >
                      <span>{name}</span>
                    </button>
                  ))}
                </div>
              )}

              <button
                onClick={handleAddDownvote}
                disabled={!downvotePersonQuery.trim()}
                className="btn-ios-primary w-full disabled:opacity-50"
              >
                <ThumbsDown className="w-5 h-5 mr-2" />
                Add Downvote
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
