import { X, Plus, Check } from "lucide-react";
import { getPoster } from "../../../utils/helpers";

export default function RecommenderStep({
  movieData,
  selectedRecommenders,
  toggleRecommender,
  allRecommenders,
  showRecommenderInput,
  setShowRecommenderInput,
  customRecommender,
  setCustomRecommender,
  addCustomRecommender,
  customInputRef,
}) {
  return (
    <div className="space-y-6">
      {/* Selected Movie Preview */}
      <div className="ios-card p-4">
        <div className="flex gap-4">
          <img
            src={getPoster(movieData.poster)}
            alt={movieData.title}
            className="w-20 h-30 object-cover rounded-xl flex-shrink-0"
          />
          <div className="flex-1 min-w-0">
            <h3 className="text-ios-title3 font-bold text-ios-label">{movieData.title}</h3>
            <p className="text-ios-caption1 text-ios-secondary-label">
              {movieData.year}
              {movieData.runtime && ` • ${movieData.runtime}`}
            </p>
            {movieData.genres && movieData.genres.length > 0 && (
              <div className="flex flex-wrap gap-1 mt-2">
                {movieData.genres.slice(0, 3).map((genre) => (
                  <span
                    key={genre}
                    className="text-ios-caption2 px-2 py-0.5 bg-ios-fill rounded-full text-ios-secondary-label"
                  >
                    {genre}
                  </span>
                ))}
              </div>
            )}
            <div className="flex gap-3 mt-2">
              {movieData.imdbRating && (
                <span className="text-ios-caption1 text-ios-yellow font-medium">
                  IMDb {movieData.imdbRating}
                </span>
              )}
              {movieData.rtRating && (
                <span className="text-ios-caption1 text-ios-red font-medium">
                  RT {movieData.rtRating}%
                </span>
              )}
            </div>
          </div>
        </div>
      </div>

      {/* Recommender Selection */}
      <div>
        <h3 className="text-ios-caption1 font-semibold text-ios-secondary-label uppercase tracking-wider mb-3">
          Who Recommended This?
        </h3>
        <p className="text-ios-caption1 text-ios-tertiary-label mb-4">
          Select one or more recommenders. You can add multiple people.
        </p>

        {/* Selected Recommenders */}
        {selectedRecommenders.length > 0 && (
          <div className="flex flex-wrap gap-2 mb-4">
            {selectedRecommenders.map((name) => (
              <button
                key={name}
                onClick={() => toggleRecommender(name)}
                className="flex items-center gap-1.5 px-3 py-1.5 bg-ios-yellow text-black rounded-full text-sm font-bold transition-all active:scale-95"
              >
                {name}
                <X className="w-4 h-4" />
              </button>
            ))}
          </div>
        )}

        {/* Recommender Options */}
        <div className="ios-list">
          {allRecommenders.map((option) => {
            const isSelected = selectedRecommenders.includes(option.name);
            const avatarBg = option.color || "#f2f2f7";
            const displayEmoji = option.emoji || option.name?.charAt(0)?.toUpperCase() || "?";
            return (
              <button
                key={option.name}
                onClick={() => toggleRecommender(option.name)}
                className={`ios-list-item py-3 w-full text-left ${isSelected ? "bg-ios-blue/5" : ""}`}
              >
                <div className="flex items-center gap-3">
                  <div
                    className="w-10 h-10 rounded-full flex items-center justify-center text-base font-semibold text-white"
                    style={{ backgroundColor: avatarBg }}
                  >
                    {displayEmoji}
                  </div>
                  <span className="text-ios-label">{option.name}</span>
                  {option.isDefault && (
                    <span className="text-ios-caption2 text-ios-purple bg-ios-purple/10 px-2 py-0.5 rounded-full">
                      Quick
                    </span>
                  )}
                </div>
                {isSelected && <Check className="w-5 h-5 text-ios-blue" />}
              </button>
            );
          })}

          {/* Add Custom Recommender */}
          {!showRecommenderInput ? (
            <button
              onClick={() => setShowRecommenderInput(true)}
              className="ios-list-item py-3 w-full text-left"
            >
              <div className="flex items-center gap-3">
                <div className="w-8 h-8 rounded-full bg-ios-green/20 flex items-center justify-center">
                  <Plus className="w-4 h-4 text-ios-green" />
                </div>
                <span className="text-ios-blue">Add New Person</span>
              </div>
            </button>
          ) : (
            <div className="p-4 bg-ios-secondary-fill border-t border-ios-separator">
              <div className="flex gap-2">
                <input
                  ref={customInputRef}
                  type="text"
                  value={customRecommender}
                  onChange={(e) => setCustomRecommender(e.target.value)}
                  onKeyDown={(e) => e.key === "Enter" && addCustomRecommender()}
                  placeholder="Enter name..."
                  className="ios-input flex-1"
                  autoComplete="off"
                />
                <button
                  onClick={addCustomRecommender}
                  disabled={!customRecommender.trim()}
                  className="btn-ios-primary px-4 disabled:opacity-50"
                >
                  Add
                </button>
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
