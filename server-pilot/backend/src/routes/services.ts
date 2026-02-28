import { Hono } from "hono";
import { getServerById, getServiceByName } from "../config";
import { executeCommand } from "../services/serverContext";

const ACTIONS = new Set(["start", "stop", "restart"]);

export const servicesRoutes = new Hono();

servicesRoutes.get("/:id/services", async (c) => {
  const server = getServerById(c.req.param("id"));
  if (!server) {
    return c.json({ error: "Unknown server" }, 404);
  }

  const statuses = await Promise.all(
    server.services.map(async (service) => {
      try {
        const result = await executeCommand(server.id, ["systemctl", "is-active", service.systemdUnit], {
          allowNonZero: true,
          sudo: true,
          timeoutMs: 8000,
        });

        const active = result.stdout.trim() === "active";
        return {
          name: service.name,
          displayName: service.displayName,
          unit: service.systemdUnit,
          status: active ? "running" : "stopped",
          raw: result.stdout || result.stderr,
        };
      } catch (error) {
        return {
          name: service.name,
          displayName: service.displayName,
          unit: service.systemdUnit,
          status: "error",
          raw: error instanceof Error ? error.message : "unknown error",
        };
      }
    }),
  );

  return c.json({ services: statuses });
});

servicesRoutes.post("/:id/services/:name/:action", async (c) => {
  const server = getServerById(c.req.param("id"));
  if (!server) {
    return c.json({ error: "Unknown server" }, 404);
  }

  const action = c.req.param("action");
  if (!ACTIONS.has(action)) {
    return c.json({ error: "Invalid action" }, 400);
  }

  const service = getServiceByName(server, c.req.param("name"));
  if (!service) {
    return c.json({ error: "Unknown service" }, 404);
  }

  try {
    await executeCommand(server.id, ["systemctl", action, service.systemdUnit], {
      sudo: true,
      timeoutMs: 15000,
    });

    return c.json({
      ok: true,
      serverId: server.id,
      service: service.name,
      action,
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : "Service action failed";
    return c.json({ error: message }, 500);
  }
});
