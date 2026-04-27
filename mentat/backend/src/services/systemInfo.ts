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

const getRemoteMacOSMetrics = async (serverId: string): Promise<SystemMetrics> => {
  // top -l 2 samples CPU twice; the second sample reflects real utilization over the interval.
  // All other commands run concurrently with top to avoid adding extra latency.
  const [topResult, loadAvgResult, memStatResult, diskResult, bootTimeResult, memSizeResult] = await Promise.all([
    executeCommand(serverId, ["top", "-l", "2", "-n", "0"], { timeoutMs: 10000, allowNonZero: true }),
    executeCommand(serverId, ["sysctl", "-n", "vm.loadavg"], { timeoutMs: 5000, allowNonZero: true }),
    executeCommand(serverId, ["vm_stat"], { timeoutMs: 5000, allowNonZero: true }),
    executeCommand(serverId, ["df", "-k", "/"], { timeoutMs: 5000, allowNonZero: true }),
    executeCommand(serverId, ["sysctl", "-n", "kern.boottime"], { timeoutMs: 5000, allowNonZero: true }),
    executeCommand(serverId, ["sysctl", "-n", "hw.memsize"], { timeoutMs: 5000, allowNonZero: true }),
  ]);

  // top -l 2 emits two "CPU usage: X% user, Y% sys, Z% idle" lines.
  // Use the second one — it represents utilization over the sampling interval,
  // not just the instantaneous snapshot at startup.
  const cpuLines = topResult.stdout.match(/^CPU usage:.*$/gm) ?? [];
  const cpuLine = cpuLines[1] ?? cpuLines[0] ?? "";
  const idleMatch = cpuLine.match(/([\d.]+)%\s+idle/);
  const idlePercent = idleMatch ? Number.parseFloat(idleMatch[1]) : 0;
  const cpu = Math.max(0, Math.min(100, 100 - idlePercent));

  // vm.loadavg returns "{ 1.44 1.43 1.38 }" — strip braces and parse
  const loadParts = loadAvgResult.stdout
    .replace(/[{}]/g, "")
    .trim()
    .split(/\s+/)
    .map((v) => Number.parseFloat(v));

  // vm_stat reports page counts.
  // Use hw.memsize (total physical bytes) as the denominator and derive page size
  // from "Mach Virtual Memory Statistics: (page size of N bytes)".
  // This avoids undercounting total pages — vm_stat omits compressor pages from
  // its category totals, making a pure-page-count denominator too small.
  const pageSizeMatch = memStatResult.stdout.match(/page size of (\d+) bytes/);
  const pageSize = Number.parseInt(pageSizeMatch?.[1] ?? "16384", 10) || 16384;

  const totalMemBytes = Number.parseInt(memSizeResult.stdout.trim(), 10) || 0;

  const getPages = (label: string): number => {
    const match = memStatResult.stdout.match(new RegExp(`${label}[^:]*:\\s+(\\d+)`));
    return Number.parseInt(match?.[1] ?? "0", 10);
  };
  const anonymousPages = getPages("Anonymous pages");
  const wiredPages = getPages("Pages wired down");
  const compressedPages = getPages("Pages occupied by compressor");
  // Matches Activity Monitor's "Used" definition:
  //   App Memory   = Anonymous pages (non-file-backed allocations — active + inactive anon)
  //   Wired Memory = kernel/always-resident pages
  //   Compressed   = pages occupied by compressor (already-shrunk representation)
  // File-backed active/inactive pages are "Cached Files" — reclaimable, not pressure.
  const usedBytes = (anonymousPages + wiredPages + compressedPages) * pageSize;
  const memory =
    totalMemBytes > 0 ? Math.max(0, Math.min(100, (usedBytes / totalMemBytes) * 100)) : 0;

  // kern.boottime returns "{ sec = 1234567890, usec = 123456 } ..." — extract sec
  const bootSecMatch = bootTimeResult.stdout.match(/sec\s*=\s*(\d+)/);
  const bootSec = Number.parseInt(bootSecMatch?.[1] ?? "0", 10);
  const uptime = bootSec > 0 ? Math.floor(Date.now() / 1000) - bootSec : 0;

  return {
    cpu: Number(cpu.toFixed(1)),
    memory: Number(memory.toFixed(1)),
    disk: Number(parseDiskPercentFromDf(diskResult.stdout).toFixed(1)),
    uptime,
    loadAvg: [loadParts[0] ?? 0, loadParts[1] ?? 0, loadParts[2] ?? 0],
  };
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

  const unameResult = await executeCommand(serverId, ["uname", "-s"], {
    timeoutMs: 5000,
    allowNonZero: true,
  });
  const isDarwin = unameResult.stdout.trim() === "Darwin";

  if (isDarwin) {
    return await getRemoteMacOSMetrics(serverId);
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
