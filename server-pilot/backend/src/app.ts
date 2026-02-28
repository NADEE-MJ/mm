import { Hono } from "hono";
import { HTTPException } from "hono/http-exception";
import { authRoutes } from "./routes/auth";
import { serversRoutes } from "./routes/servers";
import { metricsRoutes } from "./routes/metrics";
import { servicesRoutes } from "./routes/services";
import { dockerRoutes } from "./routes/docker";
import { gitRoutes } from "./routes/git";
import { packagesRoutes } from "./routes/packages";
import { wolRoutes } from "./routes/wol";
import { sshRoutes } from "./routes/ssh";
import { jobsRoutes } from "./routes/jobs";
import { logsRoutes } from "./routes/logs";
import { loggerMiddleware } from "./middleware/logger";
import { deviceAuthMiddleware } from "./middleware/deviceAuth";
import type { AppVariables } from "./types";

const app = new Hono<{ Variables: AppVariables }>();

app.use("/api/*", loggerMiddleware);
app.use("/api/*", deviceAuthMiddleware);

app.get("/health", (c) => c.json({ ok: true }));
app.get("/api/health", (c) => c.json({ ok: true }));

app.route("/api/auth", authRoutes);
app.route("/api/servers", serversRoutes);
app.route("/api/servers", metricsRoutes);
app.route("/api/servers", servicesRoutes);
app.route("/api/servers", dockerRoutes);
app.route("/api/servers", gitRoutes);
app.route("/api/servers", packagesRoutes);
app.route("/api/servers", wolRoutes);
app.route("/api/servers", sshRoutes);
app.route("/api/servers", logsRoutes);
app.route("/api/jobs", jobsRoutes);

app.onError((error, c) => {
  if (error instanceof HTTPException) {
    return c.json({ error: error.message }, error.status);
  }

  console.error(error);
  return c.json({ error: "Internal server error" }, 500);
});

export default app;
