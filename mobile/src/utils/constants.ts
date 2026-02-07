/**
 * App-wide constants
 */

// API Configuration
// Uses EXPO_PUBLIC_API_URL from .env, with fallback defaults
export const API_CONFIG = {
  BASE_URL: process.env.EXPO_PUBLIC_API_URL || "https://api.moviemanager.com/api",
  TIMEOUT: 30000,
  MAX_RETRIES: 3,
};

// Sync Configuration
export const SYNC_CONFIG = {
  RETRY_DELAYS: [1000, 5000, 15000], // Exponential backoff: 1s, 5s, 15s
  MAX_RETRIES: 3,
  BACKGROUND_INTERVAL: 1800000, // 30 minutes in milliseconds
  DEBOUNCE_DELAY: 2000, // Wait 2s after last change before syncing
};

// Theme Colors
export const COLORS = {
  primary: "#0a84ff",
  secondary: "#5856d6",
  success: "#34c759",
  warning: "#ff9500",
  error: "#ff3b30",
  background: "#000000",
  surface: "#1c1c1e",
  text: "#ffffff",
  textSecondary: "#8e8e93",
  border: "#38383a",
};

// Movie Status
export const MOVIE_STATUS = {
  TO_WATCH: "toWatch",
  WATCHED: "watched",
  DELETED: "deleted",
  CUSTOM: "custom",
} as const;

// Vote Types
export const VOTE_TYPES = {
  UPVOTE: "upvote",
  DOWNVOTE: "downvote",
} as const;

// Default Person Color
export const DEFAULT_PERSON_COLOR = "#0a84ff";

// Rating Range
export const RATING_RANGE = {
  MIN: 1,
  MAX: 10,
  STEP: 0.5,
} as const;
