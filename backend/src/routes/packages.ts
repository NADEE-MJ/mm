import { Hono } from "hono";
import { desc, eq } from "drizzle-orm";
import { getServerById } from "../config";
import { db } from "../db";
import { packageState } from "../db/schema";

export const packagesRoutes = new Hono();

packagesRoutes.get("/:id/packages", (c) => {
  const server = getServerById(c.req.param("id"));
  if (!server) {
    return c.json({ error: "Unknown server" }, 404);
  }

  const state = db
    .select()
    .from(packageState)
    .orderBy(desc(packageState.id))
    .limit(1)
    .get();

  const now = Date.now();
  const lastUpdatedAt = state?.lastUpdatedAt?.getTime() ?? null;
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

  const now = new Date();
  const current = db
    .select({ id: packageState.id })
    .from(packageState)
    .orderBy(desc(packageState.id))
    .limit(1)
    .get();

  if (!current) {
    db.insert(packageState).values({ lastUpdatedAt: now }).run();
  } else {
    db.update(packageState)
      .set({ lastUpdatedAt: now })
      .where(eq(packageState.id, current.id))
      .run();
  }

  return c.json({
    serverId: server.id,
    lastUpdatedAt: now.getTime(),
    daysSinceUpdate: 0,
  });
});
