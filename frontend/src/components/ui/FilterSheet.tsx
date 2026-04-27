import { CheckCircle } from "lucide-react";
import {
  MOVIE_SORT_LABELS,
  getDefaultSortForStatus,
  getSortOptionsForStatus,
} from "../../utils/movies";
import Modal from "./Modal";

export default function FilterSheet({
  isOpen,
  onClose,
  sortBy,
  setSortBy,
  mediaTypeFilter,
  setMediaTypeFilter,
  filterRecommender,
  setFilterRecommender,
  filterGenre,
  setFilterGenre,
  filterDecade,
  setFilterDecade,
  recommenders,
  genres,
  decades,
  status,
}) {
  const sortOptions = getSortOptionsForStatus(status);

  return (
    <Modal isOpen={isOpen} onClose={onClose} title="Sort & Filter" maxWidth="640px">
      <div className="space-y-6">
        {/* Sort */}
        <div>
          <label className="text-ios-label text-sm mb-3 block">Sort By</label>
          <div className="ios-list">
            {sortOptions.map((option) => (
              <button
                key={option}
                onClick={() => setSortBy(option)}
                className={`ios-list-item ${sortBy === option ? "active" : ""}`}
              >
                <span>{MOVIE_SORT_LABELS[option]}</span>
                {sortBy === option && <CheckCircle className="w-5 h-5 text-ios-blue" />}
              </button>
            ))}
          </div>
        </div>

        {/* Recommender Filter */}
        <div>
          <label className="text-ios-label text-sm mb-3 block">Type</label>
          <div className="flex flex-wrap gap-2">
            <button
              onClick={() => setMediaTypeFilter("all")}
              className={`ios-pill ${mediaTypeFilter === "all" ? "active" : ""}`}
            >
              All
            </button>
            <button
              onClick={() => setMediaTypeFilter("movie")}
              className={`ios-pill ${mediaTypeFilter === "movie" ? "active" : ""}`}
            >
              Movies
            </button>
            <button
              onClick={() => setMediaTypeFilter("tv")}
              className={`ios-pill ${mediaTypeFilter === "tv" ? "active" : ""}`}
            >
              TV
            </button>
          </div>
        </div>

        {/* Recommender Filter */}
        {recommenders.length > 0 && (
          <div>
            <label className="text-ios-label text-sm mb-3 block">Recommender</label>
            <select
              value={filterRecommender}
              onChange={(e) => setFilterRecommender(e.target.value)}
              className="ios-input app-select"
            >
              <option value="">All Recommenders</option>
              {recommenders.map((name) => (
                <option key={name} value={name}>
                  {name}
                </option>
              ))}
            </select>
          </div>
        )}

        {/* Genre Filter */}
        {genres.length > 0 && (
          <div>
            <label className="text-ios-label text-sm mb-3 block">Genre</label>
            <div className="flex flex-wrap gap-2">
              <button
                onClick={() => setFilterGenre("")}
                className={`ios-pill ${!filterGenre ? "active" : ""}`}
              >
                All
              </button>
              {genres.slice(0, 12).map((genre) => (
                <button
                  key={genre}
                  onClick={() => setFilterGenre(genre)}
                  className={`ios-pill ${filterGenre === genre ? "active" : ""}`}
                >
                  {genre}
                </button>
              ))}
            </div>
          </div>
        )}

        {/* Decade Filter */}
        {decades.length > 0 && (
          <div>
            <label className="text-ios-label text-sm mb-3 block">Decade</label>
            <div className="flex flex-wrap gap-2">
              <button
                onClick={() => setFilterDecade("")}
                className={`ios-pill ${!filterDecade ? "active" : ""}`}
              >
                All
              </button>
              {decades.map((decade) => (
                <button
                  key={decade}
                  onClick={() => setFilterDecade(decade)}
                  className={`ios-pill ${filterDecade === decade ? "active" : ""}`}
                >
                  {decade}s
                </button>
              ))}
            </div>
          </div>
        )}

        {/* Clear Filters */}
        <button
          onClick={() => {
            setSortBy(getDefaultSortForStatus(status));
            setMediaTypeFilter("all");
            setFilterRecommender("");
            setFilterGenre("");
            setFilterDecade("");
          }}
          className="btn-ios-secondary w-full"
        >
          Clear All Filters
        </button>
      </div>
    </Modal>
  );
}
