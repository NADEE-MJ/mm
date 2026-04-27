import { Hono } from "hono";
import { getServerById } from "../config";
import { getContainerLogs, listContainers, runContainerAction } from "../services/docker";

const ACTIONS = new Set(["start", "stop", "restart"]);
const CONTAINER_ID_PATTERN = /^[A-Za-z0-9_.-]+$/;
const MAX_LOG_LINES = 1000;

const validateContainerId = (containerId: string): boolean =>
  CONTAINER_ID_PATTERN.test(containerId);

export const dockerRoutes = new Hono();

dockerRoutes.get("/:id/docker/containers", async (c) => {
  const serverId = c.req.param("id");
  if (!getServerById(serverId)) {
    return c.json({ error: "Unknown server" }, 404);
  }

  const all = c.req.query("all") !== "false";

  try {
    const containers = await listContainers(serverId, all);
    return c.json({ containers });
  } catch (error) {
    const message = error instanceof Error ? error.message : "Failed to list containers";
    return c.json({ error: message }, 500);
  }
});

dockerRoutes.get("/:id/docker/:containerId/logs", async (c) => {
  const serverId = c.req.param("id");
  if (!getServerById(serverId)) {
    return c.json({ error: "Unknown server" }, 404);
  }

  const containerId = c.req.param("containerId");
  if (!validateContainerId(containerId)) {
    return c.json({ error: "Invalid container id" }, 400);
  }

  const rawLines = Number.parseInt(c.req.query("lines") ?? "100", 10);
  const lines = Number.isFinite(rawLines) ? Math.min(Math.max(1, rawLines), MAX_LOG_LINES) : 100;

  try {
    const logs = await getContainerLogs(serverId, containerId, lines);
    return c.json({ logs });
  } catch (error) {
    const message = error instanceof Error ? error.message : "Failed to fetch logs";
    return c.json({ error: message }, 500);
  }
});

dockerRoutes.post("/:id/docker/:containerId/:action", async (c) => {
  const serverId = c.req.param("id");
  if (!getServerById(serverId)) {
    return c.json({ error: "Unknown server" }, 404);
  }

  const containerId = c.req.param("containerId");
  if (!validateContainerId(containerId)) {
    return c.json({ error: "Invalid container id" }, 400);
  }

  const action = c.req.param("action") as "start" | "stop" | "restart";
  if (!ACTIONS.has(action)) {
    return c.json({ error: "Invalid action" }, 400);
  }

  try {
    await runContainerAction(serverId, containerId, action);
    return c.json({ ok: true, action });
  } catch (error) {
    const message = error instanceof Error ? error.message : "Failed to manage container";
    return c.json({ error: message }, 500);
  }
});
