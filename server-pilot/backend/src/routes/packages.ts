import { Hono } from "hono";
import { getServerById } from "../config";
import { sqlite } from "../db";

export const packagesRoutes = new Hono();

packagesRoutes.get("/:id/packages", (c) => {
  const server = getServerById(c.req.param("id"));
  if (!server) {
    return c.json({ error: "Unknown server" }, 404);
  }

  const state = sqlite.query("SELECT * FROM package_state ORDER BY id DESC LIMIT 1").get() as
    | { id: number; last_updated_at: number | null }
    | null;

  const now = Date.now();
  const lastUpdatedAt = state?.last_updated_at ?? null;
  const daysSinceUpdate =
    typeof lastUpdatedAt === "number"
      ? Number(((now - lastUpdatedAt) / (24 * 60 * 60 * 1000)).toFixed(1))
      : null;

  return c.json({
    serverId: server.id,
    lastUpdatedAt,
    daysSinceUpdate,
  });
});

packagesRoutes.post("/:id/packages/record", (c) => {
  const server = getServerById(c.req.param("id"));
  if (!server) {
    return c.json({ error: "Unknown server" }, 404);
  }

  const now = Date.now();
  const current = sqlite.query("SELECT id FROM package_state ORDER BY id DESC LIMIT 1").get() as
    | { id: number }
    | null;

  if (!current) {
    sqlite.prepare("INSERT INTO package_state (last_updated_at) VALUES (?)").run(now);
  } else {
    sqlite
      .prepare("UPDATE package_state SET last_updated_at = ? WHERE id = ?")
      .run(now, current.id);
  }

  return c.json({
    serverId: server.id,
    lastUpdatedAt: now,
    daysSinceUpdate: 0,
  });
});
