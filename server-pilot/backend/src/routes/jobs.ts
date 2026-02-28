import { Hono } from "hono";
import { z } from "zod";
import { scheduler } from "../services/scheduler";

const createJobSchema = z.object({
  id: z.string().min(1).max(128),
  command: z.string().min(1).max(5000),
  schedule: z.string().min(1).max(128),
  enabled: z.boolean().optional(),
});

export const jobsRoutes = new Hono();

jobsRoutes.get("/", (c) => c.json({ jobs: scheduler.listJobs() }));

jobsRoutes.post("/", async (c) => {
  const parsed = createJobSchema.safeParse(await c.req.json().catch(() => null));
  if (!parsed.success) {
    return c.json({ error: "Invalid payload" }, 400);
  }

  try {
    const job = scheduler.upsertJob(parsed.data);
    return c.json({ job }, 201);
  } catch (error) {
    const message = error instanceof Error ? error.message : "Failed to save job";
    return c.json({ error: message }, 400);
  }
});

jobsRoutes.delete("/:id", (c) => {
  scheduler.deleteJob(c.req.param("id"));
  return c.json({ ok: true });
});
