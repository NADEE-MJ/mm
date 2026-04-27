import Dockerode from "dockerode";
import type { LocalServerConfig } from "../config";
import { getServerById } from "../config";
import { executeCommand } from "./serverContext";

export type ContainerInfo = {
  id: string;
  name: string;
  image: string;
  state: string;
  status: string;
};

const getDockerClient = (server: LocalServerConfig): Dockerode => {
  if (server.dockerSocket) {
    return new Dockerode({ socketPath: server.dockerSocket });
  }
  return new Dockerode();
};

export const listContainers = async (serverId: string, all = true): Promise<ContainerInfo[]> => {
  const server = getServerById(serverId);
  if (!server) {
    throw new Error(`Unknown server '${serverId}'`);
  }

  if (server.type === "local") {
    const docker = getDockerClient(server);
    const containers = await docker.listContainers({ all });
    return containers.map((container: Dockerode.ContainerInfo) => ({
      id: container.Id,
      name: container.Names?.[0]?.replace(/^\//, "") ?? container.Id,
      image: container.Image,
      state: container.State,
      status: container.Status,
    }));
  }

  const allFlag = all ? "-a" : "";
  const result = await executeCommand(serverId, [
    "/bin/sh",
    "-lc",
    `docker ps ${allFlag} --format '{{json .}}'`,
  ]);

  return result.stdout
    .split(/\r?\n/)
    .filter(Boolean)
    .flatMap((line) => {
      try {
        const entry = JSON.parse(line) as Record<string, string>;
        return [{
          id: entry.ID ?? "",
          name: entry.Names ?? entry.ID ?? "unknown",
          image: entry.Image ?? "",
          state: entry.State ?? "unknown",
          status: entry.Status ?? "unknown",
        }];
      } catch {
        return [];
      }
    });
};

/**
 * Docker log streams use an 8-byte multiplexed frame header:
 *   byte 0:   stream type (0=stdin, 1=stdout, 2=stderr)
 *   bytes 1-3: padding (zero)
 *   bytes 4-7: payload size (big-endian uint32)
 * This strips the headers and returns the plain text payload.
 */
const demuxDockerLogs = (buf: Buffer): string => {
  const lines: string[] = [];
  let offset = 0;
  while (offset + 8 <= buf.length) {
    const size = buf.readUInt32BE(offset + 4);
    const end = offset + 8 + size;
    if (end > buf.length) break;
    lines.push(buf.subarray(offset + 8, end).toString("utf8"));
    offset = end;
  }
  // Fallback: if nothing was parsed (e.g. TTY-mode container), return raw text
  return lines.length > 0 ? lines.join("") : buf.toString("utf8");
};

export const getContainerLogs = async (
  serverId: string,
  containerId: string,
  lines = 100,
): Promise<string> => {
  const server = getServerById(serverId);
  if (!server) {
    throw new Error(`Unknown server '${serverId}'`);
  }

  if (server.type === "local") {
    const docker = getDockerClient(server);
    const container = docker.getContainer(containerId);
    const logs = await container.logs({
      stdout: true,
      stderr: true,
      tail: lines,
      timestamps: false,
      follow: false,
    });

    return Buffer.isBuffer(logs) ? demuxDockerLogs(logs) : String(logs);
  }

  const result = await executeCommand(serverId, [
    "docker",
    "logs",
    "--tail",
    String(lines),
    containerId,
  ], {
    allowNonZero: true,
  });

  return [result.stdout, result.stderr].filter(Boolean).join("\n").trim();
};

export const runContainerAction = async (
  serverId: string,
  containerId: string,
  action: "start" | "stop" | "restart",
): Promise<void> => {
  const server = getServerById(serverId);
  if (!server) {
    throw new Error(`Unknown server '${serverId}'`);
  }

  if (server.type === "local") {
    const docker = getDockerClient(server);
    const container = docker.getContainer(containerId);
    if (action === "start") {
      await container.start();
      return;
    }

    if (action === "stop") {
      await container.stop();
      return;
    }

    await container.restart();
    return;
  }

  await executeCommand(serverId, ["docker", action, containerId]);
};
