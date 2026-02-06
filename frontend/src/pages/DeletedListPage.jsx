import { useNavigate } from "react-router-dom";
import { ChevronRight } from "lucide-react";
import { MOVIE_STATUS } from "../utils/constants";
import { MovieList } from "../components/ui";
import PageTransition from "../components/PageTransition";

export default function DeletedListPage({ movies, onMovieClick, onRefresh }) {
  const navigate = useNavigate();

  return (
    <PageTransition onClose={() => navigate("/lists")}>
      <div className="bg-ios-bg min-h-screen">
        <header className="nav-stack-header">
          <button onClick={() => navigate("/lists")} className="nav-stack-back-button">
            <ChevronRight className="w-5 h-5 rotate-180" />
            <span>Lists</span>
          </button>
        </header>
        <div className="nav-stack-content">
          <MovieList
            status={MOVIE_STATUS.DELETED}
            movies={movies}
            onMovieClick={onMovieClick}
            onRefresh={onRefresh}
          />
        </div>
      </div>
    </PageTransition>
  );
}
