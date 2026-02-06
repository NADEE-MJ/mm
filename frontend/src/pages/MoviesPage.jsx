import { useState } from "react";
import { MOVIE_STATUS } from "../utils/constants";
import { MovieList } from "../components/ui";

export default function MoviesPage({ movies, onMovieClick, onRefresh }) {
  const [currentTab, setCurrentTab] = useState("toWatch");

  return (
    <div>
      {/* Segmented Control */}
      <div className="ios-segmented-control mb-6">
        <button
          onClick={() => setCurrentTab("toWatch")}
          className={`ios-segment ${currentTab === "toWatch" ? "active" : ""}`}
        >
          To Watch
        </button>
        <button
          onClick={() => setCurrentTab("watched")}
          className={`ios-segment ${currentTab === "watched" ? "active" : ""}`}
        >
          Watched
        </button>
      </div>

      {currentTab === "toWatch" && (
        <MovieList
          status={MOVIE_STATUS.TO_WATCH}
          movies={movies}
          onMovieClick={onMovieClick}
          onRefresh={onRefresh}
        />
      )}
      {currentTab === "watched" && (
        <MovieList
          status={MOVIE_STATUS.WATCHED}
          movies={movies}
          onMovieClick={onMovieClick}
          onRefresh={onRefresh}
        />
      )}
    </div>
  );
}
