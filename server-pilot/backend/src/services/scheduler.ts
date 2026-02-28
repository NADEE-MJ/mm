import cron from "node-cron";
import { sqlite } from "../db";
import { sendPushover } from "./pushover";
import { runCommand } from "./processRunner";

export type JobRecord = {
  id: string;
  command: string;
  schedule: string;
  enabled: boolean;
  createdAt: number;
  lastRunAt: number | null;
};

type PersistedJob = {
  id: string;
  command: string;
  schedule: string;
  enabled: number;
  created_at: number;
  last_run_at: number | null;
};

export type UpsertJobInput = {
  id: string;
  command: string;
  schedule: string;
  enabled?: boolean;
};

class JobScheduler {
  private tasks = new Map<string, ReturnType<typeof cron.schedule>>();

  start(): void {
    const rows = sqlite.query("SELECT * FROM jobs").all() as PersistedJob[];
    for (const row of rows) {
      this.attachJob(row);
    }
  }

  listJobs(): JobRecord[] {
    const rows = sqlite.query("SELECT * FROM jobs ORDER BY created_at DESC").all() as PersistedJob[];
    return rows.map((row) => this.toJobRecord(row));
  }

  upsertJob(input: UpsertJobInput): JobRecord {
    if (!cron.validate(input.schedule)) {
      throw new Error("Invalid cron schedule");
    }

    const now = Date.now();
    const enabled = input.enabled ?? true;

    sqlite
      .prepare(
        `
        INSERT INTO jobs (id, command, schedule, enabled, created_at, last_run_at)
        VALUES (?, ?, ?, ?, ?, NULL)
        ON CONFLICT(id) DO UPDATE SET
          command = excluded.command,
          schedule = excluded.schedule,
          enabled = excluded.enabled
      `,
      )
      .run(input.id, input.command, input.schedule, enabled ? 1 : 0, now);

    const row = sqlite.query("SELECT * FROM jobs WHERE id = ?").get(input.id) as PersistedJob;
    this.attachJob(row);
    return this.toJobRecord(row);
  }

  deleteJob(id: string): void {
    const task = this.tasks.get(id);
    if (task) {
      task.stop();
      this.tasks.delete(id);
    }

    sqlite.prepare("DELETE FROM jobs WHERE id = ?").run(id);
  }

  private attachJob(row: PersistedJob): void {
    const existing = this.tasks.get(row.id);
    if (existing) {
      existing.stop();
      this.tasks.delete(row.id);
    }

    if (!row.enabled) {
      return;
    }

    const task = cron.schedule(row.schedule, () => {
      void this.runJob(row.id, row.command);
    });

    this.tasks.set(row.id, task);
  }

  private async runJob(id: string, command: string): Promise<void> {
    try {
      const result = await runCommand(["/bin/zsh", "-lc", command], {
        timeoutMs: 120000,
        allowNonZero: true,
      });

      sqlite.prepare("UPDATE jobs SET last_run_at = ? WHERE id = ?").run(Date.now(), id);

      if (result.exitCode !== 0) {
        await sendPushover(
          "ServerPilot job failed",
          `Job '${id}' exited ${result.exitCode}: ${result.stderr || "no stderr"}`,
        );
      }
    } catch (error) {
      const message = error instanceof Error ? error.message : "unknown error";
      await sendPushover("ServerPilot job error", `Job '${id}' failed: ${message}`);
    }
  }

  private toJobRecord(row: PersistedJob): JobRecord {
    return {
      id: row.id,
      command: row.command,
      schedule: row.schedule,
      enabled: row.enabled === 1,
      createdAt: row.created_at,
      lastRunAt: row.last_run_at,
    };
  }
}

export const scheduler = new JobScheduler();
