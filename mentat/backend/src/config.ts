import { existsSync, readFileSync } from "node:fs";
import cron from "node-cron";
import { z } from "zod";
import { loadEnv } from "./env";
import { resolveProjectRelativePath } from "./utils";

loadEnv();

const envSchema = z.object({
  API_PORT: z.coerce.number().int().min(1).max(65535).default(4310),
  DATABASE_PATH: z.string().default("./data/server-pilot.db"),
  SERVERS_CONFIG_PATH: z.string().default("./config/servers.json"),
  PUSHOVER_USER_KEY: z.string().optional(),
  PUSHOVER_API_TOKEN: z.string().optional(),
  // CopyParty instance used to generate time-limited IPA download links.
  // COPYPARTY_URL  — base URL of the CopyParty server, e.g. http://192.168.1.50:3923
  // COPYPARTY_PATH — the CopyParty virtual-folder path where IPAs live, e.g. /ipabuilds
  // COPYPARTY_PASSWORD — password for the CopyParty account that creates shares (optional if the
  //                      volume allows anonymous sharing)
  // COPYPARTY_SHR_PREFIX — the ?shr= virtual folder name configured on copyparty, e.g. /s
  COPYPARTY_URL: z.string().url().optional(),
  COPYPARTY_PATH: z.string().default("/"),
  COPYPARTY_PASSWORD: z.string().optional(),
  COPYPARTY_SHR_PREFIX: z.string().default("/s"),
});

export const envConfig = envSchema.parse(process.env);

const serviceSchema = z.object({
  name: z.string().min(1),
  displayName: z.string().min(1),
  systemdUnit: z.string().min(1),
  serviceManager: z.enum(["systemd", "launchd", "brew"]).default("systemd"),
  // Only relevant when serviceManager is "launchd".
  // "gui" = LaunchAgent loaded in ~/Library/LaunchAgents/ (user session, default).
  // "system" = LaunchDaemon loaded in /Library/LaunchDaemons/ (system-wide, no user context).
  launchdDomain: z.enum(["gui", "system"]).default("gui"),
});

const gitRepoSchema = z.object({
  name: z.string().min(1),
  path: z.string().min(1),
});

// An iOS app that can be built on a server and distributed via a CopyParty share link.
const ipaAppSchema = z.object({
  // Unique identifier, used in API paths — alphanumeric/hyphens/underscores only.
  id: z.string().min(1).max(128).regex(/^[A-Za-z0-9_-]+$/, "app id must be alphanumeric, hyphens, or underscores"),
  // Human-readable display name shown in the iOS app.
  displayName: z.string().min(1),
  // Shell command that builds the IPA. Runs via executeCommand on the owning server.
  buildCommand: z.string().min(1).max(5000),
  // Absolute path to the IPA file produced by the build command. This path must be
  // reachable from the CopyParty instance (i.e. inside a volume it serves).
  ipaPath: z.string().min(1),
  // The virtual path inside CopyParty where this file appears, relative to its root.
  // Example: "/ipabuilds/MyApp.ipa"  — must match what CopyParty sees for ipaPath.
  copypartyVirtualPath: z.string().min(1),
});

const jobSchema = z.object({
  id: z.string().min(1).max(128).regex(/^[A-Za-z0-9_-]+$/, "job id must be alphanumeric, hyphens, or underscores"),
  command: z.string().min(1).max(5000),
  schedule: z.string().min(1).max(128).refine((s) => cron.validate(s), { message: "job schedule must be a valid cron expression" }),
  enabled: z.boolean().default(true),
});

const localServerSchema = z.object({
  id: z.string().min(1),
  name: z.string().min(1),
  type: z.literal("local"),
  dockerSocket: z.string().optional(),
  services: z.array(serviceSchema),
  git: z.array(gitRepoSchema),
  jobs: z.array(jobSchema).default([]),
  apps: z.array(ipaAppSchema).default([]),
});

const remoteServerSchema = z.object({
  id: z.string().min(1),
  name: z.string().min(1),
  type: z.literal("remote"),
  host: z.string().min(1),
  port: z.number().int().min(1).max(65535).default(22),
  user: z.string().min(1),
  sshKeyPath: z.string().min(1),
  mac: z.string().regex(/^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$/).optional(),
  broadcastAddress: z.string().ipv4().optional(),
  services: z.array(serviceSchema),
  git: z.array(gitRepoSchema),
  jobs: z.array(jobSchema).default([]),
  apps: z.array(ipaAppSchema).default([]),
});

const serversFileSchema = z.object({
  servers: z.array(z.discriminatedUnion("type", [localServerSchema, remoteServerSchema])).min(1),
  alerts: z.object({
    cpu_threshold: z.number().min(1).max(100),
    memory_threshold: z.number().min(1).max(100),
    disk_threshold: z.number().min(1).max(100),
    pushover_user_key: z.string().optional(),
    pushover_api_token: z.string().optional(),
  }),
  // The id of the local server on which `opencode serve` is managed by Mentat.
  // Must reference a server with type "local". If omitted, OpenCode features are disabled.
  opencodeServerId: z.string().optional(),
});


const configPath = resolveProjectRelativePath(envConfig.SERVERS_CONFIG_PATH);
if (!existsSync(configPath)) {
  throw new Error(`Missing servers config file at ${configPath}`);
}

const parsedServers = serversFileSchema.parse(
  JSON.parse(readFileSync(configPath, "utf8")),
);

export type ServiceConfig = z.infer<typeof serviceSchema>;
export type GitRepoConfig = z.infer<typeof gitRepoSchema>;
export type IpaAppConfig = z.infer<typeof ipaAppSchema>;
export type JobConfig = z.infer<typeof jobSchema>;
export type LocalServerConfig = z.infer<typeof localServerSchema>;
export type RemoteServerConfig = z.infer<typeof remoteServerSchema>;
export type ServerConfig = LocalServerConfig | RemoteServerConfig;

export const appConfig = {
  ...envConfig,
  servers: parsedServers.servers,
  opencodeServerId: parsedServers.opencodeServerId,
  alerts: {
    cpuThreshold: parsedServers.alerts.cpu_threshold,
    memoryThreshold: parsedServers.alerts.memory_threshold,
    diskThreshold: parsedServers.alerts.disk_threshold,
    pushoverUserKey: parsedServers.alerts.pushover_user_key || envConfig.PUSHOVER_USER_KEY || "",
    pushoverApiToken: parsedServers.alerts.pushover_api_token || envConfig.PUSHOVER_API_TOKEN || "",
  },
};

export const getServerById = (id: string): ServerConfig | undefined =>
  appConfig.servers.find((server) => server.id === id);

export const getServiceByName = (
  server: ServerConfig,
  serviceName: string,
): ServiceConfig | undefined => server.services.find((service) => service.name === serviceName);

export const getRepoByName = (
  server: ServerConfig,
  repoName: string,
): GitRepoConfig | undefined => server.git.find((repo) => repo.name === repoName);

export const getAppById = (
  server: ServerConfig,
  appId: string,
): IpaAppConfig | undefined => server.apps.find((app) => app.id === appId);

// Flat list of all apps across all servers, enriched with server context.
export const getAllApps = (): Array<IpaAppConfig & { serverId: string; serverName: string }> =>
  appConfig.servers.flatMap((server) =>
    server.apps.map((app) => ({
      ...app,
      serverId: server.id,
      serverName: server.name,
    })),
  );

// The local server designated to run `opencode serve`, or undefined if not configured.
// Throws at call time if the configured id doesn't resolve to a known local server.
export const getOpencodeServer = (): LocalServerConfig | undefined => {
  const { opencodeServerId } = appConfig;
  if (!opencodeServerId) {
    return undefined;
  }

  const server = appConfig.servers.find((s) => s.id === opencodeServerId);
  if (!server) {
    throw new Error(
      `opencodeServerId '${opencodeServerId}' does not match any configured server`,
    );
  }

  if (server.type !== "local") {
    throw new Error(
      `opencodeServerId '${opencodeServerId}' must reference a local server (type: "local"), got type: "${server.type}"`,
    );
  }

  return server;
};
