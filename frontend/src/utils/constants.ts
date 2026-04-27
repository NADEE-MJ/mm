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
  gray: "#8e8e93",
};
