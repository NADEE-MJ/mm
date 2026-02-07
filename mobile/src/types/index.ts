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
  id: number;
  title: string;
  overview: string;
  poster_path: string | null;
  backdrop_path: string | null;
  release_date: string;
  vote_average: number;
  vote_count: number;
  genres: { id: number; name: string }[];
  runtime: number | null;
  tagline: string | null;
}

export interface OMDBData {
  Title: string;
  Year: string;
  Rated: string;
  Released: string;
  Runtime: string;
  Genre: string;
  Director: string;
  Writer: string;
  Actors: string;
  Plot: string;
  Language: string;
  Country: string;
  Awards: string;
  Poster: string;
  Ratings: { Source: string; Value: string }[];
  Metascore: string;
  imdbRating: string;
  imdbVotes: string;
  imdbID: string;
  Type: string;
  DVD: string;
  BoxOffice: string;
  Production: string;
  Website: string;
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
  current_state?: any;
  conflict?: boolean;
}

export interface ServerSyncData {
  movies?: any[];  // Backend returns serialized movies, not full Movie objects
  recommendations?: Recommendation[];
  watch_history?: WatchHistory[];
  movie_status?: MovieStatus[];
  people?: any[];  // Backend returns simplified people objects
  custom_lists?: CustomList[];
  timestamp?: number;  // Backend uses "timestamp", not "server_timestamp"
  server_timestamp?: number;  // Keep for future compatibility
}
