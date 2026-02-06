import { useNavigate } from "react-router-dom";
import { ChevronRight } from "lucide-react";
import { MOVIE_STATUS } from "../utils/constants";
import { MovieList } from "../components/ui";

export default function DeletedListPage({ movies, onMovieClick, onRefresh }) {
  const navigate = useNavigate();

  return (
    <>
      <div className="nav-stack-blur-backdrop fade-in-backdrop" onClick={() => navigate("/lists")} />
      <div className="nav-stack-page slide-in-right">
        <div className="bg-ios-bg min-h-screen">
          <header className="nav-stack-header">
            <button
              onClick={() => navigate("/lists")}
              className="nav-stack-back-button"
            >
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
      </div>
    </>
  );
}
