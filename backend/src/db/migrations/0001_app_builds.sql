CREATE TABLE IF NOT EXISTS app_builds (
  app_id TEXT NOT NULL,
  server_id TEXT NOT NULL,
  last_built_at INTEGER,
  last_build_output TEXT,
  last_build_exit_code INTEGER,
  PRIMARY KEY (app_id, server_id)
);
