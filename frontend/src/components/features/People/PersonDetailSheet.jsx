import { useState, useEffect } from "react";
import {
  Star,
  StarOff,
  Film,
  Eye,
  Clock,
  X,
  Palette,
  Smile,
  Check,
  TrendingUp,
} from "lucide-react";
import { getPoster, formatRating } from "../../../utils/helpers";
import { IOS_COLORS } from "../../../utils/constants";

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

export default function PersonDetailSheet({ person, onClose, onToggleTrust, onUpdatePerson, colorCounts, emojiCounts }) {
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
