import { appConfig } from "../config";
import { getServerMetrics } from "./systemInfo";
import { sendPushover } from "./pushover";

const ALERT_COOLDOWN_MS = 10 * 60 * 1000;
const cooldownMap = new Map<string, number>();

const shouldSend = (key: string): boolean => {
  const now = Date.now();
  const last = cooldownMap.get(key) ?? 0;
  if (now - last < ALERT_COOLDOWN_MS) {
    return false;
  }

  cooldownMap.set(key, now);
  return true;
};

const checkOneServer = async (serverId: string): Promise<void> => {
  try {
    const metrics = await getServerMetrics(serverId);

    if (
      metrics.cpu >= appConfig.alerts.cpuThreshold &&
      shouldSend(`${serverId}:cpu`)
    ) {
      await sendPushover(
        "Mentat CPU alert",
        `${serverId} CPU at ${metrics.cpu.toFixed(1)}% (threshold ${appConfig.alerts.cpuThreshold}%)`,
      );
    }

    if (
      metrics.memory >= appConfig.alerts.memoryThreshold &&
      shouldSend(`${serverId}:memory`)
    ) {
      await sendPushover(
        "Mentat memory alert",
        `${serverId} memory at ${metrics.memory.toFixed(1)}% (threshold ${appConfig.alerts.memoryThreshold}%)`,
      );
    }

    if (
      metrics.disk >= appConfig.alerts.diskThreshold &&
      shouldSend(`${serverId}:disk`)
    ) {
      await sendPushover(
        "Mentat disk alert",
        `${serverId} disk at ${metrics.disk.toFixed(1)}% (threshold ${appConfig.alerts.diskThreshold}%)`,
      );
    }
  } catch (error) {
    // Monitoring is best-effort and should not crash the process.
    const message = error instanceof Error ? error.message : "unknown error";
    console.warn(`[alertMonitor] Error checking server '${serverId}': ${message}`);
  }
};

export const startAlertMonitor = (): void => {
  setInterval(() => {
    for (const server of appConfig.servers) {
      void checkOneServer(server.id);
    }
  }, 60_000);
};
