import * as SQLite from 'expo-sqlite';

export const DB_NAME = 'moviemanager.db';
export const DB_VERSION = 1;

export const SCHEMA_SQL = `
-- Users table (local cache, single user per device)
CREATE TABLE IF NOT EXISTS users (
    id TEXT PRIMARY KEY,
    email TEXT NOT NULL UNIQUE,
    username TEXT NOT NULL UNIQUE,
    created_at REAL NOT NULL
);

-- Movies table
CREATE TABLE IF NOT EXISTS movies (
    imdb_id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    tmdb_data TEXT,
    omdb_data TEXT,
    last_modified REAL NOT NULL,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_movies_last_modified ON movies(last_modified);

-- Recommendations table (votes)
CREATE TABLE IF NOT EXISTS recommendations (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    imdb_id TEXT NOT NULL,
    user_id TEXT NOT NULL,
    person TEXT NOT NULL,
    date_recommended REAL NOT NULL,
    vote_type TEXT NOT NULL DEFAULT 'upvote' CHECK(vote_type IN ('upvote', 'downvote')),
    FOREIGN KEY (imdb_id) REFERENCES movies(imdb_id) ON DELETE CASCADE,
    UNIQUE(imdb_id, user_id, person)
);

-- Watch history table
CREATE TABLE IF NOT EXISTS watch_history (
    imdb_id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    date_watched REAL NOT NULL,
    my_rating REAL NOT NULL CHECK(my_rating >= 1.0 AND my_rating <= 10.0),
    FOREIGN KEY (imdb_id) REFERENCES movies(imdb_id) ON DELETE CASCADE
);

-- Movie status table
CREATE TABLE IF NOT EXISTS movie_status (
    imdb_id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'toWatch' CHECK(status IN ('toWatch', 'watched', 'deleted', 'custom')),
    custom_list_id TEXT,
    FOREIGN KEY (imdb_id) REFERENCES movies(imdb_id) ON DELETE CASCADE
);

-- People table (recommenders)
CREATE TABLE IF NOT EXISTS people (
    name TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    is_trusted INTEGER DEFAULT 0,
    is_default INTEGER DEFAULT 0,
    color TEXT DEFAULT '#DBA506',
    emoji TEXT
);

-- Custom lists table
CREATE TABLE IF NOT EXISTS custom_lists (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    name TEXT NOT NULL,
    color TEXT DEFAULT '#DBA506',
    icon TEXT DEFAULT 'list',
    position INTEGER DEFAULT 0,
    created_at REAL NOT NULL
);

-- Sync queue table
CREATE TABLE IF NOT EXISTS sync_queue (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    action TEXT NOT NULL,
    data TEXT NOT NULL,
    timestamp REAL NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending' CHECK(status IN ('pending', 'processing', 'failed')),
    retries INTEGER DEFAULT 0,
    error TEXT,
    created_at REAL NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_sync_queue_status ON sync_queue(status);
CREATE INDEX IF NOT EXISTS idx_sync_queue_timestamp ON sync_queue(timestamp);

-- Metadata table
CREATE TABLE IF NOT EXISTS metadata (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL,
    updated_at REAL NOT NULL
);

-- Insert initial metadata
INSERT OR IGNORE INTO metadata (key, value, updated_at) VALUES
    ('last_sync', '0', 0),
    ('db_version', '${DB_VERSION}', 0),
    ('biometric_enabled', 'false', 0);
`;

export const DROP_ALL_TABLES_SQL = `
DROP TABLE IF EXISTS sync_queue;
DROP TABLE IF EXISTS movie_status;
DROP TABLE IF EXISTS watch_history;
DROP TABLE IF EXISTS recommendations;
DROP TABLE IF EXISTS movies;
DROP TABLE IF EXISTS custom_lists;
DROP TABLE IF EXISTS people;
DROP TABLE IF EXISTS users;
DROP TABLE IF EXISTS metadata;
`;

export interface Migration {
  version: number;
  sql: string;
}

export const MIGRATIONS: Migration[] = [
  // Add future migrations here
  // {
  //   version: 2,
  //   sql: 'ALTER TABLE movies ADD COLUMN new_field TEXT;'
  // }
];
