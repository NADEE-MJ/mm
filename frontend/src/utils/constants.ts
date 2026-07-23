/**
 * Constants used throughout the application
 */

export const MOVIE_STATUS = {
  TO_WATCH: "toWatch",
  WATCHED: "watched",
  DELETED: "deleted",
  CUSTOM: "custom", // For custom lists
};

export const SYNC_STATUS = {
  SYNCED: "synced",
  PENDING: "pending",
  CONFLICT: "conflict",
  OFFLINE: "offline",
};

export const RATING_THRESHOLD = 6.0; // Threshold for triggering questionable prompt

export const VOTE_TYPE = {
  UPVOTE: "upvote",
  DOWNVOTE: "downvote",
};

export const MEDIA_TYPE = {
  MOVIE: "movie",
  TV: "tv",
  PERSON: "person",
};

export const API_LIMITS = {
  TMDB_RATE_LIMIT: 40, // 40 requests per second
  OMDB_DAILY_LIMIT: 1000, // 1000 requests per day
};

export const POSTER_PLACEHOLDER = "/poster-placeholder.svg";

// iOS Design tokens
export const IOS_COLORS = {
  blue: "#0a84ff",
  green: "#30d158",
  red: "#ff453a",
  orange: "#ff9f0a",
  yellow: "#ffd60a",
  purple: "#bf5af2",
  pink: "#ff375f",
  teal: "#64d2ff",
  indigo: "#5e5ce6",
  mint: "#63e6be",
  brown: "#ac8e68",
  cyan: "#32ade6",
  gray: "#8e8e93",
};

// Keep in sync with mobile/Sources/Theme/AppTheme.swift (PersonAppearance.colorHexOptions/emojiOptions).
export const PERSON_COLOR_OPTIONS = [
  IOS_COLORS.blue,
  IOS_COLORS.green,
  IOS_COLORS.red,
  IOS_COLORS.orange,
  IOS_COLORS.yellow,
  IOS_COLORS.purple,
  IOS_COLORS.pink,
  IOS_COLORS.teal,
  IOS_COLORS.indigo,
  IOS_COLORS.mint,
  IOS_COLORS.brown,
  IOS_COLORS.cyan,
  IOS_COLORS.gray,
];

export const PERSON_EMOJI_OPTIONS = [
  "🍿", "🎬", "🎯", "🔥", "🌟", "💡", "🤝", "🎲", "🧠", "📽️",
  "🎥", "🏆", "👑", "🕵️", "🦹", "🎭", "🍭", "🕶️", "🐉", "🌈",
];
