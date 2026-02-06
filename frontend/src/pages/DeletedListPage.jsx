import { useNavigate } from "react-router-dom";
import { ChevronRight } from "lucide-react";
import { MOVIE_STATUS } from "../utils/constants";
import { MovieList } from "../components/ui";

export default function DeletedListPage({ movies, onMovieClick, onRefresh }) {
  const navigate = useNavigate();

  return (
    <div>
      <button
        onClick={() => navigate("/lists")}
        className="flex items-center gap-1 text-ios-blue mb-4"
      >
        <ChevronRight className="w-5 h-5 rotate-180" />
        <span>Lists</span>
      </button>
      <MovieList
        status={MOVIE_STATUS.DELETED}
        movies={movies}
        onMovieClick={onMovieClick}
        onRefresh={onRefresh}
      />
    </div>
  );
}
