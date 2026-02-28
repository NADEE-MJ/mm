import type { MiddlewareHandler } from "hono";
import { appConfig } from "../config";
import { sqlite } from "../db";
import { logAuditEvent } from "../services/audit";
import type { AppVariables, KeyType } from "../types";

const EMPTY_BODY_SHA256 =
  "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855";
const UUID_V4_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/;

const UNAUTHENTICATED_PATHS = new Set(["/health", "/api/health", "/api/auth/enroll"]);
const MUTATING_METHODS = new Set(["POST", "PUT", "PATCH", "DELETE"]);

class SlidingWindowLimiter {
  private buckets = new Map<string, number[]>();

  constructor(
    private readonly maxRequests: number,
    private readonly windowMs: number,
  ) {}

  allow(key: string): boolean {
    const now = Date.now();
    const cutoff = now - this.windowMs;
    const events = (this.buckets.get(key) ?? []).filter((timestamp) => timestamp >= cutoff);

    if (events.length >= this.maxRequests) {
      this.buckets.set(key, events);
      return false;
    }

    events.push(now);
    this.buckets.set(key, events);
    return true;
  }
}

class FailureTracker {
  private buckets = new Map<string, number[]>();

  constructor(
    private readonly threshold: number,
    private readonly windowMs: number,
  ) {}

  markFailure(key: string): void {
    const now = Date.now();
    const cutoff = now - this.windowMs;
    const events = (this.buckets.get(key) ?? []).filter((timestamp) => timestamp >= cutoff);
    events.push(now);
    this.buckets.set(key, events);
  }

  shouldTarpit(key: string): boolean {
    const now = Date.now();
    const cutoff = now - this.windowMs;
    const events = (this.buckets.get(key) ?? []).filter((timestamp) => timestamp >= cutoff);
    this.buckets.set(key, events);
    return events.length >= this.threshold;
  }
}

const postAuthLimiter = new SlidingWindowLimiter(
  appConfig.POSTAUTH_RATE_LIMIT_PER_MINUTE,
  60_000,
);
const failureTracker = new FailureTracker(20, 10 * 60_000);

const nonceCache = new Map<string, number>();

const getDeviceStmt = sqlite.prepare<
  { id: string; key_a_pem: string; key_b_pem: string; enabled: number },
  [string]
>(
  `
  SELECT id, key_a_pem, key_b_pem, enabled
  FROM devices
  WHERE id = ?
  LIMIT 1
`,
);

const getNonceStmt = sqlite.prepare<{ nonce: string }, [string, number]>(
  `
  SELECT nonce
  FROM seen_nonces
  WHERE nonce = ? AND expires_at > ?
  LIMIT 1
`,
);

const insertNonceStmt = sqlite.prepare(
  `
  INSERT OR REPLACE INTO seen_nonces (nonce, device_id, expires_at)
  VALUES (?, ?, ?)
`,
);

const cleanupNoncesStmt = sqlite.prepare(`DELETE FROM seen_nonces WHERE expires_at < ?`);

const getIdempotencyStmt = sqlite.prepare<
  { status_code: number; response_json: string },
  [string, string, number]
>(
  `
  SELECT status_code, response_json
  FROM idempotency_cache
  WHERE device_id = ? AND key = ? AND expires_at > ?
  LIMIT 1
`,
);

const upsertIdempotencyStmt = sqlite.prepare(
  `
  INSERT OR REPLACE INTO idempotency_cache (
    device_id,
    key,
    status_code,
    response_json,
    created_at,
    expires_at
  ) VALUES (?, ?, ?, ?, ?, ?)
`,
);

const cleanupIdempotencyStmt = sqlite.prepare(`DELETE FROM idempotency_cache WHERE expires_at < ?`);
const updateLastSeenStmt = sqlite.prepare(`UPDATE devices SET last_seen_at = ? WHERE id = ?`);

const sleep = (ms: number): Promise<void> => new Promise((resolve) => setTimeout(resolve, ms));

const cleanupExpired = (): void => {
  const now = Date.now();

  for (const [cacheKey, expiresAt] of nonceCache.entries()) {
    if (expiresAt < now) {
      nonceCache.delete(cacheKey);
    }
  }

  cleanupNoncesStmt.run(now);
  cleanupIdempotencyStmt.run(now);
};

cleanupExpired();
const cleanupInterval = setInterval(cleanupExpired, 30_000);
cleanupInterval.unref?.();

const sha256Hex = async (input: Uint8Array): Promise<string> => {
  const digest = await crypto.subtle.digest("SHA-256", input);
  return Buffer.from(digest).toString("hex");
};

const pemToDer = (pem: string): Uint8Array => {
  const base64 = pem
    .replace(/-----BEGIN PUBLIC KEY-----/g, "")
    .replace(/-----END PUBLIC KEY-----/g, "")
    .replace(/\s+/g, "");

  return new Uint8Array(Buffer.from(base64, "base64"));
};

const extractClientIp = (headers: Headers): string => {
  const xForwardedFor = headers.get("x-forwarded-for");
  if (xForwardedFor) {
    return xForwardedFor.split(",")[0]?.trim() ?? "unknown";
  }

  return headers.get("cf-connecting-ip") ?? headers.get("x-real-ip") ?? "unknown";
};

const verifySignature = async (
  publicKeyPem: string,
  signatureBase64: string,
  input: string,
): Promise<boolean> => {
  const importedKey = await crypto.subtle.importKey(
    "spki",
    pemToDer(publicKeyPem),
    {
      name: "ECDSA",
      namedCurve: "P-256",
    },
    false,
    ["verify"],
  );

  const signature = new Uint8Array(Buffer.from(signatureBase64, "base64"));
  const payload = new TextEncoder().encode(input);

  return crypto.subtle.verify(
    {
      name: "ECDSA",
      hash: "SHA-256",
    },
    importedKey,
    signature,
    payload,
  );
};

const isMutatingRequest = (method: string): boolean => MUTATING_METHODS.has(method);

const rejectAuth = async (
  c: Parameters<MiddlewareHandler<{ Variables: AppVariables }>>[0],
  ip: string,
  statusCode: number,
  message: string,
  failReason: string,
  deviceId: string | null = null,
): Promise<Response> => {
  failureTracker.markFailure(ip);
  if (failureTracker.shouldTarpit(ip)) {
    await sleep(5000);
  }

  logAuditEvent({
    deviceId,
    method: c.req.method,
    path: c.req.path,
    statusCode,
    failed: true,
    failReason,
  });

  return new Response(JSON.stringify({ error: message }), {
    status: statusCode,
    headers: {
      "content-type": "application/json",
    },
  });
};

export const deviceAuthMiddleware: MiddlewareHandler<{ Variables: AppVariables }> = async (
  c,
  next,
): Promise<void | Response> => {
  if (UNAUTHENTICATED_PATHS.has(c.req.path)) {
    await next();
    return;
  }

  const ip = extractClientIp(c.req.raw.headers);

  const timestampRaw = c.req.header("x-timestamp");
  const nonce = c.req.header("x-nonce")?.toLowerCase();
  const deviceId = c.req.header("x-device-id") ?? null;
  const keyTypeRaw = c.req.header("x-key-type");
  const signature = c.req.header("x-signature");

  if (!timestampRaw || !nonce || !deviceId || !keyTypeRaw || !signature) {
    return rejectAuth(c, ip, 403, "Missing auth headers", "missing_headers", deviceId);
  }

  const keyType = keyTypeRaw === "A" || keyTypeRaw === "B" ? keyTypeRaw : null;
  if (!keyType) {
    return rejectAuth(c, ip, 403, "Invalid key type", "bad_key_type", deviceId);
  }

  if (!UUID_V4_PATTERN.test(nonce)) {
    return rejectAuth(c, ip, 403, "Invalid nonce", "bad_nonce", deviceId);
  }

  const timestamp = Number.parseInt(timestampRaw, 10);
  if (!Number.isFinite(timestamp)) {
    return rejectAuth(c, ip, 403, "Invalid timestamp", "bad_timestamp", deviceId);
  }

  const nowSeconds = Math.floor(Date.now() / 1000);
  if (Math.abs(nowSeconds - timestamp) > appConfig.TIMESTAMP_TOLERANCE_SECONDS) {
    return rejectAuth(c, ip, 403, "Timestamp outside allowed skew", "timestamp_skew", deviceId);
  }

  const nonceCacheKey = `${deviceId}:${nonce}`;
  if (nonceCache.has(nonceCacheKey)) {
    return rejectAuth(c, ip, 403, "Replay detected", "replay", deviceId);
  }

  const existingNonce = getNonceStmt.get(nonce, Date.now());
  if (existingNonce) {
    return rejectAuth(c, ip, 403, "Replay detected", "replay", deviceId);
  }

  const device = getDeviceStmt.get(deviceId);
  if (!device || device.enabled !== 1) {
    return rejectAuth(c, ip, 403, "Unknown or disabled device", "unknown_device", deviceId);
  }

  const isMutating = isMutatingRequest(c.req.method.toUpperCase());
  if (isMutating && keyType !== "B") {
    return rejectAuth(
      c,
      ip,
      403,
      "Mutating requests require X-Key-Type: B",
      "wrong_key_for_mutation",
      deviceId,
    );
  }

  const host = c.req.header("host");
  if (!host) {
    return rejectAuth(c, ip, 403, "Missing host header", "missing_host", deviceId);
  }

  const rawBodyBuffer = await c.req.raw.clone().arrayBuffer();
  const bodyBytes = new Uint8Array(rawBodyBuffer);
  const bodyHash = bodyBytes.byteLength > 0 ? await sha256Hex(bodyBytes) : EMPTY_BODY_SHA256;

  const requestUrl = new URL(c.req.raw.url);
  const pathWithQuery = `${requestUrl.pathname}${requestUrl.search}`;
  const signingInput = `${timestampRaw}:${nonce}:${c.req.method.toUpperCase()}:${host}:${pathWithQuery}:${bodyHash}`;

  const publicKeyPem = keyType === "A" ? device.key_a_pem : device.key_b_pem;
  const isSignatureValid = await verifySignature(publicKeyPem, signature, signingInput);
  if (!isSignatureValid) {
    return rejectAuth(c, ip, 403, "Invalid signature", "bad_signature", deviceId);
  }

  if (!postAuthLimiter.allow(deviceId)) {
    return rejectAuth(c, ip, 429, "Device rate limit exceeded", "device_rate_limit", deviceId);
  }

  const nonceExpiresAt = Date.now() + appConfig.TIMESTAMP_TOLERANCE_SECONDS * 1000;
  nonceCache.set(nonceCacheKey, nonceExpiresAt);
  insertNonceStmt.run(nonce, deviceId, nonceExpiresAt);

  let idempotencyKey: string | undefined;
  if (isMutating) {
    idempotencyKey = c.req.header("idempotency-key") ?? undefined;
    if (!idempotencyKey) {
      return rejectAuth(c, ip, 400, "Missing Idempotency-Key", "missing_idempotency_key", deviceId);
    }

    const cached = getIdempotencyStmt.get(deviceId, idempotencyKey, Date.now());
    if (cached) {
      logAuditEvent({
        deviceId,
        method: c.req.method,
        path: c.req.path,
        statusCode: cached.status_code,
        failed: false,
      });

      return new Response(cached.response_json, {
        status: cached.status_code,
        headers: {
          "content-type": "application/json",
        },
      });
    }

    c.set("idempotencyKey", idempotencyKey);
  }

  c.set("deviceId", deviceId);
  c.set("keyType", keyType as KeyType);
  c.set("requestBodyHash", bodyHash);

  try {
    await next();
  } catch (error) {
    updateLastSeenStmt.run(Date.now(), deviceId);
    logAuditEvent({
      deviceId,
      method: c.req.method,
      path: c.req.path,
      statusCode: 500,
      failed: true,
      failReason: "handler_error",
    });
    throw error;
  }

  updateLastSeenStmt.run(Date.now(), deviceId);

  if (isMutating && idempotencyKey) {
    const expiresAt = Date.now() + appConfig.IDEMPOTENCY_TTL_SECONDS * 1000;
    const responseBody = await c.res.clone().text();
    let payload = responseBody;

    if (!payload) {
      payload = "{}";
    }

    upsertIdempotencyStmt.run(
      deviceId,
      idempotencyKey,
      c.res.status,
      payload,
      Date.now(),
      expiresAt,
    );
  }

  logAuditEvent({
    deviceId,
    method: c.req.method,
    path: c.req.path,
    statusCode: c.res.status,
    failed: c.res.status >= 400,
    failReason: c.res.status >= 400 ? "request_failed" : undefined,
  });
};
