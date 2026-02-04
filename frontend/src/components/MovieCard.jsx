/**
 * MovieCard component
 * Displays movie card in list view
 */

import { Star, Users } from 'lucide-react';
import { getPoster, formatRating } from '../utils/helpers';

export default function MovieCard({ movie, onClick }) {
  const tmdb = movie.tmdbData || {};
  const omdb = movie.omdbData || {};

  const title = omdb.title || tmdb.title || 'Unknown';
  const year = omdb.year || tmdb.year || '';
  const poster = getPoster(omdb.poster || tmdb.poster);
  const genres = omdb.genres || tmdb.genres || [];
  const imdbRating = omdb.imdbRating;
  const rtRating = omdb.rtRating;
  const myRating = movie.watchHistory?.myRating;
  const recommenders = movie.recommendations || [];

  return (
    <div
      onClick={onClick}
      className="card cursor-pointer hover:bg-gray-700 transition-all transform hover:scale-[1.02]"
    >
      <div className="flex gap-4">
        {/* Poster */}
        <img
          src={poster}
          alt={title}
          className="w-24 h-36 object-cover rounded"
          loading="lazy"
        />

        {/* Details */}
        <div className="flex-1 min-w-0">
          {/* Title and Year */}
          <h3 className="text-lg font-bold text-white truncate">
            {title} {year && <span className="text-gray-400">({year})</span>}
          </h3>

          {/* Genres */}
          {genres.length > 0 && (
            <div className="flex flex-wrap gap-1 mt-1">
              {genres.slice(0, 3).map(genre => (
                <span
                  key={genre}
                  className="text-xs px-2 py-1 bg-gray-700 rounded text-gray-300"
                >
                  {genre}
                </span>
              ))}
            </div>
          )}

          {/* Ratings */}
          <div className="flex flex-wrap gap-3 mt-2 text-sm">
            {myRating && (
              <div className="flex items-center gap-1 text-blue-400">
                <Star className="w-4 h-4 fill-current" />
                <span className="font-medium">{formatRating(myRating)}</span>
              </div>
            )}
            {imdbRating && (
              <div className="text-yellow-400">
                IMDb: {formatRating(imdbRating)}
              </div>
            )}
            {rtRating && (
              <div className="text-red-400">
                RT: {rtRating}%
              </div>
            )}
          </div>

          {/* Recommenders */}
          {recommenders.length > 0 && (
            <div className="flex items-center gap-1 mt-2 text-sm text-gray-400">
              <Users className="w-4 h-4" />
              <span>
                {recommenders.map(r => r.person).join(', ')}
              </span>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
