import { Hono } from "hono";
import { z } from "zod";
import { sqlite } from "../db";

type EnrollmentTokenRow = {
  code: string;
  device_name: string;
  expires_at: number;
  used_at: number | null;
  failed_attempts: number;
};

const enrollSchema = z.object({
  code: z.string().regex(/^[0-9a-f]{64}$/),
  keyAPem: z.string().min(64),
  keyBPem: z.string().min(64),
  deviceName: z.string().min(1).max(128),
});

const isLikelyPem = (value: string): boolean =>
  value.includes("BEGIN PUBLIC KEY") && value.includes("END PUBLIC KEY");

const incrementFailureCount = (code: string): void => {
  const current = sqlite
    .query("SELECT failed_attempts FROM enrollment_tokens WHERE code = ?")
    .get(code) as { failed_attempts: number } | null;

  if (!current) {
    return;
  }

  const next = current.failed_attempts + 1;
  if (next >= 5) {
    sqlite
      .prepare(
        "UPDATE enrollment_tokens SET failed_attempts = ?, used_at = COALESCE(used_at, ?) WHERE code = ?",
      )
      .run(next, Date.now(), code);
    return;
  }

  sqlite
    .prepare("UPDATE enrollment_tokens SET failed_attempts = ? WHERE code = ?")
    .run(next, code);
};

export const authRoutes = new Hono();

authRoutes.post("/enroll", async (c) => {
  const body = await c.req.json().catch(() => null);
  const parsed = enrollSchema.safeParse(body);

  if (!parsed.success) {
    return c.json({ error: "Invalid enroll payload" }, 400);
  }

  if (!isLikelyPem(parsed.data.keyAPem) || !isLikelyPem(parsed.data.keyBPem)) {
    incrementFailureCount(parsed.data.code);
    return c.json({ error: "Invalid PEM key format" }, 400);
  }

  const token = sqlite
    .query("SELECT * FROM enrollment_tokens WHERE code = ?")
    .get(parsed.data.code) as EnrollmentTokenRow | null;

  if (!token) {
    return c.json({ error: "Invalid enrollment code" }, 403);
  }

  const now = Date.now();

  if (token.used_at) {
    return c.json({ error: "Enrollment code already used" }, 403);
  }

  if (token.expires_at < now) {
    incrementFailureCount(token.code);
    return c.json({ error: "Enrollment code expired" }, 403);
  }

  if (token.failed_attempts >= 5) {
    return c.json({ error: "Enrollment code invalidated" }, 403);
  }

  const deviceId = crypto.randomUUID();
  sqlite
    .prepare(
      `
      INSERT INTO devices (id, name, key_a_pem, key_b_pem, enabled, created_at, last_seen_at)
      VALUES (?, ?, ?, ?, 1, ?, ?)
    `,
    )
    .run(deviceId, parsed.data.deviceName, parsed.data.keyAPem, parsed.data.keyBPem, now, now);

  sqlite
    .prepare("UPDATE enrollment_tokens SET used_at = ? WHERE code = ?")
    .run(now, parsed.data.code);

  return c.json({ deviceId, enrolledAt: now }, 201);
});
