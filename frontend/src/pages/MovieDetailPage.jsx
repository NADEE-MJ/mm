import { useState, useMemo } from "react";
import { useParams, useNavigate } from "react-router-dom";
import { ChevronRight } from "lucide-react";
import { useMovies } from "../hooks/useMovies";
import { usePeople } from "../hooks/usePeople";
import { MOVIE_STATUS, RATING_THRESHOLD } from "../utils/constants";
import MovieDetail from "../components/MovieDetail";
import RatingPrompt from "../components/RatingPrompt";

export default function MovieDetailPage() {
  const { imdbId } = useParams();
  const navigate = useNavigate();
  const { movies, loadMovies, markWatched, updateStatus, addRecommendation } = useMovies();
  const { people, getPeopleNames } = usePeople();
  const [ratingPrompt, setRatingPrompt] = useState(null);

  const movie = useMemo(() => movies.find((m) => m.imdbId === imdbId), [movies, imdbId]);

  const handleMarkWatched = async (imdbId, rating) => {
    await markWatched(imdbId, rating);

    if (rating < RATING_THRESHOLD) {
      const movie = movies.find((m) => m.imdbId === imdbId);
      if (movie && movie.recommendations && movie.recommendations.length > 0) {
        setRatingPrompt({
          movie,
          recommenders: movie.recommendations,
        });
      }
    }

    await loadMovies();
  };

  const handleRatingPromptAction = async (action) => {
    if (!ratingPrompt) return;

    const { movie, recommenders } = ratingPrompt;
    const recommenderNames = recommenders.map((r) => r.person);
    const affectedMovies = movies.filter(
      (m) =>
        m.recommendations?.some((r) => recommenderNames.includes(r.person)) &&
        m.status === MOVIE_STATUS.TO_WATCH &&
        m.imdbId !== movie.imdbId,
    );

    if (action === "delete") {
      for (const affectedMovie of affectedMovies) {
        await updateStatus(affectedMovie.imdbId, MOVIE_STATUS.DELETED);
      }
    }

    setRatingPrompt(null);
    await loadMovies();
  };

  const handleUpdateStatus = async (imdbId, status) => {
    await updateStatus(imdbId, status);
    await loadMovies();
  };

  if (!movie) {
    return (
      <div className="nav-stack-page slide-in-right">
        <div className="nav-stack-blur-backdrop fade-in-backdrop" onClick={() => navigate(-1)} />
        <div className="relative z-50 bg-ios-bg min-h-screen">
          <header className="nav-stack-header">
            <button onClick={() => navigate(-1)} className="nav-stack-back-button">
              <ChevronRight className="w-5 h-5 rotate-180" />
              <span>Back</span>
            </button>
          </header>
          <div className="nav-stack-content">
            <p className="text-ios-secondary-label">Movie not found</p>
          </div>
        </div>
      </div>
    );
  }

  return (
    <>
      <div className="nav-stack-blur-backdrop fade-in-backdrop" onClick={() => navigate(-1)} />
      <div className="nav-stack-page slide-in-right">
        <MovieDetail
          movie={movie}
          onClose={() => navigate(-1)}
          onMarkWatched={handleMarkWatched}
          onUpdateStatus={handleUpdateStatus}
          onAddVote={addRecommendation}
          people={people}
          peopleNames={getPeopleNames()}
        />
      </div>
      {ratingPrompt && (
        <RatingPrompt
          movie={ratingPrompt.movie}
          recommenders={ratingPrompt.recommenders}
          onAction={handleRatingPromptAction}
          onClose={() => setRatingPrompt(null)}
        />
      )}
    </>
  );
}
