import { getOpencodeServer } from "../config";

const OPENCODE_PORT = 4096;
const MAX_BACKOFF_MS = 30_000;

const jitter = (): number => 0.8 + Math.random() * 0.4;

class OpenCodeProcessManager {
  private proc: ReturnType<typeof Bun.spawn> | null = null;
  private restartTimer: NodeJS.Timeout | undefined = undefined;
  private attempts = 0;
  private stopped = false;

  get isRunning(): boolean {
    return this.proc !== null;
  }

  get port(): number {
    return OPENCODE_PORT;
  }

  start(): void {
    let server: ReturnType<typeof getOpencodeServer>;
    try {
      server = getOpencodeServer();
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      console.error(`[opencode] Cannot start — ${message}`);
      return;
    }

    if (!server) {
      // opencodeServerId not configured; silently skip.
      return;
    }

    this.stopped = false;
    void this.spawn();
  }

  stop(): void {
    this.stopped = true;
    if (this.restartTimer) {
      clearTimeout(this.restartTimer);
      this.restartTimer = undefined;
    }
    if (this.proc) {
      try {
        this.proc.kill();
      } catch {
        // Already dead — ignore.
      }
      this.proc = null;
    }
    console.log("[opencode] Process stopped.");
  }

  private async spawn(): Promise<void> {
    if (this.stopped) {
      return;
    }

    console.log("[opencode] Starting `opencode serve`…");

    let proc: ReturnType<typeof Bun.spawn>;
    try {
      proc = Bun.spawn(["opencode", "serve"], {
        stdout: "pipe",
        stderr: "pipe",
        // Inherit the current environment so opencode can find its config,
        // API keys, etc.
        env: process.env as Record<string, string>,
      });
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      console.error(`[opencode] Failed to spawn process: ${message}`);
      this.scheduleRestart();
      return;
    }

    this.proc = proc;
    this.attempts = 0;

    // Drain stdout/stderr in the background — required so the pipe buffer
    // never fills up and stalls the child process.
    const stdout = proc.stdout instanceof ReadableStream ? proc.stdout : null;
    const stderr = proc.stderr instanceof ReadableStream ? proc.stderr : null;
    void this.drain(stdout, "stdout");
    void this.drain(stderr, "stderr");

    // Wait for the process to exit.
    const exitCode = await proc.exited;
    this.proc = null;

    if (this.stopped) {
      return;
    }

    console.warn(`[opencode] Process exited with code ${exitCode}. Scheduling restart…`);
    this.scheduleRestart();
  }

  private async drain(
    stream: ReadableStream<Uint8Array> | null,
    label: "stdout" | "stderr",
  ): Promise<void> {
    if (!stream) {
      return;
    }

    const reader = stream.getReader();
    const decoder = new TextDecoder();
    let buf = "";

    try {
      while (true) {
        const { done, value } = await reader.read();
        if (done) {
          break;
        }
        buf += decoder.decode(value, { stream: true });
        const lines = buf.split("\n");
        // Keep the last (potentially incomplete) line in the buffer.
        buf = lines.pop() ?? "";
        for (const line of lines) {
          if (line.trim()) {
            console.log(`[opencode:${label}] ${line}`);
          }
        }
      }
      // Flush any remaining content.
      if (buf.trim()) {
        console.log(`[opencode:${label}] ${buf}`);
      }
    } catch {
      // Stream closed — nothing to do.
    }
  }

  private scheduleRestart(): void {
    if (this.stopped || this.restartTimer) {
      return;
    }

    this.attempts += 1;
    const delay = Math.floor(
      Math.min(MAX_BACKOFF_MS, 1000 * 2 ** Math.min(this.attempts, 5)) * jitter(),
    );

    console.log(`[opencode] Restarting in ${delay}ms (attempt ${this.attempts})…`);

    this.restartTimer = setTimeout(() => {
      this.restartTimer = undefined;
      void this.spawn();
    }, delay);
  }
}

export const opencodeProcess = new OpenCodeProcessManager();
