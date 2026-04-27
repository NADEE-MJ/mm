import { Hono } from "hono";
import { getServerById } from "../config";
import { executeCommand } from "../services/serverContext";

const POWER_ACTIONS = new Set(["restart", "shutdown"]);

export const powerRoutes = new Hono();

// POST /api/servers/:id/power/:action
// action: "restart" | "shutdown"
//
// Runs `shutdown -r now` (restart) or `shutdown -h now` (shutdown) on the
// target server. Both require passwordless sudo on the remote host.
powerRoutes.post("/:id/power/:action", async (c) => {
  const server = getServerById(c.req.param("id"));
  if (!server) {
    return c.json({ error: "Unknown server" }, 404);
  }

  const action = c.req.param("action");
  if (!POWER_ACTIONS.has(action)) {
    return c.json({ error: "Invalid action. Must be 'restart' or 'shutdown'" }, 400);
  }

  // shutdown flag: -r = reboot, -h = halt/power off
  const flag = action === "restart" ? "-r" : "-h";

  try {
    await executeCommand(server.id, ["shutdown", flag, "now"], {
      sudo: true,
      // The SSH connection will drop before shutdown completes, so we tolerate
      // non-zero exit codes and use a short timeout.
      allowNonZero: true,
      timeoutMs: 10000,
    });

    return c.json({ ok: true, serverId: server.id, action });
  } catch (error) {
    const message = error instanceof Error ? error.message : "Power action failed";
    return c.json({ error: message }, 500);
  }
});
