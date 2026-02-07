// User types
export interface User {
  id: string;
  email: string;
  username: string;
  created_at: number;
}

// Movie types
export interface Movie {
  imdb_id: string;
  user_id: string;
  tmdb_data?: TMDBData;
  omdb_data?: OMDBData;
  last_modified: number;
}

export interface TMDBData {
  id?: number;
  tmdbId?: number;
  imdbId?: string | null;
  title?: string;
  overview?: string;
  plot?: string;
  poster?: string | null;
  posterSmall?: string | null;
  poster_path?: string | null;
  backdrop?: string | null;
  backdrop_path?: string | null;
  release_date?: string;
  year?: string | number | null;
  vote_average?: number;
  voteAverage?: number;
  vote_count?: number;
  voteCount?: number;
  genres?: Array<{ id?: number; name?: string } | string>;
  cast?: string[];
  runtime?: number | null;
  tagline?: string | null;
}

export interface OMDBData {
  title?: string;
  year?: number | string | null;
  rated?: string;
  released?: string;
  runtime?: string;
  genres?: string[];
  director?: string;
  writer?: string;
  actors?: string[];
  plot?: string;
  language?: string;
  country?: string;
  awards?: string;
  poster?: string | null;
  imdbRating?: number | string | null;
  imdbVotes?: string;
  imdbId?: string;
  rtRating?: number | null;
  metascore?: number | string | null;
  boxOffice?: string;
  production?: string;
  website?: string;
  Title?: string;
  Year?: string;
  Rated?: string;
  Released?: string;
  Runtime?: string;
  Genre?: string;
  Director?: string;
  Writer?: string;
  Actors?: string;
  Plot?: string;
  Language?: string;
  Country?: string;
  Awards?: string;
  Poster?: string;
  Ratings?: { Source: string; Value: string }[];
  Metascore?: string;
  imdbID?: string;
  Type?: string;
  DVD?: string;
  BoxOffice?: string;
  Production?: string;
  Website?: string;
}

// Recommendation types
export interface Recommendation {
  id: number;
  imdb_id: string;
  user_id: string;
  person: string;
  date_recommended: number;
  vote_type: 'upvote' | 'downvote';
}

// Watch history types
export interface WatchHistory {
  imdb_id: string;
  user_id: string;
  date_watched: number;
  my_rating: number;
}

// Movie status types
export type MovieStatusType = 'toWatch' | 'watched' | 'deleted' | 'custom';

export interface MovieStatus {
  imdb_id: string;
  user_id: string;
  status: MovieStatusType;
  custom_list_id?: string;
}

// People types
export interface Person {
  name: string;
  user_id: string;
  is_trusted: boolean;
  is_default: boolean;
  color: string;
  emoji?: string;
}

// Custom list types
export interface CustomList {
  id: string;
  user_id: string;
  name: string;
  color: string;
  icon: string;
  position: number;
  created_at: number;
}

// Sync queue types
export type SyncAction =
  | 'addRecommendation'
  | 'removeRecommendation'
  | 'updateRecommendationVote'
  | 'markWatched'
  | 'updateRating'
  | 'updateStatus'
  | 'addPerson'
  | 'updatePerson'
  | 'deletePerson'
  | 'addList'
  | 'updateList'
  | 'deleteList';

export type SyncQueueStatus = 'pending' | 'processing' | 'failed';

export interface SyncQueueItem {
  id: number;
  action: SyncAction;
  data: any;
  timestamp: number;
  status: SyncQueueStatus;
  retries: number;
  error?: string;
  created_at: number;
}

// Metadata types
export interface Metadata {
  key: string;
  value: string;
  updated_at: number;
}

// Enhanced movie with related data
export interface MovieWithDetails extends Movie {
  recommendations: Recommendation[];
  watch_history?: WatchHistory;
  status: MovieStatus;
}

// API response types
export interface ApiResponse<T> {
  data: T;
  message?: string;
}

export interface AuthResponse {
  token: string;
  user: User;
}

export interface SyncResponse {
  success: boolean;
  last_modified?: number;
  error?: string;
  server_state?: any;
  conflict?: boolean;
}

export interface ServerSyncData {
  movies: any[];
  people: any[];
  lists: CustomList[];
  deleted_movie_ids: string[];
  has_more: boolean;
  next_offset?: number | null;
  timestamp?: number; // legacy /api/sync
  server_timestamp: number;
}

export interface BatchSyncRequest {
  actions: Array<{
    action: string;
    data: any;
    timestamp: number;
  }>;
  client_timestamp: number;
}

export interface BatchSyncResponse {
  results: SyncResponse[];
  server_timestamp: number;
}
