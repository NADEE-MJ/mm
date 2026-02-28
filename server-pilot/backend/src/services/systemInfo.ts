import os from "node:os";
import { getServerById } from "../config";
import { executeCommand } from "./serverContext";

export type SystemMetrics = {
  cpu: number;
  memory: number;
  disk: number;
  uptime: number;
  loadAvg: [number, number, number];
};

const parseDiskPercentFromDf = (output: string): number => {
  const lines = output.split(/\r?\n/).filter(Boolean);
  if (lines.length < 2) {
    return 0;
  }

  const parts = lines[1]?.trim().split(/\s+/) ?? [];
  const usePercent = parts.find((part) => part.endsWith("%"));
  if (!usePercent) {
    return 0;
  }

  const parsed = Number.parseFloat(usePercent.replace("%", ""));
  return Number.isFinite(parsed) ? parsed : 0;
};

const parseMemUsagePercentFromMemInfo = (output: string): number => {
  const lines = output.split(/\r?\n/);
  let total = 0;
  let available = 0;

  for (const line of lines) {
    if (line.startsWith("MemTotal:")) {
      total = Number.parseFloat(line.replace(/\D+/g, " ").trim().split(" ")[0] ?? "0");
    }

    if (line.startsWith("MemAvailable:")) {
      available = Number.parseFloat(line.replace(/\D+/g, " ").trim().split(" ")[0] ?? "0");
    }
  }

  if (total <= 0) {
    return 0;
  }

  return Math.max(0, Math.min(100, ((total - available) / total) * 100));
};

export const getServerMetrics = async (serverId: string): Promise<SystemMetrics> => {
  const server = getServerById(serverId);
  if (!server) {
    throw new Error(`Unknown server '${serverId}'`);
  }

  if (server.type === "local") {
    const load = os.loadavg();
    const cpus = os.cpus().length || 1;
    const cpuPercent = Math.max(0, Math.min(100, (load[0] / cpus) * 100));

    const totalMem = os.totalmem();
    const usedMem = totalMem - os.freemem();
    const memoryPercent = (usedMem / totalMem) * 100;

    const diskResult = await executeCommand(server.id, ["df", "-k", "/"], {
      allowNonZero: true,
      timeoutMs: 5000,
    });

    return {
      cpu: Number(cpuPercent.toFixed(1)),
      memory: Number(memoryPercent.toFixed(1)),
      disk: Number(parseDiskPercentFromDf(diskResult.stdout).toFixed(1)),
      uptime: Math.floor(os.uptime()),
      loadAvg: [load[0] ?? 0, load[1] ?? 0, load[2] ?? 0],
    };
  }

  const [loadAvgResult, memInfoResult, diskResult, uptimeResult, coresResult] = await Promise.all([
    executeCommand(serverId, ["cat", "/proc/loadavg"], { timeoutMs: 5000 }),
    executeCommand(serverId, ["cat", "/proc/meminfo"], { timeoutMs: 5000 }),
    executeCommand(serverId, ["df", "-k", "/"], { timeoutMs: 5000 }),
    executeCommand(serverId, ["cat", "/proc/uptime"], { timeoutMs: 5000 }),
    executeCommand(serverId, ["nproc"], { timeoutMs: 5000, allowNonZero: true }),
  ]);

  const loadParts = loadAvgResult.stdout.split(/\s+/).map((value) => Number.parseFloat(value));
  const cores = Math.max(1, Number.parseInt(coresResult.stdout.trim(), 10) || 1);
  const cpu = Math.max(0, Math.min(100, ((loadParts[0] ?? 0) / cores) * 100));

  const uptime = Math.floor(Number.parseFloat(uptimeResult.stdout.split(" ")[0] ?? "0"));

  return {
    cpu: Number(cpu.toFixed(1)),
    memory: Number(parseMemUsagePercentFromMemInfo(memInfoResult.stdout).toFixed(1)),
    disk: Number(parseDiskPercentFromDf(diskResult.stdout).toFixed(1)),
    uptime: Number.isFinite(uptime) ? uptime : 0,
    loadAvg: [loadParts[0] ?? 0, loadParts[1] ?? 0, loadParts[2] ?? 0],
  };
};
