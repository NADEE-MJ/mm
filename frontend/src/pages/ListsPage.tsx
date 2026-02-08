import { useMemo } from "react";
import { Folder, Trash2 } from "lucide-react";
import { MOVIE_STATUS } from "../utils/constants";
import MoviePosterCard from "../components/MoviePosterCard";

export default function ListsPage({ movies, onMovieClick }) {
  const deletedMovies = useMemo(
    () => movies.filter((movie) => movie.status === MOVIE_STATUS.DELETED),
    [movies],
  );

  return (
    <div className="space-y-6">
      <section className="ios-card p-5">
        <div className="flex items-center gap-3 mb-2">
          <div className="w-10 h-10 rounded-lg bg-ios-red/20 flex items-center justify-center">
            <Trash2 className="w-5 h-5 text-ios-red" />
          </div>
          <div>
            <h3 className="text-ios-headline text-ios-label">Deleted</h3>
            <p className="text-ios-caption1 text-ios-secondary-label">{deletedMovies.length} movies</p>
          </div>
        </div>
        <p className="text-ios-caption1 text-ios-secondary-label">
          Deleted movies stay here so you can restore or review them from the detail panel.
        </p>
      </section>

      {deletedMovies.length > 0 ? (
        <div className="movie-poster-grid">
          {deletedMovies.map((movie) => (
            <MoviePosterCard key={movie.imdbId} movie={movie} onClick={() => onMovieClick(movie)} />
          ))}
        </div>
      ) : (
        <div className="movie-empty-state">
          <Folder className="w-14 h-14" />
          <h3>No deleted movies</h3>
          <p>Movies marked as deleted will appear here.</p>
        </div>
      )}
    </div>
  );
}
