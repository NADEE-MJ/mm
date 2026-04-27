import { useMemo, useState, useRef, useEffect } from "react";
import { useNavigate, useParams } from "react-router-dom";
import {
  ChevronLeft,
  Star,
  StarOff,
  Film,
  Eye,
  Clock,
  Palette,
  Smile,
  Check,
  TrendingUp,
  Pencil,
  X,
} from "lucide-react";
import { getPoster, formatRating } from "../utils/helpers";
import { IOS_COLORS } from "../utils/constants";
import { usePeople } from "../hooks/usePeople";
import { buildPersonStats, getPeopleMetaCounts } from "../utils/people";

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

export default function PersonDetailPage({ movies = [] }) {
  const navigate = useNavigate();
  const { name } = useParams();
  const { people, loading, updateTrust, updatePerson } = usePeople();
  const [isEditingName, setIsEditingName] = useState(false);
  const [nameInput, setNameInput] = useState("");
  const [nameError, setNameError] = useState("");
  const nameInputRef = useRef(null);

  const decodedName = decodeURIComponent(name || "");

  const { color: colorCounts, emoji: emojiCounts } = useMemo(
    () => getPeopleMetaCounts(people),
    [people],
  );

  const person = useMemo(() => {
    const personRecord = people.find((entry) => entry.name === decodedName);
    return personRecord ? buildPersonStats(personRecord, movies) : null;
  }, [decodedName, people, movies]);

  const handleToggleTrust = async () => {
    if (!person) return;
    await updateTrust(person.name, !person.is_trusted);
  };

  const handleUpdatePerson = async (updates) => {
    if (!person) return;
    await updatePerson(person.name, updates);
  };

  useEffect(() => {
    if (isEditingName && nameInputRef.current) {
      nameInputRef.current.focus();
    }
  }, [isEditingName]);

  const handleStartEditName = () => {
    setNameInput(person?.name || "");
    setNameError("");
    setIsEditingName(true);
  };

  const handleCancelEditName = () => {
    setIsEditingName(false);
    setNameError("");
  };

  const handleSaveName = async () => {
    const trimmed = nameInput.trim();
    if (!trimmed) {
      setNameError("Name cannot be empty");
      return;
    }
    if (trimmed === person.name) {
      setIsEditingName(false);
      return;
    }
    try {
      await updatePerson(person.name, { name: trimmed });
      setIsEditingName(false);
      navigate(`/people/${encodeURIComponent(trimmed)}`, { replace: true });
    } catch {
      setNameError("Failed to rename. Name may already be taken.");
    }
  };

  const handleBackToPeople = () => {
    if (window.history.length > 1) {
      navigate(-1);
      return;
    }
    navigate("/people");
  };

  if (loading) {
    return (
      <div className="space-y-4">
        <button
          onClick={handleBackToPeople}
          className="inline-flex items-center gap-1 rounded-[10px] bg-white/10 px-2.5 py-1.5 text-[0.85rem] font-semibold text-[var(--color-ios-label)]"
        >
          <ChevronLeft className="w-4 h-4" />
          <span>Back to Recommenders</span>
        </button>
        <p className="text-ios-secondary-label">Loading recommender...</p>
      </div>
    );
  }

  if (!person) {
    return (
      <div className="space-y-4">
        <button
          onClick={handleBackToPeople}
          className="inline-flex items-center gap-1 rounded-[10px] bg-white/10 px-2.5 py-1.5 text-[0.85rem] font-semibold text-[var(--color-ios-label)]"
        >
          <ChevronLeft className="w-4 h-4" />
          <span>Back to Recommenders</span>
        </button>
        <p className="text-ios-secondary-label">Recommender not found.</p>
      </div>
    );
  }

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
    <div className="space-y-6">
      <button
        onClick={handleBackToPeople}
        className="inline-flex items-center gap-1 rounded-[10px] bg-white/10 px-2.5 py-1.5 text-[0.85rem] font-semibold text-[var(--color-ios-label)]"
      >
        <ChevronLeft className="w-4 h-4" />
        <span>Back to Recommenders</span>
      </button>

      <div className="ios-card p-4">
        <div className="flex items-center justify-between gap-3">
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
            <div className="flex-1 min-w-0">
              {isEditingName ? (
                <div className="flex flex-col gap-1">
                  <div className="flex items-center gap-2">
                    <input
                      ref={nameInputRef}
                      type="text"
                      value={nameInput}
                      onChange={(e) => { setNameInput(e.target.value); setNameError(""); }}
                      onKeyDown={(e) => { if (e.key === "Enter") handleSaveName(); if (e.key === "Escape") handleCancelEditName(); }}
                      className="flex-1 min-w-0 rounded-lg bg-ios-fill px-2 py-1 text-ios-body font-semibold text-ios-label border border-ios-blue/50 focus:outline-none focus:border-ios-blue"
                    />
                    <button onClick={handleSaveName} className="text-ios-blue text-sm font-semibold shrink-0">Save</button>
                    <button onClick={handleCancelEditName} className="text-ios-secondary-label shrink-0"><X className="w-4 h-4" /></button>
                  </div>
                  {nameError && <p className="text-[0.72rem] text-ios-red">{nameError}</p>}
                </div>
              ) : (
                <div className="flex items-center gap-2">
                  <p className="text-ios-body font-semibold text-ios-label truncate">{person.name}</p>
                  {!person.isDefault && (
                    <button onClick={handleStartEditName} className="text-ios-secondary-label hover:text-ios-label shrink-0">
                      <Pencil className="w-3.5 h-3.5" />
                    </button>
                  )}
                </div>
              )}
              <p className="text-ios-caption1 text-ios-secondary-label">
                {person.is_trusted ? "Trusted Recommender" : "Not Trusted"}
              </p>
            </div>
          </div>
          <button
            onClick={handleToggleTrust}
            className={`px-4 py-2 rounded-xl text-sm font-medium transition-all active:scale-95 ${
              person.is_trusted ? "bg-ios-yellow/20 text-ios-yellow" : "bg-ios-fill text-ios-label"
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

      <div className="grid grid-cols-3 gap-3">
        {stats.map((stat) => (
          <div key={stat.label} className="ios-card p-4 text-center">
            <stat.icon className={`w-6 h-6 mx-auto mb-2 ${stat.color}`} />
            <p className="text-ios-title2 font-bold text-ios-label">{stat.value}</p>
            <p className="text-ios-caption2 text-ios-secondary-label">{stat.label}</p>
          </div>
        ))}
      </div>

      {person.avgRating && (
        <div className="ios-card p-4 bg-ios-blue/5 border border-ios-blue/20">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-3">
              <TrendingUp className="w-6 h-6 text-ios-blue" />
              <span className="text-ios-body text-ios-label">Average Rating</span>
            </div>
            <div className="flex items-center gap-1">
              <Star className="w-5 h-5 text-ios-blue fill-current" />
              <span className="text-ios-title2 font-bold text-ios-blue">{person.avgRating.toFixed(1)}</span>
            </div>
          </div>
        </div>
      )}

      <div className="ios-card p-4">
        <div className="flex items-center justify-between mb-3">
          <div className="flex items-center gap-2 text-ios-secondary-label text-sm font-medium uppercase tracking-wide">
            <Palette className="w-4 h-4" />
            Color
          </div>
          <span className="text-ios-caption2 text-ios-tertiary-label">
            {sharedColors === 0 ? "Unique color" : `${sharedColors} other${sharedColors === 1 ? "" : "s"}`}
          </span>
        </div>
        <div className="flex flex-wrap gap-2">
          {COLOR_OPTIONS.map((option) => (
            <button
              key={option}
              type="button"
              onClick={() => handleUpdatePerson({ color: option })}
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

      <div className="ios-card p-4">
        <div className="flex items-center justify-between mb-3">
          <div className="flex items-center gap-2 text-ios-secondary-label text-sm font-medium uppercase tracking-wide">
            <Smile className="w-4 h-4" />
            Emoji
          </div>
          <span className="text-ios-caption2 text-ios-tertiary-label">
            {sharedEmoji === 0 ? "Unique emoji" : `${sharedEmoji} other${sharedEmoji === 1 ? "" : "s"}`}
          </span>
        </div>
        <div className="flex flex-wrap gap-2">
          {EMOJI_OPTIONS.map((option) => (
            <button
              key={option}
              type="button"
              onClick={() => handleUpdatePerson({ emoji: option })}
              className={`px-3 py-2 rounded-xl text-lg ${
                person.emoji === option ? "bg-ios-blue text-white" : "bg-ios-fill"
              }`}
            >
              {option}
            </button>
          ))}
          <button
            type="button"
            onClick={() => handleUpdatePerson({ emoji: null })}
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

      {person.movies.length > 0 && (
        <div>
          <h4 className="text-ios-caption1 font-semibold text-ios-secondary-label uppercase tracking-wider mb-3">
            Movies ({person.movies.length})
          </h4>
          <div className="ios-list">
            {person.movies.map((movie) => {
              const title = movie.omdbData?.title || movie.tmdbData?.title || "Unknown";
              const year = movie.omdbData?.year || movie.tmdbData?.year;
              const poster = getPoster(movie.omdbData?.poster || movie.tmdbData?.poster);
              const rating = movie.watchHistory?.myRating;
              const isWatched = movie.status === "watched";

              return (
                <button
                  key={movie.imdbId}
                  onClick={() => navigate(`/?movie=${movie.imdbId}`)}
                  className="ios-list-item py-3 w-full text-left"
                >
                  <div className="flex items-center gap-3 flex-1 min-w-0">
                    <img
                      src={poster}
                      alt={title}
                      className="w-10 h-15 object-cover rounded-lg flex-shrink-0"
                    />
                    <div className="flex-1 min-w-0">
                      <p className="text-ios-body text-ios-label font-medium truncate">{title}</p>
                      <p className="text-ios-caption1 text-ios-secondary-label">
                        {year}
                        {isWatched && <span className="ml-2 text-ios-green">• Watched</span>}
                      </p>
                    </div>
                  </div>
                  {rating && (
                    <div className="flex items-center gap-1 text-ios-blue ml-3">
                      <Star className="w-4 h-4 fill-current" />
                      <span className="text-ios-caption1 font-semibold">{formatRating(rating)}</span>
                    </div>
                  )}
                </button>
              );
            })}
          </div>
        </div>
      )}
    </div>
  );
}
