import Dockerode from "dockerode";
import { getServerById } from "../config";
import { executeCommand } from "./serverContext";

export type ContainerInfo = {
  id: string;
  name: string;
  image: string;
  state: string;
  status: string;
};

const docker = new Dockerode();
const CONTAINER_ID_PATTERN = /^[A-Za-z0-9_.-]+$/;

const assertContainerId = (containerId: string): void => {
  if (!CONTAINER_ID_PATTERN.test(containerId)) {
    throw new Error("Invalid container id");
  }
};

export const listContainers = async (serverId: string, all = true): Promise<ContainerInfo[]> => {
  const server = getServerById(serverId);
  if (!server) {
    throw new Error(`Unknown server '${serverId}'`);
  }

  if (server.type === "local") {
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
    .map((line) => JSON.parse(line) as Record<string, string>)
    .map((entry) => ({
      id: entry.ID ?? "",
      name: entry.Names ?? entry.ID ?? "unknown",
      image: entry.Image ?? "",
      state: entry.State ?? "unknown",
      status: entry.Status ?? "unknown",
    }));
};

export const getContainerLogs = async (
  serverId: string,
  containerId: string,
  lines = 100,
): Promise<string> => {
  assertContainerId(containerId);

  const server = getServerById(serverId);
  if (!server) {
    throw new Error(`Unknown server '${serverId}'`);
  }

  if (server.type === "local") {
    const container = docker.getContainer(containerId);
    const logs = await container.logs({
      stdout: true,
      stderr: true,
      tail: lines,
      timestamps: false,
      follow: false,
    });

    return Buffer.isBuffer(logs) ? logs.toString("utf8") : String(logs);
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
  assertContainerId(containerId);

  const server = getServerById(serverId);
  if (!server) {
    throw new Error(`Unknown server '${serverId}'`);
  }

  if (server.type === "local") {
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
