import { loadEnv } from "./env";

loadEnv();

import app from "./app";
import adminApp from "./admin/adminApp";
import { appConfig } from "./config";
import { startAlertMonitor } from "./services/alertMonitor";
import { scheduler } from "./services/scheduler";
import { sshPool } from "./services/sshClient";

if (import.meta.main) {
  scheduler.start();
  sshPool.start();
  startAlertMonitor();

  Bun.serve({
    hostname: appConfig.API_HOST,
    port: appConfig.API_PORT,
    fetch: app.fetch,
  });

  Bun.serve({
    hostname: "127.0.0.1",
    port: appConfig.ADMIN_PORT,
    fetch: adminApp.fetch,
  });

  console.log(`API listening on http://${appConfig.API_HOST}:${appConfig.API_PORT}`);
  console.log(`Admin listening on http://127.0.0.1:${appConfig.ADMIN_PORT}`);
}

export default app;
