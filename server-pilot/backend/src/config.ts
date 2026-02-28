import { existsSync, readFileSync } from "node:fs";
import path from "node:path";
import { z } from "zod";
import { loadEnv } from "./env";

loadEnv();

const envSchema = z.object({
  API_HOST: z.string().default("0.0.0.0"),
  API_PORT: z.coerce.number().int().min(1).max(65535).default(4310),
  ADMIN_PORT: z.coerce.number().int().min(1).max(65535).default(4311),
  ADMIN_TOKEN: z.string().min(24),
  DATABASE_PATH: z.string().default("./data/server-pilot.db"),
  SERVERS_CONFIG_PATH: z.string().default("./config/servers.json"),
  TIMESTAMP_TOLERANCE_SECONDS: z.coerce.number().int().min(5).max(300).default(30),
  AUDIT_LOG_MAX_ROWS: z.coerce.number().int().min(100).max(100000).default(10000),
  IDEMPOTENCY_TTL_SECONDS: z.coerce.number().int().min(30).max(3600).default(300),
  POSTAUTH_RATE_LIMIT_PER_MINUTE: z.coerce.number().int().min(10).max(5000).default(120),
  PUSHOVER_USER_KEY: z.string().optional(),
  PUSHOVER_API_TOKEN: z.string().optional(),
});

export const envConfig = envSchema.parse(process.env);

const serviceSchema = z.object({
  name: z.string().min(1),
  displayName: z.string().min(1),
  systemdUnit: z.string().min(1),
});

const gitRepoSchema = z.object({
  name: z.string().min(1),
  path: z.string().min(1),
});

const localServerSchema = z.object({
  id: z.string().min(1),
  name: z.string().min(1),
  type: z.literal("local"),
  services: z.array(serviceSchema),
  git: z.array(gitRepoSchema),
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
  broadcastAddress: z.string().optional(),
  services: z.array(serviceSchema),
  git: z.array(gitRepoSchema),
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
});

const resolveProjectRelativePath = (rawPath: string): string => {
  if (path.isAbsolute(rawPath)) {
    return rawPath;
  }

  return path.resolve(process.cwd(), rawPath.replace(/^\.\//, ""));
};

const configPath = resolveProjectRelativePath(envConfig.SERVERS_CONFIG_PATH);
if (!existsSync(configPath)) {
  throw new Error(`Missing servers config file at ${configPath}`);
}

const parsedServers = serversFileSchema.parse(
  JSON.parse(readFileSync(configPath, "utf8")),
);

export type ServiceConfig = z.infer<typeof serviceSchema>;
export type GitRepoConfig = z.infer<typeof gitRepoSchema>;
export type LocalServerConfig = z.infer<typeof localServerSchema>;
export type RemoteServerConfig = z.infer<typeof remoteServerSchema>;
export type ServerConfig = LocalServerConfig | RemoteServerConfig;

export const appConfig = {
  ...envConfig,
  servers: parsedServers.servers,
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
