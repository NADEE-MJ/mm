import { Hono } from "hono";
import { scheduler } from "../services/scheduler";

export const jobsRoutes = new Hono();

jobsRoutes.get("/", (c) => c.json({ jobs: scheduler.listJobs() }));
