import { Hono } from "hono";
import { HTTPException } from "hono/http-exception";
import { serversRoutes } from "./routes/servers";
import { metricsRoutes } from "./routes/metrics";
import { servicesRoutes } from "./routes/services";
import { dockerRoutes } from "./routes/docker";
import { gitRoutes } from "./routes/git";
import { packagesRoutes } from "./routes/packages";
import { wolRoutes } from "./routes/wol";
import { jobsRoutes } from "./routes/jobs";
import { powerRoutes } from "./routes/power";
import { appsRoutes } from "./routes/apps";
import { opencodeRoutes } from "./routes/opencode";
import { loggerMiddleware } from "./middleware/logger";

const app = new Hono();

app.use("/api/*", loggerMiddleware);

app.get("/health", (c) => c.json({ ok: true }));
app.get("/api/health", (c) => c.json({ ok: true }));

app.route("/api/servers", serversRoutes);
app.route("/api/servers", metricsRoutes);
app.route("/api/servers", servicesRoutes);
app.route("/api/servers", dockerRoutes);
app.route("/api/servers", gitRoutes);
app.route("/api/servers", packagesRoutes);
app.route("/api/servers", wolRoutes);
app.route("/api/servers", powerRoutes);
app.route("/api/apps", appsRoutes);
app.route("/api/opencode", opencodeRoutes);
app.route("/api/jobs", jobsRoutes);

app.onError((error, c) => {
  if (error instanceof HTTPException) {
    return c.json({ error: error.message }, error.status);
  }

  console.error(error);
  return c.json({ error: "Internal server error" }, 500);
});

export default app;
