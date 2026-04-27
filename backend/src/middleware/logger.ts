import type { Context, Next } from "hono";

const REDACTED_HEADERS = new Set([
  "authorization",
  "cookie",
  "x-api-key",
  "x-auth-token",
  "proxy-authorization",
]);

export const loggerMiddleware = async (c: Context, next: Next): Promise<void> => {
  const startedAt = performance.now();
  await next();

  const elapsedMs = Math.round(performance.now() - startedAt);
  const headers = Object.fromEntries(
    [...c.req.raw.headers.entries()].map(([key, value]) => [
      key,
      REDACTED_HEADERS.has(key.toLowerCase()) ? "[redacted]" : value,
    ]),
  );

  console.info(
    JSON.stringify({
      method: c.req.method,
      path: c.req.path,
      status: c.res.status,
      elapsedMs,
      headers,
    }),
  );
};
