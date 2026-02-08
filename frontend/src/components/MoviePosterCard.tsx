import { Star, ThumbsUp, ThumbsDown } from "lucide-react";
import { getPoster, formatRating } from "../utils/helpers";
import { VOTE_TYPE } from "../utils/constants";

export default function MoviePosterCard({ movie, onClick }) {
  const tmdb = movie.tmdbData || {};
  const omdb = movie.omdbData || {};

  const title = omdb.title || tmdb.title || "Unknown";
  const year = omdb.year || tmdb.year || "";
  const poster = getPoster(omdb.poster || tmdb.poster);
  const imdbRating = omdb.imdbRating;
  const allVotes = movie.recommendations || [];
  const upvotes = allVotes.filter((vote) => vote.vote_type !== VOTE_TYPE.DOWNVOTE).length;
  const downvotes = allVotes.filter((vote) => vote.vote_type === VOTE_TYPE.DOWNVOTE).length;

  return (
    <button type="button" className="movie-poster-card" onClick={onClick} title={title}>
      <div className="movie-poster-media">
        <img src={poster} alt={title} loading="lazy" />
      </div>
      <div className="movie-poster-meta">
        <h3 className="movie-poster-title" title={title}>
          {title}
        </h3>
        <p className="movie-poster-year">{year || "Unknown Year"}</p>

        <div className="movie-poster-stats">
          <span>
            <Star className="w-3.5 h-3.5" />
            {imdbRating ? formatRating(imdbRating) : "N/A"}
          </span>
          <span>
            <ThumbsUp className="w-3.5 h-3.5" />
            {upvotes}
          </span>
          <span>
            <ThumbsDown className="w-3.5 h-3.5" />
            {downvotes}
          </span>
        </div>
      </div>
    </button>
  );
}
