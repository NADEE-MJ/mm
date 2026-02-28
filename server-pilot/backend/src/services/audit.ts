import { appConfig } from "../config";
import { sqlite } from "../db";

export type AuditEvent = {
  deviceId: string | null;
  method: string;
  path: string;
  statusCode: number;
  failed: boolean;
  failReason?: string;
};

const insertStmt = sqlite.prepare(`
  INSERT INTO audit_log (
    device_id,
    method,
    path,
    status_code,
    timestamp_ms,
    failed,
    fail_reason
  ) VALUES (?, ?, ?, ?, ?, ?, ?)
`);

const pruneStmt = sqlite.prepare(`
  DELETE FROM audit_log
  WHERE id NOT IN (
    SELECT id FROM audit_log ORDER BY id DESC LIMIT ?
  )
`);

export const logAuditEvent = (event: AuditEvent): void => {
  const now = Date.now();

  insertStmt.run(
    event.deviceId,
    event.method,
    event.path,
    event.statusCode,
    now,
    event.failed ? 1 : 0,
    event.failReason ?? null,
  );

  pruneStmt.run(appConfig.AUDIT_LOG_MAX_ROWS);
};
