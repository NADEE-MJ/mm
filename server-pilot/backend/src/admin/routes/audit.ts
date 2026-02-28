import { Hono } from "hono";
import { sqlite } from "../../db";

export const adminAuditRoutes = new Hono();

adminAuditRoutes.get("/", (c) => {
  const limitRaw = Number.parseInt(c.req.query("limit") ?? "100", 10);
  const limit = Math.min(1000, Math.max(1, Number.isFinite(limitRaw) ? limitRaw : 100));

  const rows = sqlite
    .query(
      `
      SELECT id, device_id, method, path, status_code, timestamp_ms, failed, fail_reason
      FROM audit_log
      ORDER BY id DESC
      LIMIT ?
    `,
    )
    .all(limit) as Array<{
    id: number;
    device_id: string | null;
    method: string;
    path: string;
    status_code: number;
    timestamp_ms: number;
    failed: number;
    fail_reason: string | null;
  }>;

  return c.json({
    entries: rows.map((row) => ({
      id: row.id,
      deviceId: row.device_id,
      method: row.method,
      path: row.path,
      statusCode: row.status_code,
      timestampMs: row.timestamp_ms,
      failed: row.failed === 1,
      failReason: row.fail_reason,
    })),
  });
});
