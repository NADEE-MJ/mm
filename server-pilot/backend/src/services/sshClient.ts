import { existsSync, readFileSync } from "node:fs";
import { Client } from "ssh2";
import type { ConnectConfig } from "ssh2";
import { appConfig, type RemoteServerConfig } from "../config";
import type { CommandResult } from "./processRunner";

export type SSHConnectionState = "connected" | "connecting" | "unreachable";

type ConnectionRecord = {
  server: RemoteServerConfig;
  state: SSHConnectionState;
  client: Client | null;
  attempts: number;
  reconnectTimer?: NodeJS.Timeout;
  connectPromise?: Promise<void>;
};

const jitterMultiplier = (): number => 0.8 + Math.random() * 0.4;

class SSHClientPool {
  private records = new Map<string, ConnectionRecord>();

  constructor(servers: RemoteServerConfig[]) {
    for (const server of servers) {
      this.records.set(server.id, {
        server,
        state: "unreachable",
        client: null,
        attempts: 0,
      });
    }
  }

  start(): void {
    for (const record of this.records.values()) {
      void this.connect(record);
    }
  }

  getState(serverId: string): SSHConnectionState {
    return this.records.get(serverId)?.state ?? "unreachable";
  }

  getStates(): Record<string, SSHConnectionState> {
    const output: Record<string, SSHConnectionState> = {};
    for (const [id, record] of this.records.entries()) {
      output[id] = record.state;
    }

    return output;
  }

  triggerImmediateReconnect(serverId: string): void {
    const record = this.records.get(serverId);
    if (!record) {
      return;
    }

    if (record.reconnectTimer) {
      clearTimeout(record.reconnectTimer);
      record.reconnectTimer = undefined;
    }

    record.attempts = 0;
    void this.connect(record);
  }

  async exec(serverId: string, command: string, timeoutMs = 15000): Promise<CommandResult> {
    const record = this.records.get(serverId);
    if (!record) {
      throw new Error(`Unknown remote server '${serverId}'`);
    }

    await this.ensureConnected(record);

    if (!record.client) {
      throw new Error(`SSH client unavailable for '${serverId}'`);
    }

    const startedAt = Date.now();

    return new Promise<CommandResult>((resolve, reject) => {
      const client = record.client;
      if (!client) {
        reject(new Error(`SSH client unavailable for '${serverId}'`));
        return;
      }

      const timeout = setTimeout(() => {
        record.state = "unreachable";
        this.scheduleReconnect(record);
        reject(new Error(`SSH command timed out on '${serverId}' after ${timeoutMs}ms`));
      }, timeoutMs);

      client.exec(command, (error, stream) => {
        if (error) {
          clearTimeout(timeout);
          record.state = "unreachable";
          this.scheduleReconnect(record);
          reject(error);
          return;
        }

        let stdout = "";
        let stderr = "";

        stream.on("data", (chunk: Buffer | string) => {
          stdout += chunk.toString();
        });

        stream.stderr.on("data", (chunk: Buffer | string) => {
          stderr += chunk.toString();
        });

        stream.on("close", (exitCode: number | null) => {
          clearTimeout(timeout);

          resolve({
            exitCode: exitCode ?? 0,
            stdout: stdout.trim(),
            stderr: stderr.trim(),
            durationMs: Date.now() - startedAt,
          });
        });
      });
    });
  }

  private async ensureConnected(record: ConnectionRecord): Promise<void> {
    if (record.state === "connected" && record.client) {
      return;
    }

    await this.connect(record);
  }

  private connect(record: ConnectionRecord): Promise<void> {
    if (record.connectPromise) {
      return record.connectPromise;
    }

    record.state = "connecting";

    if (record.client) {
      record.client.removeAllListeners();
      record.client.end();
      record.client = null;
    }

    const client = new Client();
    record.client = client;

    record.connectPromise = new Promise<void>((resolve, reject) => {
      let resolved = false;

      client.once("ready", () => {
        resolved = true;
        record.state = "connected";
        record.attempts = 0;
        record.connectPromise = undefined;
        resolve();
      });

      client.on("error", (error) => {
        if (!resolved) {
          record.connectPromise = undefined;
          reject(error);
        }
      });

      client.on("close", () => {
        record.state = "unreachable";
        record.connectPromise = undefined;
        this.scheduleReconnect(record);
      });

      const connectConfig = this.toConnectConfig(record.server);
      client.connect(connectConfig);
    }).catch((error) => {
      record.state = "unreachable";
      this.scheduleReconnect(record);
      throw error;
    });

    return record.connectPromise;
  }

  private scheduleReconnect(record: ConnectionRecord): void {
    if (record.reconnectTimer) {
      return;
    }

    const nextAttempt = record.attempts + 1;
    record.attempts = nextAttempt;

    const delay = Math.min(30000, 1000 * 2 ** Math.min(nextAttempt, 5));
    const jitteredDelay = Math.floor(delay * jitterMultiplier());

    record.reconnectTimer = setTimeout(() => {
      record.reconnectTimer = undefined;
      void this.connect(record);
    }, jitteredDelay);
  }

  private toConnectConfig(server: RemoteServerConfig): ConnectConfig {
    if (!existsSync(server.sshKeyPath)) {
      throw new Error(`Missing SSH key for ${server.id}: ${server.sshKeyPath}`);
    }

    return {
      host: server.host,
      port: server.port,
      username: server.user,
      privateKey: readFileSync(server.sshKeyPath),
      keepaliveInterval: 15000,
      keepaliveCountMax: 3,
      readyTimeout: 10000,
    };
  }
}

const remoteServers = appConfig.servers.filter(
  (server): server is RemoteServerConfig => server.type === "remote",
);

export const sshPool = new SSHClientPool(remoteServers);
