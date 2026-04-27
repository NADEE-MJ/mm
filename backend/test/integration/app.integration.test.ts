import { afterAll, beforeAll, describe, expect, test } from "bun:test";
import { execSync } from "node:child_process";
import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";

type AppModule = {
  default: {
    request: (input: string, init?: RequestInit) => Promise<Response>;
  };
};

const TEST_HOST = "127.0.0.1";

let tempDir = "";
let app: AppModule["default"];
let gitRepoName = "";

beforeAll(async () => {
  tempDir = mkdtempSync(path.join(tmpdir(), "server-pilot-tests-"));

  const dbPath = path.join(tempDir, "server-pilot.test.db");
  const serversPath = path.join(tempDir, "servers.json");
  const repoPath = path.join(tempDir, "repo");
  gitRepoName = "test-repo";

  mkdirSync(repoPath, { recursive: true });
  writeFileSync(path.join(repoPath, "README.md"), "# test\n", "utf8");
  execSync("git init", { cwd: repoPath, stdio: "ignore" });
  execSync("git add README.md", { cwd: repoPath, stdio: "ignore" });
  execSync("git -c user.name=Test -c user.email=test@example.com commit -m init", {
    cwd: repoPath,
    stdio: "ignore",
  });

  writeFileSync(
    serversPath,
    JSON.stringify(
      {
        servers: [
          {
            id: "mac-mini",
            name: "Mac Mini",
            type: "local",
            services: [
              {
                name: "dummy",
                displayName: "Dummy",
                systemdUnit: "dummy",
              },
            ],
            git: [
              {
                name: gitRepoName,
                path: repoPath,
              },
            ],
          },
        ],
        alerts: {
          cpu_threshold: 80,
          memory_threshold: 80,
          disk_threshold: 90,
          pushover_user_key: "",
          pushover_api_token: "",
        },
      },
      null,
      2,
    ),
    "utf8",
  );

  process.env.API_PORT = "4310";
  process.env.DATABASE_PATH = dbPath;
  process.env.SERVERS_CONFIG_PATH = serversPath;

  const appModule = (await import("../../src/app")) as AppModule;
  app = appModule.default;
});

afterAll(() => {
  if (tempDir) {
    rmSync(tempDir, { recursive: true, force: true });
  }
});

const request = (
  path: string,
  init?: RequestInit,
): Promise<Response> =>
  app.request(`http://${TEST_HOST}${path}`, {
    headers: { host: TEST_HOST, ...((init?.headers as Record<string, string>) ?? {}) },
    ...init,
  });

describe("Mentat backend integration", () => {
  test("health endpoint returns ok", async () => {
    const response = await request("/health");
    expect(response.status).toBe(200);
    const json = (await response.json()) as { ok: boolean };
    expect(json.ok).toBe(true);
  });

  test("api health endpoint returns ok", async () => {
    const response = await request("/api/health");
    expect(response.status).toBe(200);
    const json = (await response.json()) as { ok: boolean };
    expect(json.ok).toBe(true);
  });

  test("GET /api/servers returns servers list", async () => {
    const response = await request("/api/servers");
    expect(response.status).toBe(200);
    const json = (await response.json()) as { servers: Array<{ id: string }> };
    expect(json.servers.length).toBeGreaterThan(0);
    expect(json.servers[0]?.id).toBe("mac-mini");
  });

  test("package routes: record and fetch", async () => {
    const record = await request("/api/servers/mac-mini/packages/record", {
      method: "POST",
      headers: { host: TEST_HOST, "content-type": "application/json" },
      body: "{}",
    });
    expect(record.status).toBe(200);

    const state = await request("/api/servers/mac-mini/packages");
    expect(state.status).toBe(200);

    const payload = (await state.json()) as { serverId: string; daysSinceUpdate: number | null };
    expect(payload.serverId).toBe("mac-mini");
    expect(payload.daysSinceUpdate).not.toBeNull();
  });

  test("jobs route: list returns array (read-only, config-defined)", async () => {
    const list = await request("/api/jobs");
    expect(list.status).toBe(200);

    const listPayload = (await list.json()) as { jobs: unknown[] };
    expect(Array.isArray(listPayload.jobs)).toBe(true);
  });

  test("jobs route: POST is not available (jobs are config-defined)", async () => {
    const create = await request("/api/jobs", {
      method: "POST",
      headers: { host: TEST_HOST, "content-type": "application/json" },
      body: JSON.stringify({
        id: "test-job",
        command: "echo hello",
        schedule: "*/15 * * * *",
      }),
    });
    expect(create.status).toBe(404);
  });

  test("ssh route is removed (arbitrary command execution is not available)", async () => {
    const response = await request("/api/servers/mac-mini/ssh", {
      method: "POST",
      headers: { host: TEST_HOST, "content-type": "application/json" },
      body: JSON.stringify({ command: "echo mentat-integration" }),
    });
    expect(response.status).toBe(404);
  });

  test("git routes list and mutate", async () => {
    const list = await request("/api/servers/mac-mini/git");
    expect(list.status).toBe(200);

    const listPayload = (await list.json()) as { repos: Array<{ name: string; branch: string }> };
    const repo = listPayload.repos.find((entry) => entry.name === gitRepoName);
    expect(repo).toBeDefined();

    const pull = await request("/api/servers/mac-mini/git/pull", {
      method: "POST",
      headers: { host: TEST_HOST, "content-type": "application/json" },
      body: JSON.stringify({ repoName: gitRepoName }),
    });
    expect(pull.status).toBe(200);

    const pullPayload = (await pull.json()) as { ok: boolean; exitCode: number };
    expect(typeof pullPayload.ok).toBe("boolean");
    expect(typeof pullPayload.exitCode).toBe("number");

    const checkout = await request("/api/servers/mac-mini/git/checkout", {
      method: "POST",
      headers: { host: TEST_HOST, "content-type": "application/json" },
      body: JSON.stringify({
        repoName: gitRepoName,
        branch: repo?.branch ?? "master",
      }),
    });
    expect(checkout.status).toBe(200);
  });

  test("unknown server returns 404", async () => {
    const response = await request("/api/servers/nonexistent/metrics");
    expect(response.status).toBe(404);
  });
});
