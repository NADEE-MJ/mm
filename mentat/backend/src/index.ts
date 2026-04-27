import { loadEnv } from "./env";

loadEnv();

import app from "./app";
import { appConfig } from "./config";
import { startAlertMonitor } from "./services/alertMonitor";
import { scheduler } from "./services/scheduler";
import { sshPool } from "./services/sshClient";
import { opencodeProcess } from "./services/opencodeProcess";
import { upgradeMetricsWS, wsHandlers } from "./routes/ws";

if (import.meta.main) {
  scheduler.start();
  sshPool.start();
  startAlertMonitor();
  opencodeProcess.start();

  // Bind to localhost only — the server is intentionally not accessible from
  // the network. Access is provided exclusively via SSH port-forwarding.
  let server: ReturnType<typeof Bun.serve>;
  server = Bun.serve({
    hostname: "127.0.0.1",
    port: appConfig.API_PORT,
    websocket: wsHandlers,
    fetch(req): Response | Promise<Response> | undefined {
      const url = new URL(req.url);
      // WebSocket upgrade paths are handled before the Hono app.
      // upgradeMetricsWS returns null when upgrade succeeds (Bun handles the
      // response internally), or a Response on failure.
      if (url.pathname.startsWith("/api/ws/")) {
        return upgradeMetricsWS(req, server) ?? undefined;
      }
      return app.fetch(req);
    },
  });

  console.log(`API listening on http://127.0.0.1:${appConfig.API_PORT}`);
}

export default app;
