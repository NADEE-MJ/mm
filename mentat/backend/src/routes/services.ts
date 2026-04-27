import { Hono } from "hono";
import type { ServiceConfig } from "../config";
import { getServerById, getServiceByName } from "../config";
import { executeCommand } from "../services/serverContext";

const ACTIONS = new Set(["start", "stop", "restart"]);

export const servicesRoutes = new Hono();

// Build the shell command args for checking status of a service
const statusCommand = (service: ServiceConfig): string[] => {
  switch (service.serviceManager) {
    case "launchd": {
      // system domain: launchctl print system/<unit> (LaunchDaemon, no user context)
      // gui domain:    launchctl print gui/$(id -u)/<unit> (LaunchAgent, user session)
      const domain =
        service.launchdDomain === "system"
          ? `system/${service.systemdUnit}`
          : `gui/$(id -u)/${service.systemdUnit}`;
      return ["/bin/sh", "-c", `launchctl print ${domain}`];
    }
    case "brew":
      return ["brew", "services", "info", "--json", service.systemdUnit];
    default:
      return ["systemctl", "is-active", service.systemdUnit];
  }
};

// Build the shell command args for performing an action on a service
const actionCommand = (service: ServiceConfig, action: string): string[] => {
  switch (service.serviceManager) {
    case "launchd": {
      if (service.launchdDomain === "system") {
        // system LaunchDaemons: bootstrap/bootout use the plist path under /Library/LaunchDaemons/
        if (action === "start") {
          return ["/bin/sh", "-c", `launchctl bootstrap system /Library/LaunchDaemons/${service.systemdUnit}.plist`];
        }
        if (action === "stop") {
          return ["/bin/sh", "-c", `launchctl bootout system /Library/LaunchDaemons/${service.systemdUnit}.plist`];
        }
        // restart = kickstart -k system/<unit>
        return ["launchctl", "kickstart", "-k", `system/${service.systemdUnit}`];
      }
      // gui LaunchAgents: bootstrap/bootout use the plist path under ~/Library/LaunchAgents/
      if (action === "start") {
        return ["/bin/sh", "-c", `launchctl bootstrap gui/$(id -u) "$HOME/Library/LaunchAgents/${service.systemdUnit}.plist"`];
      }
      if (action === "stop") {
        return ["/bin/sh", "-c", `launchctl bootout gui/$(id -u) "$HOME/Library/LaunchAgents/${service.systemdUnit}.plist"`];
      }
      // restart = kickstart -k gui/<uid>/<unit>
      return ["/bin/sh", "-c", `launchctl kickstart -k gui/$(id -u)/${service.systemdUnit}`];
    }
    case "brew": {
      const brewAction = action === "restart" ? "restart" : action === "start" ? "start" : "stop";
      return ["brew", "services", brewAction, service.systemdUnit];
    }
    default:
      return ["systemctl", action, service.systemdUnit];
  }
};

// Parse whether a service is running from the command output
const parseIsRunning = (service: ServiceConfig, stdout: string, stderr: string): boolean => {
  switch (service.serviceManager) {
    case "launchd":
      // `launchctl print` output contains "state = running" when active
      return stdout.includes("state = running");
    case "brew": {
      // brew services info --json returns an array with a "running" boolean and a "status" string.
      // "status" is "started" only when brew itself manages the lifecycle; services started outside
      // brew (e.g. manually or via launchd directly) show status "none" even while the process is
      // alive. The "running" boolean reflects the actual process state regardless of how it started.
      try {
        const parsed = JSON.parse(stdout) as Array<{ running: boolean }>;
        return parsed[0]?.running === true;
      } catch {
        return stdout.includes('"running": true') || stdout.includes('"running":true');
      }
    }
    default:
      return (stdout + stderr).trim() === "active";
  }
};

servicesRoutes.get("/:id/services", async (c) => {
  const server = getServerById(c.req.param("id"));
  if (!server) {
    return c.json({ error: "Unknown server" }, 404);
  }

  const statuses = await Promise.all(
    server.services.map(async (service) => {
      try {
        const cmd = statusCommand(service);
        const result = await executeCommand(server.id, cmd, {
          allowNonZero: true,
          sudo: service.serviceManager === "systemd",
          timeoutMs: 8000,
        });

        const running = parseIsRunning(service, result.stdout, result.stderr);
        return {
          name: service.name,
          displayName: service.displayName,
          unit: service.systemdUnit,
          serviceManager: service.serviceManager,
          status: running ? "running" : "stopped",
          raw: result.stdout || result.stderr,
        };
      } catch (error) {
        return {
          name: service.name,
          displayName: service.displayName,
          unit: service.systemdUnit,
          serviceManager: service.serviceManager,
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
    const cmd = actionCommand(service, action);
    await executeCommand(server.id, cmd, {
      sudo: service.serviceManager === "systemd" || (service.serviceManager === "launchd" && service.launchdDomain === "system"),
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
