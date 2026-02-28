import { chmodSync, existsSync, mkdirSync } from "node:fs";
import path from "node:path";
import { Database } from "bun:sqlite";
import { drizzle } from "drizzle-orm/bun-sqlite";
import { appConfig } from "../config";
import * as schema from "./schema";

const resolveProjectRelativePath = (rawPath: string): string => {
  if (path.isAbsolute(rawPath)) {
    return rawPath;
  }

  return path.resolve(process.cwd(), rawPath.replace(/^\.\//, ""));
};

const databasePath = resolveProjectRelativePath(appConfig.DATABASE_PATH);
const databaseExists = existsSync(databasePath);

mkdirSync(path.dirname(databasePath), { recursive: true });

export const sqlite = new Database(databasePath, { create: true });

sqlite.exec("PRAGMA journal_mode = WAL;");
sqlite.exec("PRAGMA foreign_keys = ON;");

if (!databaseExists) {
  chmodSync(databasePath, 0o600);
}

sqlite.exec(`
CREATE TABLE IF NOT EXISTS devices (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  key_a_pem TEXT NOT NULL,
  key_b_pem TEXT NOT NULL,
  enabled INTEGER NOT NULL DEFAULT 1,
  created_at INTEGER NOT NULL,
  last_seen_at INTEGER
);

CREATE TABLE IF NOT EXISTS enrollment_tokens (
  code TEXT PRIMARY KEY,
  device_name TEXT NOT NULL,
  expires_at INTEGER NOT NULL,
  used_at INTEGER,
  failed_attempts INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS seen_nonces (
  nonce TEXT PRIMARY KEY,
  device_id TEXT NOT NULL,
  expires_at INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS idempotency_cache (
  device_id TEXT NOT NULL,
  key TEXT NOT NULL,
  status_code INTEGER NOT NULL,
  response_json TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  expires_at INTEGER NOT NULL,
  PRIMARY KEY(device_id, key)
);

CREATE TABLE IF NOT EXISTS jobs (
  id TEXT PRIMARY KEY,
  command TEXT NOT NULL,
  schedule TEXT NOT NULL,
  enabled INTEGER NOT NULL DEFAULT 1,
  created_at INTEGER NOT NULL,
  last_run_at INTEGER
);

CREATE TABLE IF NOT EXISTS package_state (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  last_updated_at INTEGER
);

CREATE TABLE IF NOT EXISTS audit_log (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  device_id TEXT,
  method TEXT NOT NULL,
  path TEXT NOT NULL,
  status_code INTEGER NOT NULL,
  timestamp_ms INTEGER NOT NULL,
  failed INTEGER NOT NULL DEFAULT 0,
  fail_reason TEXT
);
`);

export const db = drizzle(sqlite, { schema });
