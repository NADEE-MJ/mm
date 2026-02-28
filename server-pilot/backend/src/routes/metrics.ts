import { Hono } from "hono";
import { getServerById } from "../config";
import { getServerMetrics } from "../services/systemInfo";

export const metricsRoutes = new Hono();

metricsRoutes.get("/:id/metrics", async (c) => {
  const id = c.req.param("id");
  if (!getServerById(id)) {
    return c.json({ error: "Unknown server" }, 404);
  }

  try {
    const metrics = await getServerMetrics(id);
    return c.json(metrics);
  } catch (error) {
    const message = error instanceof Error ? error.message : "Failed to get metrics";
    return c.json({ error: message }, 500);
  }
});
