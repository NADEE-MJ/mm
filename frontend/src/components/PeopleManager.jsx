/**
 * PeopleManager component - iOS Style
 * Manage people/recommenders with detailed stats
 */

import { useState, useMemo, useEffect } from "react";
import {
  Users,
  Star,
  StarOff,
  ChevronRight,
  Film,
  TrendingUp,
  Eye,
  Clock,
  X,
  Plus,
  Palette,
  Smile,
  Check,
} from "lucide-react";
import { usePeople } from "../hooks/usePeople";
import { getPoster, formatRating } from "../utils/helpers";
import { DEFAULT_RECOMMENDERS, IOS_COLORS } from "../utils/constants";

const COLOR_OPTIONS = [
  IOS_COLORS.blue,
  IOS_COLORS.green,
  IOS_COLORS.orange,
  IOS_COLORS.purple,
  IOS_COLORS.pink,
  IOS_COLORS.teal,
  IOS_COLORS.yellow,
  IOS_COLORS.gray,
];

const EMOJI_OPTIONS = ["🍿", "🎬", "🎯", "🔥", "🌟", "💡", "🤝", "🎲", "🧠", "📽️"];

function AddPersonCard({ onAdd, existingNames }) {
  const [name, setName] = useState("");
  const [color, setColor] = useState(COLOR_OPTIONS[0]);
  const [emoji, setEmoji] = useState(EMOJI_OPTIONS[0]);
  const [isTrusted, setIsTrusted] = useState(false);
  const [error, setError] = useState(null);
  const [submitting, setSubmitting] = useState(false);

  const handleSubmit = async (event) => {
    event.preventDefault();
    const trimmed = name.trim();
    if (!trimmed) {
      setError("Name is required");
      return;
    }

    const lower = trimmed.toLowerCase();
    if (existingNames.some((existing) => existing.toLowerCase() === lower)) {
      setError("Person already exists");
      return;
    }

    setSubmitting(true);
    try {
      await onAdd({
        name: trimmed,
        color,
        emoji,
        isTrusted,
      });
      setName("");
      setIsTrusted(false);
      setError(null);
    } catch (err) {
      setError(err.message || "Unable to add person");
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <div className="ios-card p-4 space-y-4">
      <div className="flex items-center gap-2">
        <Plus className="w-5 h-5 text-ios-blue" />
        <h3 className="text-ios-headline font-semibold text-ios-label">Add Person</h3>
      </div>

      <form className="space-y-4" onSubmit={handleSubmit}>
        <input
          type="text"
          value={name}
          onChange={(e) => setName(e.target.value)}
          placeholder="Name"
          className="ios-input"
          autoComplete="off"
        />

        <div>
          <div className="flex items-center justify-between mb-2">
            <div className="flex items-center gap-2 text-ios-secondary-label text-sm font-medium uppercase tracking-wide">
              <Palette className="w-4 h-4" />
              Color
            </div>
            <span className="text-ios-caption2 text-ios-tertiary-label">{color}</span>
          </div>
          <div className="flex flex-wrap gap-2">
            {COLOR_OPTIONS.map((option) => (
              <button
                key={option}
                type="button"
                onClick={() => setColor(option)}
                className={`w-10 h-10 rounded-full border-2 ${
                  color === option ? "border-ios-blue" : "border-transparent"
                }`}
                style={{ backgroundColor: option }}
                aria-label={`Select color ${option}`}
              />
            ))}
          </div>
        </div>

        <div>
          <div className="flex items-center gap-2 text-ios-secondary-label text-sm font-medium uppercase tracking-wide mb-2">
            <Smile className="w-4 h-4" />
            Emoji
          </div>
          <div className="flex flex-wrap gap-2">
            {EMOJI_OPTIONS.map((option) => (
              <button
                key={option}
                type="button"
                onClick={() => setEmoji(option)}
                className={`px-3 py-2 rounded-xl text-lg ${
                  emoji === option ? "bg-ios-blue text-white" : "bg-ios-fill"
                }`}
              >
                {option}
              </button>
            ))}
            <button
              type="button"
              onClick={() => setEmoji(null)}
              className={`px-3 py-2 rounded-xl text-sm font-medium ${
                emoji == null ? "bg-ios-blue/10 text-ios-blue" : "bg-ios-fill text-ios-secondary-label"
              }`}
            >
              None
            </button>
          </div>
        </div>

        <div className="flex items-center justify-between">
          <span className="text-ios-secondary-label">Trusted recommender</span>
          <button
            type="button"
            onClick={() => setIsTrusted((prev) => !prev)}
            className={`px-4 py-1.5 rounded-full text-sm font-medium ${
              isTrusted ? "bg-ios-yellow/20 text-ios-yellow" : "bg-ios-fill text-ios-label"
            }`}
          >
            {isTrusted ? "Trusted" : "Not Trusted"}
          </button>
        </div>

        {error && <p className="text-ios-red text-sm">{error}</p>}

        <button
          type="submit"
          disabled={submitting || !name.trim()}
          className="btn-ios-primary w-full disabled:opacity-50"
        >
          {submitting ? "Adding..." : "Save Person"}
        </button>
      </form>
    </div>
  );
}

function PersonDetailSheet({ person, onClose, onToggleTrust, onUpdatePerson, colorCounts, emojiCounts }) {
  if (!person) return null;

  const avatarColor = person.color || IOS_COLORS.gray;
  const avatarEmoji = person.emoji || person.name.charAt(0).toUpperCase();
  const colorKey = person.color || "default";
  const emojiKey = person.emoji || "none";
  const sharedColors = Math.max(0, (colorCounts[colorKey] || 1) - 1);
  const sharedEmoji = Math.max(0, (emojiCounts[emojiKey] || 1) - 1);

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
                  className="w-12 h-12 rounded-full flex items-center justify-center text-xl font-semibold text-white relative"
                  style={{ backgroundColor: avatarColor }}
                >
                  {avatarEmoji}
                  {person.is_trusted && (
                    <Star className="w-4 h-4 text-ios-yellow fill-current absolute -bottom-1 -right-1 drop-shadow" />
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

          {/* Color selection */}
          <div className="ios-card p-4 mb-4">
            <div className="flex items-center justify-between mb-3">
              <div className="flex items-center gap-2 text-ios-secondary-label text-sm font-medium uppercase tracking-wide">
                <Palette className="w-4 h-4" />
                Color
              </div>
              <span className="text-ios-caption2 text-ios-tertiary-label">
                {sharedColors === 0
                  ? "Unique color"
                  : `${sharedColors} other${sharedColors === 1 ? "" : "s"}`}
              </span>
            </div>
            <div className="flex flex-wrap gap-2">
              {COLOR_OPTIONS.map((option) => (
                <button
                  key={option}
                  type="button"
                  onClick={() => onUpdatePerson(person.name, { color: option })}
                  className={`w-10 h-10 rounded-full border-2 ${
                    person.color === option ? "border-ios-blue" : "border-transparent"
                  }`}
                  style={{ backgroundColor: option }}
                >
                  {person.color === option && <Check className="w-4 h-4 text-white" />}
                </button>
              ))}
            </div>
          </div>

          {/* Emoji selection */}
          <div className="ios-card p-4 mb-6">
            <div className="flex items-center justify-between mb-3">
              <div className="flex items-center gap-2 text-ios-secondary-label text-sm font-medium uppercase tracking-wide">
                <Smile className="w-4 h-4" />
                Emoji
              </div>
              <span className="text-ios-caption2 text-ios-tertiary-label">
                {sharedEmoji === 0
                  ? "Unique emoji"
                  : `${sharedEmoji} other${sharedEmoji === 1 ? "" : "s"}`}
              </span>
            </div>
            <div className="flex flex-wrap gap-2">
              {EMOJI_OPTIONS.map((option) => (
                <button
                  key={option}
                  type="button"
                  onClick={() => onUpdatePerson(person.name, { emoji: option })}
                  className={`px-3 py-2 rounded-xl text-lg ${
                    person.emoji === option ? "bg-ios-blue text-white" : "bg-ios-fill"
                  }`}
                >
                  {option}
                </button>
              ))}
              <button
                type="button"
                onClick={() => onUpdatePerson(person.name, { emoji: null })}
                className={`px-3 py-2 rounded-xl text-sm font-medium ${
                  person.emoji == null
                    ? "bg-ios-blue/10 text-ios-blue"
                    : "bg-ios-fill text-ios-secondary-label"
                }`}
              >
                None
              </button>
            </div>
          </div>

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
  const { people, addPerson, updatePerson, updateTrust } = usePeople();
  const [filter, setFilter] = useState("all");
  const [selectedPerson, setSelectedPerson] = useState(null);

  const existingNames = useMemo(() => people.map((person) => person.name), [people]);

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

  const handleAddPerson = async (payload) => {
    await addPerson(payload);
  };

  const handleUpdatePerson = async (name, updates) => {
    try {
      await updatePerson(name, updates);
    } catch (err) {
      console.error("Error updating person metadata:", err);
    }
  };

  useEffect(() => {
    if (!selectedPerson) return;
    const updated = peopleWithStats.find((person) => person.name === selectedPerson.name);
    if (updated && updated !== selectedPerson) {
      setSelectedPerson(updated);
    }
  }, [peopleWithStats, selectedPerson]);

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

      {/* Add person */}
      <AddPersonCard onAdd={handleAddPerson} existingNames={existingNames} />

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
          {filteredPeople.map((person) => {
            const colorMatchCount = Math.max(0, (colorCounts[person.color || "default"] || 1) - 1);
            const emojiMatchCount = Math.max(0, (emojiCounts[person.emoji || "none"] || 1) - 1);
            return (
              <button
                key={person.name}
                onClick={() => setSelectedPerson(person)}
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

      {/* Person Detail Sheet */}
      {selectedPerson && (
        <PersonDetailSheet
          person={selectedPerson}
          onClose={() => setSelectedPerson(null)}
          onToggleTrust={handleToggleTrust}
          onUpdatePerson={handleUpdatePerson}
          colorCounts={colorCounts}
          emojiCounts={emojiCounts}
        />
      )}
    </div>
  );
}
