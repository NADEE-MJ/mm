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

type SqliteModule = {
  sqlite: {
    prepare: (sql: string) => {
      run: (...args: unknown[]) => unknown;
    };
  };
};

type KeyMaterial = {
  privateKey: CryptoKey;
  publicKeyPem: string;
};

const TEST_HOST = "serverpilot.tail.ts.net";
const EMPTY_BODY_SHA256 =
  "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855";

let tempDir = "";
let app: AppModule["default"];
let sqlite: SqliteModule["sqlite"];
let keyA: KeyMaterial;
let keyB: KeyMaterial;
let enrolledDeviceId = "";
let gitRepoName = "";

const hex64 = (): string =>
  Array.from(crypto.getRandomValues(new Uint8Array(32)))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");

const toPem = (spki: ArrayBuffer): string => {
  const base64 = Buffer.from(spki).toString("base64");
  const lines: string[] = [];

  for (let i = 0; i < base64.length; i += 64) {
    lines.push(base64.slice(i, i + 64));
  }

  return `-----BEGIN PUBLIC KEY-----\n${lines.join("\n")}\n-----END PUBLIC KEY-----`;
};

const generateKeyMaterial = async (): Promise<KeyMaterial> => {
  const keyPair = (await crypto.subtle.generateKey(
    {
      name: "ECDSA",
      namedCurve: "P-256",
    },
    true,
    ["sign", "verify"],
  )) as CryptoKeyPair;

  const spki = await crypto.subtle.exportKey("spki", keyPair.publicKey);

  return {
    privateKey: keyPair.privateKey,
    publicKeyPem: toPem(spki),
  };
};

const sha256Hex = async (input: string): Promise<string> => {
  if (!input) {
    return EMPTY_BODY_SHA256;
  }

  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(input));
  return Buffer.from(digest).toString("hex");
};

type SignedRequestOptions = {
  method: "GET" | "POST" | "PUT" | "PATCH" | "DELETE";
  path: string;
  body?: Record<string, unknown>;
  keyType?: "A" | "B";
  timestamp?: number;
  nonce?: string;
  includeIdempotencyKey?: boolean;
};

const sendSignedRequest = async ({
  method,
  path,
  body,
  keyType = "A",
  timestamp,
  nonce,
  includeIdempotencyKey = true,
}: SignedRequestOptions): Promise<Response> => {
  const bodyString = body ? JSON.stringify(body) : "";
  const timestampValue = timestamp ?? Math.floor(Date.now() / 1000);
  const nonceValue = nonce ?? crypto.randomUUID().toLowerCase();
  const bodyHash = await sha256Hex(bodyString);

  const signingInput = `${timestampValue}:${nonceValue}:${method}:${TEST_HOST}:${path}:${bodyHash}`;
  const key = keyType === "A" ? keyA.privateKey : keyB.privateKey;

  const signature = await crypto.subtle.sign(
    {
      name: "ECDSA",
      hash: "SHA-256",
    },
    key,
    new TextEncoder().encode(signingInput),
  );

  const headers = new Headers({
    host: TEST_HOST,
    "x-timestamp": String(timestampValue),
    "x-nonce": nonceValue,
    "x-device-id": enrolledDeviceId,
    "x-key-type": keyType,
    "x-signature": Buffer.from(signature).toString("base64"),
  });

  if (bodyString) {
    headers.set("content-type", "application/json");
  }

  if (["POST", "PUT", "PATCH", "DELETE"].includes(method) && includeIdempotencyKey) {
    headers.set("idempotency-key", crypto.randomUUID().toLowerCase());
  }

  return app.request(`http://${TEST_HOST}${path}`, {
    method,
    headers,
    body: bodyString || undefined,
  });
};

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

  process.env.API_HOST = "127.0.0.1";
  process.env.API_PORT = "4310";
  process.env.ADMIN_PORT = "4311";
  process.env.ADMIN_TOKEN = "0123456789abcdef0123456789abcdef0123456789abcdef";
  process.env.DATABASE_PATH = dbPath;
  process.env.SERVERS_CONFIG_PATH = serversPath;
  process.env.TIMESTAMP_TOLERANCE_SECONDS = "30";
  process.env.AUDIT_LOG_MAX_ROWS = "10000";
  process.env.IDEMPOTENCY_TTL_SECONDS = "300";
  process.env.POSTAUTH_RATE_LIMIT_PER_MINUTE = "120";

  const appModule = (await import("../../src/app")) as AppModule;
  const sqliteModule = (await import("../../src/db/index")) as SqliteModule;

  app = appModule.default;
  sqlite = sqliteModule.sqlite;

  const enrollmentCode = hex64();
  sqlite
    .prepare(
      `
      INSERT INTO enrollment_tokens (code, device_name, expires_at, used_at, failed_attempts)
      VALUES (?, ?, ?, NULL, 0)
    `,
    )
    .run(enrollmentCode, "Integration Test Device", Date.now() + 10 * 60 * 1000);

  keyA = await generateKeyMaterial();
  keyB = await generateKeyMaterial();

  const enrollResponse = await app.request(`http://${TEST_HOST}/api/auth/enroll`, {
    method: "POST",
    headers: {
      host: TEST_HOST,
      "content-type": "application/json",
    },
    body: JSON.stringify({
      code: enrollmentCode,
      keyAPem: keyA.publicKeyPem,
      keyBPem: keyB.publicKeyPem,
      deviceName: "Integration Test iPhone",
    }),
  });

  expect(enrollResponse.status).toBe(201);
  const payload = (await enrollResponse.json()) as { deviceId: string };
  enrolledDeviceId = payload.deviceId;
  expect(enrolledDeviceId.length).toBeGreaterThan(8);
});

afterAll(() => {
  if (tempDir) {
    rmSync(tempDir, { recursive: true, force: true });
  }
});

describe("ServerPilot backend integration", () => {
  test("rejects unsigned request", async () => {
    const response = await app.request(`http://${TEST_HOST}/api/servers`, {
      method: "GET",
      headers: { host: TEST_HOST },
    });

    expect(response.status).toBe(403);
  });

  test("accepts valid signed read request", async () => {
    const response = await sendSignedRequest({ method: "GET", path: "/api/servers" });

    expect(response.status).toBe(200);
    const json = (await response.json()) as { servers: Array<{ id: string }> };
    expect(json.servers.length).toBeGreaterThan(0);
    expect(json.servers[0]?.id).toBe("mac-mini");
  });

  test("rejects stale timestamp", async () => {
    const oldTimestamp = Math.floor(Date.now() / 1000) - 120;
    const response = await sendSignedRequest({
      method: "GET",
      path: "/api/servers",
      timestamp: oldTimestamp,
    });

    expect(response.status).toBe(403);
  });

  test("rejects replayed nonce", async () => {
    const nonce = crypto.randomUUID().toLowerCase();
    const ts = Math.floor(Date.now() / 1000);

    const first = await sendSignedRequest({
      method: "GET",
      path: "/api/servers",
      nonce,
      timestamp: ts,
    });
    expect(first.status).toBe(200);

    const second = await sendSignedRequest({
      method: "GET",
      path: "/api/servers",
      nonce,
      timestamp: ts,
    });
    expect(second.status).toBe(403);
  });

  test("requires key type B for mutating routes", async () => {
    const response = await sendSignedRequest({
      method: "POST",
      path: "/api/jobs",
      keyType: "A",
      body: {
        id: "job-auth-a",
        command: "echo hi",
        schedule: "*/10 * * * *",
      },
    });

    expect(response.status).toBe(403);
  });

  test("requires idempotency key for mutating routes", async () => {
    const response = await sendSignedRequest({
      method: "POST",
      path: "/api/jobs",
      keyType: "B",
      includeIdempotencyKey: false,
      body: {
        id: "job-no-idempotency",
        command: "echo hi",
        schedule: "*/10 * * * *",
      },
    });

    expect(response.status).toBe(400);
  });

  test("package routes: record and fetch", async () => {
    const record = await sendSignedRequest({
      method: "POST",
      path: "/api/servers/mac-mini/packages/record",
      keyType: "B",
      body: {},
    });
    expect(record.status).toBe(200);

    const state = await sendSignedRequest({
      method: "GET",
      path: "/api/servers/mac-mini/packages",
      keyType: "A",
    });
    expect(state.status).toBe(200);

    const payload = (await state.json()) as { serverId: string; daysSinceUpdate: number | null };
    expect(payload.serverId).toBe("mac-mini");
    expect(payload.daysSinceUpdate).not.toBeNull();
  });

  test("jobs routes: create, list, delete", async () => {
    const jobId = `job-${Date.now()}`;

    const create = await sendSignedRequest({
      method: "POST",
      path: "/api/jobs",
      keyType: "B",
      body: {
        id: jobId,
        command: "echo hello",
        schedule: "*/15 * * * *",
      },
    });
    expect(create.status).toBe(201);

    const list = await sendSignedRequest({
      method: "GET",
      path: "/api/jobs",
      keyType: "A",
    });
    expect(list.status).toBe(200);

    const listPayload = (await list.json()) as { jobs: Array<{ id: string }> };
    expect(listPayload.jobs.some((job) => job.id === jobId)).toBe(true);

    const remove = await sendSignedRequest({
      method: "DELETE",
      path: `/api/jobs/${jobId}`,
      keyType: "B",
      body: {},
    });
    expect(remove.status).toBe(200);
  });

  test("ssh route executes local commands", async () => {
    const response = await sendSignedRequest({
      method: "POST",
      path: "/api/servers/mac-mini/ssh",
      keyType: "B",
      body: {
        command: "echo serverpilot-integration",
      },
    });

    expect(response.status).toBe(200);
    const payload = (await response.json()) as { stdout: string; exitCode: number };
    expect(payload.exitCode).toBe(0);
    expect(payload.stdout).toContain("serverpilot-integration");
  });

  test("git routes list and mutate", async () => {
    const list = await sendSignedRequest({
      method: "GET",
      path: "/api/servers/mac-mini/git",
      keyType: "A",
    });
    expect(list.status).toBe(200);

    const listPayload = (await list.json()) as { repos: Array<{ name: string; branch: string }> };
    const repo = listPayload.repos.find((entry) => entry.name === gitRepoName);
    expect(repo).toBeDefined();

    const pull = await sendSignedRequest({
      method: "POST",
      path: "/api/servers/mac-mini/git/pull",
      keyType: "B",
      body: {
        repoName: gitRepoName,
      },
    });
    expect(pull.status).toBe(200);

    const pullPayload = (await pull.json()) as { ok: boolean; exitCode: number };
    expect(typeof pullPayload.ok).toBe("boolean");
    expect(typeof pullPayload.exitCode).toBe("number");

    const checkout = await sendSignedRequest({
      method: "POST",
      path: "/api/servers/mac-mini/git/checkout",
      keyType: "B",
      body: {
        repoName: gitRepoName,
        branch: repo?.branch ?? "master",
      },
    });
    expect(checkout.status).toBe(200);
  });

  test("post-auth device rate limit eventually returns 429", async () => {
    let sawRateLimit = false;

    for (let i = 0; i < 160; i += 1) {
      const response = await sendSignedRequest({
        method: "GET",
        path: "/api/servers",
        keyType: "A",
      });

      if (response.status === 429) {
        sawRateLimit = true;
        break;
      }

      expect(response.status).toBe(200);
    }

    expect(sawRateLimit).toBe(true);
  });
});
