/**
 * PeopleManager component - iOS Style
 * Manage people/recommenders with detailed stats
 */

import { useState, useMemo } from "react";
import { Users, Star, StarOff, ChevronRight, Film, TrendingUp, Eye, Clock, X } from "lucide-react";
import { usePeople } from "../hooks/usePeople";
import { getPoster, formatRating } from "../utils/helpers";
import { DEFAULT_RECOMMENDERS } from "../utils/constants";

function PersonDetailSheet({ person, onClose, onToggleTrust }) {
  if (!person) return null;

  const stats = [
    {
      label: "Total Movies",
      value: person.totalRecommendations,
      icon: Film,
      color: "text-ios-blue",
    },
    { label: "Watched", value: person.watched, icon: Eye, color: "text-ios-green" },
    { label: "To Watch", value: person.toWatch, icon: Clock, color: "text-ios-orange" },
  ];

  return (
    <div className="fixed inset-0 z-50">
      <div className="ios-sheet-backdrop" onClick={onClose} />
      <div className="ios-sheet ios-slide-up max-h-[90vh]">
        <div className="ios-sheet-handle" />

        {/* Header */}
        <div className="ios-sheet-header">
          <h3 className="ios-sheet-title">{person.name}</h3>
          <button onClick={onClose} className="ios-sheet-close">
            <X className="w-5 h-5" />
          </button>
        </div>

        <div className="ios-sheet-content">
          {/* Trust Status */}
          <div className="ios-card p-4 mb-6">
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-3">
                <div
                  className={`w-12 h-12 rounded-full flex items-center justify-center ${
                    person.is_trusted ? "bg-ios-yellow/20" : "bg-ios-fill"
                  }`}
                >
                  {person.is_trusted ? (
                    <Star className="w-6 h-6 text-ios-yellow fill-current" />
                  ) : (
                    <span className="text-xl font-semibold text-ios-secondary-label">
                      {person.name.charAt(0).toUpperCase()}
                    </span>
                  )}
                </div>
                <div>
                  <p className="text-ios-body font-semibold text-ios-label">{person.name}</p>
                  <p className="text-ios-caption1 text-ios-secondary-label">
                    {person.is_trusted ? "Trusted Recommender" : "Not Trusted"}
                  </p>
                </div>
              </div>
              <button
                onClick={() => onToggleTrust(person)}
                className={`px-4 py-2 rounded-xl text-sm font-medium transition-all active:scale-95 ${
                  person.is_trusted
                    ? "bg-ios-yellow/20 text-ios-yellow"
                    : "bg-ios-fill text-ios-label"
                }`}
              >
                {person.is_trusted ? (
                  <>
                    <Star className="w-4 h-4 inline mr-1 fill-current" />
                    Trusted
                  </>
                ) : (
                  <>
                    <StarOff className="w-4 h-4 inline mr-1" />
                    Mark Trusted
                  </>
                )}
              </button>
            </div>
          </div>

          {/* Stats Grid */}
          <div className="grid grid-cols-3 gap-3 mb-6">
            {stats.map((stat) => (
              <div key={stat.label} className="ios-card p-4 text-center">
                <stat.icon className={`w-6 h-6 mx-auto mb-2 ${stat.color}`} />
                <p className="text-ios-title2 font-bold text-ios-label">{stat.value}</p>
                <p className="text-ios-caption2 text-ios-secondary-label">{stat.label}</p>
              </div>
            ))}
          </div>

          {/* Average Rating */}
          {person.avgRating && (
            <div className="ios-card p-4 mb-6 bg-ios-blue/5 border border-ios-blue/20">
              <div className="flex items-center justify-between">
                <div className="flex items-center gap-3">
                  <TrendingUp className="w-6 h-6 text-ios-blue" />
                  <span className="text-ios-body text-ios-label">Average Rating</span>
                </div>
                <div className="flex items-center gap-1">
                  <Star className="w-5 h-5 text-ios-blue fill-current" />
                  <span className="text-ios-title2 font-bold text-ios-blue">
                    {person.avgRating.toFixed(1)}
                  </span>
                </div>
              </div>
            </div>
          )}

          {/* Movies List */}
          {person.movies.length > 0 && (
            <div>
              <h4 className="text-ios-caption1 font-semibold text-ios-secondary-label uppercase tracking-wider mb-3">
                Movies ({person.movies.length})
              </h4>
              <div className="ios-list max-h-64 overflow-y-auto">
                {person.movies.map((movie) => {
                  const title = movie.omdbData?.title || movie.tmdbData?.title || "Unknown";
                  const year = movie.omdbData?.year || movie.tmdbData?.year;
                  const poster = getPoster(movie.omdbData?.poster || movie.tmdbData?.poster);
                  const rating = movie.watchHistory?.myRating;
                  const isWatched = movie.status === "watched";

                  return (
                    <div key={movie.imdbId} className="ios-list-item py-3">
                      <div className="flex items-center gap-3 flex-1 min-w-0">
                        <img
                          src={poster}
                          alt={title}
                          className="w-10 h-15 object-cover rounded-lg flex-shrink-0"
                        />
                        <div className="flex-1 min-w-0">
                          <p className="text-ios-body text-ios-label font-medium truncate">
                            {title}
                          </p>
                          <p className="text-ios-caption1 text-ios-secondary-label">
                            {year}
                            {isWatched && <span className="ml-2 text-ios-green">• Watched</span>}
                          </p>
                        </div>
                      </div>
                      {rating && (
                        <div className="flex items-center gap-1 text-ios-blue">
                          <Star className="w-4 h-4 fill-current" />
                          <span className="text-ios-caption1 font-semibold">
                            {formatRating(rating)}
                          </span>
                        </div>
                      )}
                    </div>
                  );
                })}
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}

export default function PeopleManager({ movies }) {
  const { people, updateTrust } = usePeople();
  const [filter, setFilter] = useState("all");
  const [selectedPerson, setSelectedPerson] = useState(null);

  // Calculate recommendation stats
  const peopleWithStats = useMemo(() => {
    return people
      .map((person) => {
        const recommendations = movies.filter((movie) =>
          movie.recommendations?.some((rec) => rec.person === person.name),
        );

        const toWatch = recommendations.filter((m) => m.status === "toWatch").length;
        const watched = recommendations.filter((m) => m.status === "watched").length;
        const ratedMovies = recommendations.filter((m) => m.watchHistory?.myRating);
        const avgRating =
          ratedMovies.length > 0
            ? ratedMovies.reduce((acc, m) => acc + m.watchHistory.myRating, 0) / ratedMovies.length
            : null;

        const isDefault = DEFAULT_RECOMMENDERS.some((d) => d.name === person.name);

        return {
          ...person,
          totalRecommendations: recommendations.length,
          toWatch,
          watched,
          avgRating,
          movies: recommendations,
          isDefault,
        };
      })
      .sort((a, b) => b.totalRecommendations - a.totalRecommendations);
  }, [people, movies]);

  const filteredPeople = peopleWithStats.filter((person) => {
    if (filter === "trusted") return person.is_trusted;
    if (filter === "untrusted") return !person.is_trusted;
    if (filter === "quick") return person.isDefault;
    return true;
  });

  const handleToggleTrust = async (person) => {
    try {
      await updateTrust(person.name, !person.is_trusted);
    } catch (err) {
      console.error("Error toggling trust:", err);
    }
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-3">
          <h2 className="text-ios-title1">People</h2>
          <span className="ios-badge">{filteredPeople.length}</span>
        </div>
      </div>

      {/* Filter Segments */}
      <div className="ios-segmented-control">
        {[
          { value: "all", label: "All" },
          { value: "trusted", label: "⭐ Trusted" },
          { value: "quick", label: "Quick" },
        ].map((opt) => (
          <button
            key={opt.value}
            onClick={() => setFilter(opt.value)}
            className={`ios-segment ${filter === opt.value ? "active" : ""}`}
          >
            {opt.label}
          </button>
        ))}
      </div>

      {/* Summary Stats */}
      <div className="grid grid-cols-3 gap-3">
        <div className="ios-card p-4 text-center">
          <p className="text-ios-title2 font-bold text-ios-label">{people.length}</p>
          <p className="text-ios-caption2 text-ios-secondary-label">Total</p>
        </div>
        <div className="ios-card p-4 text-center">
          <p className="text-ios-title2 font-bold text-ios-yellow">
            {people.filter((p) => p.is_trusted).length}
          </p>
          <p className="text-ios-caption2 text-ios-secondary-label">Trusted</p>
        </div>
        <div className="ios-card p-4 text-center">
          <p className="text-ios-title2 font-bold text-ios-blue">
            {movies.reduce((acc, m) => acc + (m.recommendations?.length || 0), 0)}
          </p>
          <p className="text-ios-caption2 text-ios-secondary-label">Recs</p>
        </div>
      </div>

      {/* People List */}
      {filteredPeople.length === 0 ? (
        <div className="ios-card text-center py-16">
          <Users className="w-16 h-16 mx-auto mb-4 text-ios-tertiary-label" />
          <p className="text-ios-headline text-ios-label mb-1">No people found</p>
          <p className="text-ios-caption1 text-ios-secondary-label">
            People who recommend movies will appear here
          </p>
        </div>
      ) : (
        <div className="ios-list">
          {filteredPeople.map((person) => (
            <button
              key={person.name}
              onClick={() => setSelectedPerson(person)}
              className="ios-list-item py-4 w-full text-left"
            >
              <div className="flex items-center gap-3 flex-1 min-w-0">
                {/* Avatar */}
                <div
                  className={`w-12 h-12 rounded-full flex items-center justify-center flex-shrink-0 ${
                    person.is_trusted
                      ? "bg-ios-yellow/20"
                      : person.isDefault
                        ? "bg-ios-purple/20"
                        : "bg-ios-fill"
                  }`}
                >
                  {person.is_trusted ? (
                    <Star className="w-6 h-6 text-ios-yellow fill-current" />
                  ) : person.isDefault ? (
                    <Users className="w-5 h-5 text-ios-purple" />
                  ) : (
                    <span className="text-lg font-semibold text-ios-secondary-label">
                      {person.name.charAt(0).toUpperCase()}
                    </span>
                  )}
                </div>

                {/* Info */}
                <div className="flex-1 min-w-0">
                  <div className="flex items-center gap-2">
                    <h3 className="text-ios-body font-semibold text-ios-label truncate">
                      {person.name}
                    </h3>
                    {person.isDefault && (
                      <span className="text-ios-caption2 text-ios-purple bg-ios-purple/10 px-2 py-0.5 rounded-full">
                        Quick
                      </span>
                    )}
                  </div>
                  <div className="flex items-center gap-3 text-ios-caption1 text-ios-secondary-label mt-0.5">
                    <span>{person.totalRecommendations} movies</span>
                    {person.avgRating && (
                      <>
                        <span className="text-ios-tertiary-label">•</span>
                        <span className="text-ios-blue flex items-center gap-0.5">
                          <Star className="w-3 h-3 fill-current" />
                          {person.avgRating.toFixed(1)} avg
                        </span>
                      </>
                    )}
                  </div>
                </div>
              </div>

              {/* Stats Preview */}
              <div className="flex items-center gap-4">
                <div className="text-right">
                  <p className="text-ios-caption1 text-ios-orange">{person.toWatch} to watch</p>
                  <p className="text-ios-caption1 text-ios-green">{person.watched} watched</p>
                </div>
                <ChevronRight className="w-5 h-5 text-ios-tertiary-label flex-shrink-0" />
              </div>
            </button>
          ))}
        </div>
      )}

      {/* Person Detail Sheet */}
      {selectedPerson && (
        <PersonDetailSheet
          person={selectedPerson}
          onClose={() => setSelectedPerson(null)}
          onToggleTrust={handleToggleTrust}
        />
      )}
    </div>
  );
}
