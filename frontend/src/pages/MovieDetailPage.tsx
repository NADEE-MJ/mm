import { useState, useMemo } from "react";
import { useParams, useNavigate } from "react-router-dom";
import { ChevronRight } from "lucide-react";
import { useMoviesContext } from "../contexts/MoviesContext";
import { usePeople } from "../hooks/usePeople";
import { MOVIE_STATUS, RATING_THRESHOLD, VOTE_TYPE } from "../utils/constants";
import MovieDetail from "../components/MovieDetail";
import RatingPrompt from "../components/RatingPrompt";
import UpvoteModal from "../components/features/MovieDetail/UpvoteModal";
import DownvoteModal from "../components/features/MovieDetail/DownvoteModal";
import PageTransition from "../components/PageTransition";

export default function MovieDetailPage() {
  const { imdbId } = useParams();
  const navigate = useNavigate();
  const { movies, markWatched, updateStatus, addRecommendation, removeRecommendation } =
    useMoviesContext();
  const { people, getPeopleNames } = usePeople();
  const [ratingPrompt, setRatingPrompt] = useState(null);
  const [showAddUpvote, setShowAddUpvote] = useState(false);
  const [showAddDownvote, setShowAddDownvote] = useState(false);

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
  };

  const handleUpdateStatus = async (imdbId, status) => {
    await updateStatus(imdbId, status);
  };

  const handleAddUpvote = async (person) => {
    try {
      await addRecommendation(movie.imdbId, person, movie.tmdbData, movie.omdbData, VOTE_TYPE.UPVOTE);
      setShowAddUpvote(false);
    } catch (error) {
      console.error("Error adding upvote:", error);
    }
  };

  const handleAddDownvote = async (person) => {
    try {
      await addRecommendation(movie.imdbId, person, movie.tmdbData, movie.omdbData, VOTE_TYPE.DOWNVOTE);
      setShowAddDownvote(false);
    } catch (error) {
      console.error("Error adding downvote:", error);
    }
  };

  if (!movie) {
    return (
      <PageTransition onClose={() => navigate(-1)}>
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
      </PageTransition>
    );
  }

  return (
    <>
      <PageTransition onClose={() => navigate(-1)}>
        <MovieDetail
          movie={movie}
          onClose={() => navigate(-1)}
          onMarkWatched={handleMarkWatched}
          onUpdateStatus={handleUpdateStatus}
          onAddVote={addRecommendation}
          onRemoveVote={removeRecommendation}
          onShowAddUpvote={() => setShowAddUpvote(true)}
          onShowAddDownvote={() => setShowAddDownvote(true)}
          people={people}
          peopleNames={getPeopleNames()}
        />
      </PageTransition>

      {ratingPrompt && (
        <RatingPrompt
          movie={ratingPrompt.movie}
          recommenders={ratingPrompt.recommenders}
          onAction={handleRatingPromptAction}
          onClose={() => setRatingPrompt(null)}
        />
      )}

      {/* Add Upvote Modal */}
      <UpvoteModal
        isOpen={showAddUpvote}
        onClose={() => setShowAddUpvote(false)}
        peopleNames={getPeopleNames()}
        onAdd={handleAddUpvote}
      />

      {/* Add Downvote Modal */}
      <DownvoteModal
        isOpen={showAddDownvote}
        onClose={() => setShowAddDownvote(false)}
        peopleNames={getPeopleNames()}
        onAdd={handleAddDownvote}
      />
    </>
  );
}
