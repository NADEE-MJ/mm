import { useEffect, useState } from "react";
import { Film, Star, ThumbsUp, ThumbsDown } from "lucide-react";
import { getPoster, formatRating } from "../utils/helpers";
import { POSTER_PLACEHOLDER, VOTE_TYPE } from "../utils/constants";

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
  const [posterSrc, setPosterSrc] = useState(poster);

  useEffect(() => {
    setPosterSrc(poster);
  }, [poster]);

  const handlePosterError = () => {
    if (posterSrc !== POSTER_PLACEHOLDER) {
      setPosterSrc(POSTER_PLACEHOLDER);
      return;
    }
    setPosterSrc("");
  };

  return (
    <button
      type="button"
      className="flex w-full flex-col overflow-hidden rounded-[14px] border border-[var(--color-ios-separator)] bg-[rgba(28,28,28,0.94)] text-left transition-[transform,box-shadow] duration-200 hover:scale-[1.02] hover:-translate-y-0.5 hover:shadow-[0_14px_26px_rgba(0,0,0,0.42)]"
      onClick={onClick}
      title={title}
    >
      <div className="relative flex aspect-[2/3] items-center justify-center bg-[linear-gradient(180deg,#1a1a1a,#101010)]">
        {movie.mediaType === "tv" && (
          <span className="absolute left-2 top-2 z-[1] rounded-md bg-[rgba(10,132,255,0.92)] px-1.5 py-0.5 text-[0.62rem] font-bold uppercase tracking-[0.05em] text-white">
            TV
          </span>
        )}
        {posterSrc ? (
          <img
            src={posterSrc}
            alt={title}
            loading="lazy"
            onError={handlePosterError}
            className="block h-full w-full object-cover"
          />
        ) : (
          <div
            className="flex h-full w-full flex-col items-center justify-center gap-2 bg-[linear-gradient(180deg,#202020,#111111)] text-[rgba(255,255,255,0.62)]"
            aria-hidden="true"
          >
            <Film className="w-8 h-8" />
            <span className="text-[0.7rem] font-bold uppercase tracking-[0.08em]">No Poster</span>
          </div>
        )}
      </div>
      <div className="flex min-h-[106px] flex-col bg-[#f9f9f9] px-2.5 py-2.5 text-[#161616]">
        <h3
          className="m-0 min-h-[2.1em] overflow-hidden text-[0.87rem] font-bold leading-[1.2] [display:-webkit-box] [-webkit-box-orient:vertical] [-webkit-line-clamp:2]"
          title={title}
        >
          {title}
        </h3>
        <p className="mt-0.5 text-[0.78rem] text-[#555555]">{year || "Unknown Year"}</p>

        <div className="mt-auto flex flex-wrap gap-2 text-[0.72rem] font-bold text-[#333333]">
          <span className="inline-flex items-center gap-1">
            <Star className="w-3.5 h-3.5" />
            {imdbRating ? formatRating(imdbRating) : "N/A"}
          </span>
          <span className="inline-flex items-center gap-1">
            <ThumbsUp className="w-3.5 h-3.5" />
            {upvotes}
          </span>
          <span className="inline-flex items-center gap-1">
            <ThumbsDown className="w-3.5 h-3.5" />
            {downvotes}
          </span>
        </div>
      </div>
    </button>
  );
}
