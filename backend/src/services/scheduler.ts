import cron from "node-cron";
import { appConfig, type JobConfig } from "../config";
import { db } from "../db";
import { jobs } from "../db/schema";
import { sendPushover } from "./pushover";
import { runCommand } from "./processRunner";

export type JobStatus = {
  id: string;
  serverId: string;
  command: string;
  schedule: string;
  enabled: boolean;
  lastRunAt: number | null;
};

type LastRunRow = {
  id: string;
  lastRunAt: Date | null;
};

class JobScheduler {
  private tasks = new Map<string, ReturnType<typeof cron.schedule>>();

  start(): void {
    for (const server of appConfig.servers) {
      for (const job of server.jobs) {
        this.attachJob(server.id, job);
      }
    }
  }

  listJobs(): JobStatus[] {
    const rows = db.select().from(jobs).all() as LastRunRow[];
    const lastRunMap = new Map<string, number | null>(
      rows.map((r) => [r.id, r.lastRunAt?.getTime() ?? null]),
    );

    const result: JobStatus[] = [];
    for (const server of appConfig.servers) {
      for (const job of server.jobs) {
        result.push({
          id: job.id,
          serverId: server.id,
          command: job.command,
          schedule: job.schedule,
          enabled: job.enabled,
          lastRunAt: lastRunMap.get(job.id) ?? null,
        });
      }
    }

    return result;
  }

  private attachJob(serverId: string, job: JobConfig): void {
    const existing = this.tasks.get(job.id);
    if (existing) {
      existing.stop();
      this.tasks.delete(job.id);
    }

    if (!job.enabled) {
      return;
    }

    if (!cron.validate(job.schedule)) {
      console.error(`[scheduler] Invalid cron schedule for job '${job.id}': ${job.schedule}`);
      return;
    }

    const task = cron.schedule(job.schedule, () => {
      void this.runJob(serverId, job.id, job.command);
    });

    this.tasks.set(job.id, task);
  }

  private async runJob(serverId: string, id: string, command: string): Promise<void> {
    try {
      const result = await runCommand(["/bin/sh", "-c", command], {
        timeoutMs: 120000,
        allowNonZero: true,
      });

      db.insert(jobs)
        .values({ id, lastRunAt: new Date() })
        .onConflictDoUpdate({ target: jobs.id, set: { lastRunAt: new Date() } })
        .run();

      if (result.exitCode !== 0) {
        try {
          await sendPushover(
            "Mentat job failed",
            `Job '${id}' on '${serverId}' exited ${result.exitCode}: ${result.stderr || "no stderr"}`,
          );
        } catch (pushErr) {
          const msg = pushErr instanceof Error ? pushErr.message : "unknown error";
          console.warn(`[scheduler] Failed to send Pushover alert for job '${id}': ${msg}`);
        }
      }
    } catch (error) {
      const message = error instanceof Error ? error.message : "unknown error";
      try {
        await sendPushover("Mentat job error", `Job '${id}' on '${serverId}' failed: ${message}`);
      } catch (pushErr) {
        const msg = pushErr instanceof Error ? pushErr.message : "unknown error";
        console.warn(`[scheduler] Failed to send Pushover error alert for job '${id}': ${msg}`);
      }
    }
  }
}

export const scheduler = new JobScheduler();
