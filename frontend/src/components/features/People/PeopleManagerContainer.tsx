/**
 * PeopleManager Container - iOS Style
 * Manage people/recommenders with detailed stats
 */

import { useState, useMemo } from "react";
import {
  Users,
  Film,
  Eye,
  Clock,
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
          className="ios-search input-with-leading-icon input-with-trailing-control"
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
        <div className="grid gap-3 [grid-template-columns:repeat(auto-fill,minmax(min(100%,280px),1fr))]">
          {visiblePeople.map((person) => {
            const colorMatchCount = Math.max(0, (colorCounts[person.color || "default"] || 1) - 1);
            const emojiMatchCount = Math.max(0, (emojiCounts[person.emoji || "none"] || 1) - 1);
            return (
              <button
                key={person.name}
                onClick={() => onPersonSelect?.(person)}
                className="flex min-h-[168px] flex-col gap-3 rounded-[14px] border border-[var(--color-ios-separator)] bg-[linear-gradient(180deg,rgba(28,28,28,0.94),rgba(18,18,18,0.98))] p-3 text-left transition-[transform,box-shadow,border-color] duration-200 hover:-translate-y-0.5 hover:border-[rgba(219,165,6,0.4)] hover:shadow-[0_14px_24px_rgba(0,0,0,0.35)]"
              >
                <div className="flex items-center gap-3">
                  <div
                    className="relative inline-flex h-[42px] w-[42px] shrink-0 items-center justify-center rounded-full text-base font-bold text-white"
                    style={{
                      backgroundColor: person.color || (person.isDefault ? IOS_COLORS.purple : IOS_COLORS.gray),
                    }}
                  >
                    {person.emoji || person.name.charAt(0).toUpperCase()}
                    {person.is_trusted && (
                      <Star className="absolute -bottom-0.5 -right-0.5 h-[14px] w-[14px] fill-current text-[var(--color-ios-yellow)]" />
                    )}
                  </div>

                  <div className="min-w-0 flex-1">
                    <div className="flex items-center gap-2">
                      <h3 className="m-0 overflow-hidden text-ellipsis whitespace-nowrap text-[0.95rem] font-bold text-[var(--color-ios-label)]" title={person.name}>
                        {person.name}
                      </h3>
                      {person.isDefault && (
                        <span className="rounded-full bg-[rgba(191,90,242,0.18)] px-2 py-0.5 text-[0.62rem] font-bold leading-none tracking-[0.03em] text-[#f2db83]">
                          Quick
                        </span>
                      )}
                      <ChevronRight className="ml-auto h-4 w-4 shrink-0 text-[var(--color-ios-label-tertiary)]" />
                    </div>
                    <p className="mt-0.5 text-[0.77rem] text-[var(--color-ios-label-secondary)]">
                      {person.totalRecommendations} movie{person.totalRecommendations === 1 ? "" : "s"}
                      {person.avgRating ? ` • ${person.avgRating.toFixed(1)} avg` : ""}
                    </p>
                  </div>
                </div>

                <div className="flex flex-wrap gap-2">
                  <span className="inline-flex items-center gap-1 rounded-full bg-white/10 px-2 py-1 text-[0.7rem] font-bold text-[var(--color-ios-label-secondary)]">
                    <Film className="w-3.5 h-3.5" />
                    {person.totalRecommendations}
                  </span>
                  <span className="inline-flex items-center gap-1 rounded-full border border-[rgba(255,159,10,0.3)] bg-[rgba(255,159,10,0.12)] px-2 py-1 text-[0.7rem] font-bold text-[#f2c35f]">
                    <Clock className="w-3.5 h-3.5" />
                    {person.toWatch} to watch
                  </span>
                  <span className="inline-flex items-center gap-1 rounded-full border border-[rgba(48,209,88,0.28)] bg-[rgba(48,209,88,0.12)] px-2 py-1 text-[0.7rem] font-bold text-[#8ddea2]">
                    <Eye className="w-3.5 h-3.5" />
                    {person.watched} watched
                  </span>
                </div>

                <div className="mt-auto flex flex-wrap gap-x-3 gap-y-1 text-[0.7rem] text-[var(--color-ios-label-tertiary)]">
                  <span>
                    {colorMatchCount === 0 ? "Unique color" : `${colorMatchCount} share color`}
                  </span>
                  {person.emoji && (
                    <span>
                      {emojiMatchCount === 0 ? "Unique emoji" : `${emojiMatchCount} share emoji`}
                    </span>
                  )}
                </div>
              </button>
            );
          })}
        </div>
      )}
    </div>
  );
}
