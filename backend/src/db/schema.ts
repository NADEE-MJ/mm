import { sqliteTable, text, integer } from "drizzle-orm/sqlite-core";

export const jobs = sqliteTable("jobs", {
  id: text("id").primaryKey(),
  lastRunAt: integer("last_run_at", { mode: "timestamp_ms" }),
});

export const packageState = sqliteTable("package_state", {
  id: integer("id").primaryKey({ autoIncrement: true }),
  lastUpdatedAt: integer("last_updated_at", { mode: "timestamp_ms" }),
});

export const appBuilds = sqliteTable("app_builds", {
  appId: text("app_id").notNull(),
  serverId: text("server_id").notNull(),
  lastBuiltAt: integer("last_built_at", { mode: "timestamp_ms" }),
  lastBuildOutput: text("last_build_output"),
  lastBuildExitCode: integer("last_build_exit_code"),
});

