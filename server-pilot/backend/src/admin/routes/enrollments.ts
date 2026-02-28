import { randomBytes } from "node:crypto";
import { Hono } from "hono";
import { z } from "zod";
import { sqlite } from "../../db";

const createEnrollmentSchema = z.object({
  deviceName: z.string().min(1).max(128),
});

export const adminEnrollmentsRoutes = new Hono();

adminEnrollmentsRoutes.post("/", async (c) => {
  const parsed = createEnrollmentSchema.safeParse(await c.req.json().catch(() => null));
  if (!parsed.success) {
    return c.json({ error: "Invalid payload" }, 400);
  }

  const code = randomBytes(32).toString("hex");
  const expiresAt = Date.now() + 10 * 60 * 1000;

  sqlite
    .prepare(
      `
      INSERT INTO enrollment_tokens (code, device_name, expires_at, used_at, failed_attempts)
      VALUES (?, ?, ?, NULL, 0)
    `,
    )
    .run(code, parsed.data.deviceName, expiresAt);

  return c.json({ code, expiresAt }, 201);
});

adminEnrollmentsRoutes.get("/", (c) => {
  const now = Date.now();
  const enrollments = sqlite
    .query(
      `
      SELECT code, device_name, expires_at, used_at, failed_attempts
      FROM enrollment_tokens
      ORDER BY expires_at DESC
    `,
    )
    .all() as Array<{
    code: string;
    device_name: string;
    expires_at: number;
    used_at: number | null;
    failed_attempts: number;
  }>;

  return c.json({
    enrollments: enrollments.map((enrollment) => {
      let status = "pending";
      if (enrollment.used_at) {
        status = enrollment.failed_attempts >= 5 ? "invalidated" : "used";
      } else if (enrollment.expires_at < now) {
        status = "expired";
      }

      return {
        code: enrollment.code,
        deviceName: enrollment.device_name,
        expiresAt: enrollment.expires_at,
        usedAt: enrollment.used_at,
        failedAttempts: enrollment.failed_attempts,
        status,
      };
    }),
  });
});

adminEnrollmentsRoutes.delete("/:code", (c) => {
  const result = sqlite
    .prepare("DELETE FROM enrollment_tokens WHERE code = ?")
    .run(c.req.param("code"));

  if (result.changes === 0) {
    return c.json({ error: "Enrollment token not found" }, 404);
  }

  return c.json({ ok: true });
});
