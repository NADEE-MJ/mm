import { primaryKey, sqliteTable, text, integer } from "drizzle-orm/sqlite-core";

export const devices = sqliteTable("devices", {
  id: text("id").primaryKey(),
  name: text("name").notNull(),
  keyAPem: text("key_a_pem").notNull(),
  keyBPem: text("key_b_pem").notNull(),
  enabled: integer("enabled", { mode: "boolean" }).default(true),
  createdAt: integer("created_at", { mode: "timestamp_ms" }).notNull(),
  lastSeenAt: integer("last_seen_at", { mode: "timestamp_ms" }),
});

export const enrollmentTokens = sqliteTable("enrollment_tokens", {
  code: text("code").primaryKey(),
  deviceName: text("device_name").notNull(),
  expiresAt: integer("expires_at", { mode: "timestamp_ms" }).notNull(),
  usedAt: integer("used_at", { mode: "timestamp_ms" }),
  failedAttempts: integer("failed_attempts").default(0),
});

export const seenNonces = sqliteTable("seen_nonces", {
  nonce: text("nonce").primaryKey(),
  deviceId: text("device_id").notNull(),
  expiresAt: integer("expires_at", { mode: "timestamp_ms" }).notNull(),
});

export const idempotencyCache = sqliteTable(
  "idempotency_cache",
  {
    deviceId: text("device_id").notNull(),
    key: text("key").notNull(),
    statusCode: integer("status_code").notNull(),
    responseJson: text("response_json").notNull(),
    createdAt: integer("created_at", { mode: "timestamp_ms" }).notNull(),
    expiresAt: integer("expires_at", { mode: "timestamp_ms" }).notNull(),
  },
  (table) => [primaryKey({ columns: [table.deviceId, table.key] })],
);

export const jobs = sqliteTable("jobs", {
  id: text("id").primaryKey(),
  command: text("command").notNull(),
  schedule: text("schedule").notNull(),
  enabled: integer("enabled", { mode: "boolean" }).default(true),
  createdAt: integer("created_at", { mode: "timestamp_ms" }).notNull(),
  lastRunAt: integer("last_run_at", { mode: "timestamp_ms" }),
});

export const packageState = sqliteTable("package_state", {
  id: integer("id").primaryKey({ autoIncrement: true }),
  lastUpdatedAt: integer("last_updated_at", { mode: "timestamp_ms" }),
});

export const auditLog = sqliteTable("audit_log", {
  id: integer("id").primaryKey({ autoIncrement: true }),
  deviceId: text("device_id"),
  method: text("method").notNull(),
  path: text("path").notNull(),
  statusCode: integer("status_code").notNull(),
  timestampMs: integer("timestamp_ms").notNull(),
  failed: integer("failed", { mode: "boolean" }).default(false),
  failReason: text("fail_reason"),
});

export const schema = {
  devices,
  enrollmentTokens,
  seenNonces,
  idempotencyCache,
  jobs,
  packageState,
  auditLog,
};
