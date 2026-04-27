import { appConfig } from "../config";

const OPENCODE_BASE_URL = "http://127.0.0.1:4096";

const isConfigured = (): boolean => !!appConfig.opencodeServerId;

const notConfiguredError = (): Error =>
  new Error("OpenCode is not configured (missing opencodeServerId in servers.json)");

const unreachableError = (cause: unknown): Error => {
  const detail = cause instanceof Error ? cause.message : String(cause);
  return new Error(`OpenCode is not reachable at ${OPENCODE_BASE_URL}: ${detail}`);
};

const doFetch = async (
  path: string,
  init: RequestInit = {},
): Promise<Response> => {
  if (!isConfigured()) {
    throw notConfiguredError();
  }

  const url = `${OPENCODE_BASE_URL}${path}`;

  try {
    const response = await fetch(url, {
      ...init,
      headers: {
        "Content-Type": "application/json",
        ...(init.headers ?? {}),
      },
    });
    return response;
  } catch (error) {
    throw unreachableError(error);
  }
};

const parseJson = async (response: Response): Promise<unknown> => {
  const text = await response.text();
  if (!text) {
    return null;
  }
  try {
    return JSON.parse(text) as unknown;
  } catch {
    throw new Error(`OpenCode returned non-JSON response (${response.status}): ${text.slice(0, 200)}`);
  }
};

export const opencodeGet = async (path: string): Promise<unknown> => {
  const response = await doFetch(path, { method: "GET" });
  return parseJson(response);
};

export const opencodePost = async (path: string, body?: unknown): Promise<unknown> => {
  const response = await doFetch(path, {
    method: "POST",
    body: body !== undefined ? JSON.stringify(body) : undefined,
  });
  return parseJson(response);
};

export const opencodePatch = async (path: string, body: unknown): Promise<unknown> => {
  const response = await doFetch(path, {
    method: "PATCH",
    body: JSON.stringify(body),
  });
  return parseJson(response);
};

export const opencodeDelete = async (path: string): Promise<unknown> => {
  const response = await doFetch(path, { method: "DELETE" });
  return parseJson(response);
};

// Returns the raw fetch Response so the caller can stream the body (e.g. SSE).
export const opencodeStream = async (path: string): Promise<Response> => {
  return doFetch(path, {
    method: "GET",
    headers: { Accept: "text/event-stream" },
  });
};
