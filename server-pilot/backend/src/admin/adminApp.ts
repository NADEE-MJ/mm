import { Hono } from "hono";
import { HTTPException } from "hono/http-exception";
import { appConfig } from "../config";
import { loggerMiddleware } from "../middleware/logger";
import { adminAuditRoutes } from "./routes/audit";
import { adminDevicesRoutes } from "./routes/devices";
import { adminEnrollmentsRoutes } from "./routes/enrollments";

const adminApp = new Hono();

adminApp.use("*", loggerMiddleware);
adminApp.use("*", async (c, next) => {
  if (c.req.path === "/health") {
    return next();
  }

  const bearer = c.req.header("authorization")?.replace(/^Bearer\s+/i, "").trim();
  const token = c.req.header("x-admin-token") ?? bearer;

  if (!token || token !== appConfig.ADMIN_TOKEN) {
    throw new HTTPException(401, { message: "Unauthorized" });
  }

  return next();
});

adminApp.get("/health", (c) => c.json({ ok: true }));
adminApp.route("/devices", adminDevicesRoutes);
adminApp.route("/enrollments", adminEnrollmentsRoutes);
adminApp.route("/audit-log", adminAuditRoutes);

adminApp.onError((error, c) => {
  if (error instanceof HTTPException) {
    return c.json({ error: error.message }, error.status);
  }

  console.error(error);
  return c.json({ error: "Internal server error" }, 500);
});

export default adminApp;
