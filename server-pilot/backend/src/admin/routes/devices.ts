import { Hono } from "hono";
import { z } from "zod";
import { sqlite } from "../../db";

const patchSchema = z.object({
  enabled: z.boolean(),
});

export const adminDevicesRoutes = new Hono();

adminDevicesRoutes.get("/", (c) => {
  const devices = sqlite
    .query(
      `
      SELECT id, name, enabled, created_at, last_seen_at
      FROM devices
      ORDER BY created_at DESC
    `,
    )
    .all() as Array<{
    id: string;
    name: string;
    enabled: number;
    created_at: number;
    last_seen_at: number | null;
  }>;

  return c.json({
    devices: devices.map((device) => ({
      id: device.id,
      name: device.name,
      enabled: device.enabled === 1,
      createdAt: device.created_at,
      lastSeenAt: device.last_seen_at,
    })),
  });
});

adminDevicesRoutes.patch("/:id", async (c) => {
  const parsed = patchSchema.safeParse(await c.req.json().catch(() => null));
  if (!parsed.success) {
    return c.json({ error: "Invalid payload" }, 400);
  }

  const result = sqlite
    .prepare("UPDATE devices SET enabled = ? WHERE id = ?")
    .run(parsed.data.enabled ? 1 : 0, c.req.param("id"));

  if (result.changes === 0) {
    return c.json({ error: "Device not found" }, 404);
  }

  return c.json({ ok: true });
});

adminDevicesRoutes.delete("/:id", (c) => {
  const id = c.req.param("id");

  sqlite.prepare("DELETE FROM idempotency_cache WHERE device_id = ?").run(id);
  sqlite.prepare("DELETE FROM seen_nonces WHERE device_id = ?").run(id);
  const result = sqlite.prepare("DELETE FROM devices WHERE id = ?").run(id);

  if (result.changes === 0) {
    return c.json({ error: "Device not found" }, 404);
  }

  return c.json({ ok: true });
});
