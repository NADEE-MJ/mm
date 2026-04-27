import type { Context } from "hono";
import { Hono } from "hono";
import { streamSSE } from "hono/streaming";
import { appConfig } from "../config";
import {
  opencodeGet,
  opencodePost,
  opencodePatch,
  opencodeDelete,
  opencodeStream,
} from "../services/opencodeClient";

export const opencodeRoutes = new Hono();

// Guard used on every route — returns 503 when OpenCode is not configured.
const isConfigured = (): boolean => !!appConfig.opencodeServerId;

const notConfiguredResponse = (c: Context) =>
  c.json({ error: "OpenCode is not configured on this server" }, 503);

// ---------------------------------------------------------------------------
// Sessions
// ---------------------------------------------------------------------------

// GET /api/opencode/session
opencodeRoutes.get("/session", async (c) => {
  if (!isConfigured()) return notConfiguredResponse(c);
  try {
    const data = await opencodeGet("/session");
    return c.json(data);
  } catch (error) {
    const message = error instanceof Error ? error.message : "Failed to list sessions";
    return c.json({ error: message }, 500);
  }
});

// POST /api/opencode/session  — body: { title?, workdir? }
opencodeRoutes.post("/session", async (c) => {
  if (!isConfigured()) return notConfiguredResponse(c);
  try {
    const body = await c.req.json().catch(() => ({}));
    const data = await opencodePost("/session", body);
    return c.json(data);
  } catch (error) {
    const message = error instanceof Error ? error.message : "Failed to create session";
    return c.json({ error: message }, 500);
  }
});

// DELETE /api/opencode/session/:id
opencodeRoutes.delete("/session/:id", async (c) => {
  if (!isConfigured()) return notConfiguredResponse(c);
  try {
    const data = await opencodeDelete(`/session/${c.req.param("id")}`);
    return c.json(data);
  } catch (error) {
    const message = error instanceof Error ? error.message : "Failed to delete session";
    return c.json({ error: message }, 500);
  }
});

// ---------------------------------------------------------------------------
// Messages
// ---------------------------------------------------------------------------

// GET /api/opencode/session/:id/message
opencodeRoutes.get("/session/:id/message", async (c) => {
  if (!isConfigured()) return notConfiguredResponse(c);
  try {
    const data = await opencodeGet(`/session/${c.req.param("id")}/message`);
    return c.json(data);
  } catch (error) {
    const message = error instanceof Error ? error.message : "Failed to fetch messages";
    return c.json({ error: message }, 500);
  }
});

// POST /api/opencode/session/:id/message
// body: { parts: [{ type: "text", text: string }], model?: { providerID, modelID } }
opencodeRoutes.post("/session/:id/message", async (c) => {
  if (!isConfigured()) return notConfiguredResponse(c);
  try {
    const body = await c.req.json().catch(() => null);
    if (!body) {
      return c.json({ error: "Request body is required" }, 400);
    }
    const data = await opencodePost(`/session/${c.req.param("id")}/message`, body);
    return c.json(data);
  } catch (error) {
    const message = error instanceof Error ? error.message : "Failed to send message";
    return c.json({ error: message }, 500);
  }
});

// ---------------------------------------------------------------------------
// Session actions
// ---------------------------------------------------------------------------

// POST /api/opencode/session/:id/share
opencodeRoutes.post("/session/:id/share", async (c) => {
  if (!isConfigured()) return notConfiguredResponse(c);
  try {
    const data = await opencodePost(`/session/${c.req.param("id")}/share`);
    return c.json(data);
  } catch (error) {
    const message = error instanceof Error ? error.message : "Failed to share session";
    return c.json({ error: message }, 500);
  }
});

// POST /api/opencode/session/:id/fork
opencodeRoutes.post("/session/:id/fork", async (c) => {
  if (!isConfigured()) return notConfiguredResponse(c);
  try {
    const body = await c.req.json().catch(() => ({}));
    const data = await opencodePost(`/session/${c.req.param("id")}/fork`, body);
    return c.json(data);
  } catch (error) {
    const message = error instanceof Error ? error.message : "Failed to fork session";
    return c.json({ error: message }, 500);
  }
});

// POST /api/opencode/session/:id/revert
opencodeRoutes.post("/session/:id/revert", async (c) => {
  if (!isConfigured()) return notConfiguredResponse(c);
  try {
    const body = await c.req.json().catch(() => ({}));
    const data = await opencodePost(`/session/${c.req.param("id")}/revert`, body);
    return c.json(data);
  } catch (error) {
    const message = error instanceof Error ? error.message : "Failed to revert session";
    return c.json({ error: message }, 500);
  }
});

// POST /api/opencode/session/:id/command
opencodeRoutes.post("/session/:id/command", async (c) => {
  if (!isConfigured()) return notConfiguredResponse(c);
  try {
    const body = await c.req.json().catch(() => null);
    if (!body) {
      return c.json({ error: "Request body is required" }, 400);
    }
    const data = await opencodePost(`/session/${c.req.param("id")}/command`, body);
    return c.json(data);
  } catch (error) {
    const message = error instanceof Error ? error.message : "Failed to send command";
    return c.json({ error: message }, 500);
  }
});

// ---------------------------------------------------------------------------
// Providers & config
// ---------------------------------------------------------------------------

// GET /api/opencode/provider
opencodeRoutes.get("/provider", async (c) => {
  if (!isConfigured()) return notConfiguredResponse(c);
  try {
    const data = await opencodeGet("/provider");
    return c.json(data);
  } catch (error) {
    const message = error instanceof Error ? error.message : "Failed to fetch providers";
    return c.json({ error: message }, 500);
  }
});

// GET /api/opencode/config
opencodeRoutes.get("/config", async (c) => {
  if (!isConfigured()) return notConfiguredResponse(c);
  try {
    const data = await opencodeGet("/config");
    return c.json(data);
  } catch (error) {
    const message = error instanceof Error ? error.message : "Failed to fetch config";
    return c.json({ error: message }, 500);
  }
});

// PATCH /api/opencode/config
opencodeRoutes.patch("/config", async (c) => {
  if (!isConfigured()) return notConfiguredResponse(c);
  try {
    const body = await c.req.json().catch(() => null);
    if (!body) {
      return c.json({ error: "Request body is required" }, 400);
    }
    const data = await opencodePatch("/config", body);
    return c.json(data);
  } catch (error) {
    const message = error instanceof Error ? error.message : "Failed to update config";
    return c.json({ error: message }, 500);
  }
});

// ---------------------------------------------------------------------------
// Agents
// ---------------------------------------------------------------------------

// GET /api/opencode/agent
opencodeRoutes.get("/agent", async (c) => {
  if (!isConfigured()) return notConfiguredResponse(c);
  try {
    const data = await opencodeGet("/agent");
    return c.json(data);
  } catch (error) {
    const message = error instanceof Error ? error.message : "Failed to fetch agents";
    return c.json({ error: message }, 500);
  }
});

// ---------------------------------------------------------------------------
// SSE event stream
// Proxies OpenCode's /event stream back to the iOS client.
// ---------------------------------------------------------------------------

// GET /api/opencode/event
opencodeRoutes.get("/event", async (c) => {
  if (!isConfigured()) return notConfiguredResponse(c);

  let upstreamResponse: Response;
  try {
    upstreamResponse = await opencodeStream("/event");
  } catch (error) {
    const message = error instanceof Error ? error.message : "Failed to connect to OpenCode event stream";
    return c.json({ error: message }, 502);
  }

  if (!upstreamResponse.body) {
    return c.json({ error: "OpenCode event stream returned an empty body" }, 502);
  }

  return streamSSE(c, async (stream) => {
    const reader = upstreamResponse.body!.getReader();
    const decoder = new TextDecoder();

    try {
      while (true) {
        const { done, value } = await reader.read();
        if (done) {
          break;
        }
        // Forward the raw SSE chunk. OpenCode emits properly formatted
        // SSE lines (event:, data:, id:, \n\n) — we pipe them verbatim.
        const chunk = decoder.decode(value, { stream: true });
        await stream.write(chunk);
      }
    } catch {
      // Client disconnected or upstream closed — exit gracefully.
    } finally {
      reader.releaseLock();
    }
  });
});
