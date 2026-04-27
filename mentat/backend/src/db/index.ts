import { chmodSync, existsSync, mkdirSync } from "node:fs";
import path from "node:path";
import { Database } from "bun:sqlite";
import { drizzle } from "drizzle-orm/bun-sqlite";
import { migrate } from "drizzle-orm/bun-sqlite/migrator";
import { appConfig } from "../config";
import { resolveProjectRelativePath } from "../utils";
import * as schema from "./schema";

const databasePath = resolveProjectRelativePath(appConfig.DATABASE_PATH);
const databaseExists = existsSync(databasePath);

mkdirSync(path.dirname(databasePath), { recursive: true });

export const sqlite = new Database(databasePath, { create: true });

sqlite.exec("PRAGMA journal_mode = WAL;");
sqlite.exec("PRAGMA foreign_keys = ON;");

if (!databaseExists) {
  chmodSync(databasePath, 0o600);
}

export const db = drizzle(sqlite, { schema });

// Apply migrations on startup. The migrations folder is the single source of
// truth for the schema — no ad-hoc DDL lives outside of it.
migrate(db, { migrationsFolder: `${import.meta.dir}/migrations` });
