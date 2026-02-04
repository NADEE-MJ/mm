/**
 * MovieDetail component
 * Shows full movie details with actions
 */

import { useState } from 'react';
import { X, Star, Calendar, Users, Trash2 } from 'lucide-react';
import { getPoster, formatDate, formatRating } from '../utils/helpers';
import { MOVIE_STATUS } from '../utils/constants';

export default function MovieDetail({ movie, onClose, onMarkWatched, onUpdateStatus }) {
  const [showRating, setShowRating] = useState(false);
  const [rating, setRating] = useState(5.0);

  if (!movie) return null;

  const tmdb = movie.tmdbData || {};
  const omdb = movie.omdbData || {};

  const title = omdb.title || tmdb.title || 'Unknown';
  const year = omdb.year || tmdb.year || '';
  const poster = getPoster(omdb.poster || tmdb.poster);
  const plot = omdb.plot || tmdb.plot || 'No plot available';
  const genres = omdb.genres || tmdb.genres || [];
  const cast = omdb.actors || tmdb.cast || [];
  const director = omdb.director || '';
  const imdbRating = omdb.imdbRating;
  const rtRating = omdb.rtRating;
  const runtime = omdb.runtime || tmdb.runtime;
  const recommenders = movie.recommendations || [];
  const watchHistory = movie.watchHistory;

  const handleMarkWatched = async () => {
    await onMarkWatched(movie.imdbId, rating);
    setShowRating(false);
  };

  const handleStatusChange = async (newStatus) => {
    await onUpdateStatus(movie.imdbId, newStatus);
  };

  return (
    <div className="fixed inset-0 bg-black bg-opacity-75 z-50 overflow-y-auto">
      <div className="min-h-screen px-4 py-8">
        <div className="max-w-4xl mx-auto bg-gray-800 rounded-lg shadow-xl">
          {/* Header */}
          <div className="flex justify-between items-start p-6 border-b border-gray-700">
            <div>
              <h2 className="text-3xl font-bold">{title}</h2>
              <p className="text-gray-400 mt-1">
                {year} {runtime && `• ${runtime}`}
              </p>
            </div>
            <button
              onClick={onClose}
              className="text-gray-400 hover:text-white"
            >
              <X className="w-6 h-6" />
            </button>
          </div>

          {/* Content */}
          <div className="p-6">
            <div className="flex flex-col md:flex-row gap-6">
              {/* Poster */}
              <img
                src={poster}
                alt={title}
                className="w-full md:w-64 rounded-lg"
              />

              {/* Details */}
              <div className="flex-1">
                {/* Genres */}
                {genres.length > 0 && (
                  <div className="flex flex-wrap gap-2 mb-4">
                    {genres.map(genre => (
                      <span
                        key={genre}
                        className="px-3 py-1 bg-gray-700 rounded-full text-sm"
                      >
                        {genre}
                      </span>
                    ))}
                  </div>
                )}

                {/* Ratings */}
                <div className="space-y-2 mb-6">
                  {watchHistory && (
                    <div className="flex items-center gap-2">
                      <Star className="w-5 h-5 text-blue-400 fill-current" />
                      <span className="text-lg font-medium">
                        My Rating: {formatRating(watchHistory.myRating)}
                      </span>
                    </div>
                  )}
                  {imdbRating && (
                    <div className="text-yellow-400">
                      IMDb: {formatRating(imdbRating)}/10
                    </div>
                  )}
                  {rtRating && (
                    <div className="text-red-400">
                      Rotten Tomatoes: {rtRating}%
                    </div>
                  )}
                </div>

                {/* Plot */}
                <div className="mb-6">
                  <h3 className="text-xl font-bold mb-2">Plot</h3>
                  <p className="text-gray-300">{plot}</p>
                </div>

                {/* Director */}
                {director && (
                  <div className="mb-4">
                    <span className="font-medium">Director:</span> {director}
                  </div>
                )}

                {/* Cast */}
                {cast.length > 0 && (
                  <div className="mb-6">
                    <h3 className="text-xl font-bold mb-2">Cast</h3>
                    <p className="text-gray-300">{cast.slice(0, 5).join(', ')}</p>
                  </div>
                )}

                {/* Recommenders */}
                {recommenders.length > 0 && (
                  <div className="mb-6">
                    <h3 className="text-xl font-bold mb-2">Recommended by</h3>
                    <div className="space-y-2">
                      {recommenders.map(rec => (
                        <div key={rec.person} className="flex items-center gap-2">
                          <Users className="w-4 h-4 text-gray-400" />
                          <span>{rec.person}</span>
                          <span className="text-sm text-gray-400">
                            ({formatDate(rec.date_recommended * 1000)})
                          </span>
                        </div>
                      ))}
                    </div>
                  </div>
                )}

                {/* Watch History */}
                {watchHistory && (
                  <div className="mb-6">
                    <div className="flex items-center gap-2 text-gray-400">
                      <Calendar className="w-4 h-4" />
                      <span>Watched on {formatDate(watchHistory.dateWatched)}</span>
                    </div>
                  </div>
                )}
              </div>
            </div>

            {/* Actions */}
            <div className="mt-6 pt-6 border-t border-gray-700">
              {!watchHistory ? (
                <div>
                  {!showRating ? (
                    <button
                      onClick={() => setShowRating(true)}
                      className="btn-primary"
                    >
                      Mark as Watched
                    </button>
                  ) : (
                    <div className="space-y-4">
                      <div>
                        <label className="block text-sm font-medium mb-2">
                          Your Rating (1-10)
                        </label>
                        <input
                          type="range"
                          min="1"
                          max="10"
                          step="0.5"
                          value={rating}
                          onChange={(e) => setRating(parseFloat(e.target.value))}
                          className="w-full"
                        />
                        <div className="text-center text-2xl font-bold mt-2">
                          {formatRating(rating)}
                        </div>
                      </div>
                      <div className="flex gap-2">
                        <button onClick={handleMarkWatched} className="btn-primary">
                          Save
                        </button>
                        <button
                          onClick={() => setShowRating(false)}
                          className="btn-secondary"
                        >
                          Cancel
                        </button>
                      </div>
                    </div>
                  )}
                </div>
              ) : (
                <div className="space-y-4">
                  <div className="text-sm text-gray-400">
                    Status: {movie.status}
                  </div>
                  {movie.status !== MOVIE_STATUS.QUESTIONABLE && (
                    <button
                      onClick={() => handleStatusChange(MOVIE_STATUS.QUESTIONABLE)}
                      className="btn-secondary"
                    >
                      Move to Questionable
                    </button>
                  )}
                  {movie.status !== MOVIE_STATUS.DELETED && (
                    <button
                      onClick={() => handleStatusChange(MOVIE_STATUS.DELETED)}
                      className="btn-secondary flex items-center gap-2"
                    >
                      <Trash2 className="w-4 h-4" />
                      Delete
                    </button>
                  )}
                </div>
              )}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
