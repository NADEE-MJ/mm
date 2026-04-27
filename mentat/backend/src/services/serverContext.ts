import { getServerById, type ServerConfig } from "../config";
import { runCommand, type CommandResult } from "./processRunner";
import { sshPool } from "./sshClient";


export type ExecuteOptions = {
  timeoutMs?: number;
  allowNonZero?: boolean;
  sudo?: boolean;
  cwd?: string;
};

const shellEscape = (value: string): string => `'${value.replace(/'/g, `'\\''`)}'`;

const buildRemoteCommand = (args: string[], sudo: boolean): string => {
  const safe = args.map(shellEscape).join(" ");
  if (!sudo) {
    return safe;
  }

  return `sudo -n ${safe}`;
};

export const requireServer = (serverId: string): ServerConfig => {
  const server = getServerById(serverId);
  if (!server) {
    throw new Error(`Unknown server '${serverId}'`);
  }

  return server;
};

export const executeCommand = async (
  serverId: string,
  args: string[],
  options: ExecuteOptions = {},
): Promise<CommandResult> => {
  const server = requireServer(serverId);
  const allowNonZero = options.allowNonZero ?? false;

  if (server.type === "local") {
    const localArgs = options.sudo ? ["sudo", "-n", ...args] : args;
    return runCommand(localArgs, {
      allowNonZero,
      timeoutMs: options.timeoutMs,
      cwd: options.cwd,
    });
  }

  const command = buildRemoteCommand(args, options.sudo ?? false);
  const result = await sshPool.exec(server.id, command, options.timeoutMs);

  if (!allowNonZero && result.exitCode !== 0) {
    throw new Error(
      `Remote command failed (${result.exitCode}) on ${server.id}: ${command}${
        result.stderr ? `\n${result.stderr}` : ""
      }`,
    );
  }

  return result;
};
