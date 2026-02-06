/**
 * PeopleManager Container - iOS Style
 * Manage people/recommenders with detailed stats
 */

import { useState, useMemo } from "react";
import {
  Users,
  Star,
  ChevronRight,
  Plus,
  Search,
  X,
} from "lucide-react";
import { usePeople } from "../../../hooks/usePeople";
import { DEFAULT_RECOMMENDERS, IOS_COLORS } from "../../../utils/constants";

export default function PeopleManagerContainer({ movies, onAddPerson, onPersonSelect }) {
  const { people } = usePeople();
  const [filter, setFilter] = useState("people");
  const [searchQuery, setSearchQuery] = useState("");

  const colorCounts = useMemo(() => {
    return people.reduce((acc, person) => {
      const key = person.color || "default";
      acc[key] = (acc[key] || 0) + 1;
      return acc;
    }, {});
  }, [people]);

  const emojiCounts = useMemo(() => {
    return people.reduce((acc, person) => {
      const key = person.emoji || "none";
      acc[key] = (acc[key] || 0) + 1;
      return acc;
    }, {});
  }, [people]);

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
    if (filter === "quick") return person.isDefault;
    if (filter === "people") return !person.isDefault;
    return true;
  });

  const visiblePeople = filteredPeople.filter((person) => {
    if (!searchQuery.trim()) return true;
    const q = searchQuery.trim().toLowerCase();
    const matchesName = person.name.toLowerCase().includes(q);
    const matchesMeta =
      person.emoji?.toLowerCase().includes(q) ||
      (person.is_trusted && "trusted".includes(q)) ||
      (person.isDefault && "quick".includes(q));
    return matchesName || matchesMeta;
  });

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-3">
          <h2 className="text-ios-title1">Recommenders</h2>
          <span className="ios-badge">{visiblePeople.length}</span>
        </div>
        <button onClick={onAddPerson} className="btn-ios-primary">
          <Plus className="w-5 h-5" />
          <span className="ml-1">Add</span>
        </button>
      </div>

      {/* Filter Segments */}
      <div className="ios-segmented-control">
        {[
          { value: "people", label: "People" },
          { value: "trusted", label: "Trusted" },
          { value: "quick", label: "Quick Recommends" },
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

      <div className="relative">
        <Search className="w-4 h-4 text-ios-tertiary-label absolute left-3 top-1/2 -translate-y-1/2" />
        {searchQuery.trim().length > 0 && (
          <button
            type="button"
            onClick={() => setSearchQuery("")}
            className="absolute right-3 top-1/2 -translate-y-1/2 text-ios-tertiary-label hover:text-ios-secondary-label"
            aria-label="Clear search"
          >
            <X className="w-4 h-4" />
          </button>
        )}
        <input
          type="text"
          className="ios-search pl-10 pr-9"
          placeholder="Search recommenders..."
          value={searchQuery}
          onChange={(event) => setSearchQuery(event.target.value)}
          aria-label="Search recommenders"
          autoComplete="off"
        />
      </div>

      {/* People List */}
      {visiblePeople.length === 0 ? (
        <div className="ios-card text-center py-16">
          <Users className="w-16 h-16 mx-auto mb-4 text-ios-tertiary-label" />
          <p className="text-ios-headline text-ios-label mb-1">No recommenders found</p>
          <p className="text-ios-caption1 text-ios-secondary-label">
            {searchQuery.trim()
              ? "Try a different search query"
              : "People who recommend movies will appear here"}
          </p>
        </div>
      ) : (
        <div className="ios-list">
          {visiblePeople.map((person) => {
            const colorMatchCount = Math.max(0, (colorCounts[person.color || "default"] || 1) - 1);
            const emojiMatchCount = Math.max(0, (emojiCounts[person.emoji || "none"] || 1) - 1);
            return (
              <button
                key={person.name}
                onClick={() => onPersonSelect?.(person)}
                className="ios-list-item py-4 w-full text-left"
              >
                <div className="flex items-center gap-3 flex-1 min-w-0">
                  {/* Avatar */}
                  <div
                    className="w-12 h-12 rounded-full flex items-center justify-center flex-shrink-0 text-lg font-semibold text-white relative"
                    style={{ backgroundColor: person.color || (person.isDefault ? IOS_COLORS.purple : IOS_COLORS.gray) }}
                  >
                    {person.emoji || person.name.charAt(0).toUpperCase()}
                    {person.is_trusted && (
                      <Star className="w-4 h-4 text-ios-yellow fill-current absolute -bottom-1 -right-1" />
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
                    <div className="flex items-center gap-2 text-ios-caption2 text-ios-tertiary-label mt-1">
                      <span>
                        {colorMatchCount === 0
                          ? "Unique color"
                          : `${colorMatchCount} share color`}
                      </span>
                      {person.emoji && (
                        <>
                          <span>•</span>
                          <span>
                            {emojiMatchCount === 0
                              ? "Unique emoji"
                              : `${emojiMatchCount} share emoji`}
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
          );
        })}
        </div>
      )}
    </div>
  );
}
