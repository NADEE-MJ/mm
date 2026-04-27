CREATE TABLE IF NOT EXISTS jobs (
  id TEXT PRIMARY KEY,
  last_run_at INTEGER
);
--> statement-breakpoint
CREATE TABLE IF NOT EXISTS package_state (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  last_updated_at INTEGER
);
