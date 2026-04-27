import type { ServerWebSocket } from "bun";
import { getServerById } from "../config";
import { getServerMetrics } from "../services/systemInfo";

// Data attached to each WebSocket connection
type WSData = {
  serverId: string;
  intervalId: ReturnType<typeof setInterval> | null;
};

const PUSH_INTERVAL_MS = 1000;

const sendMetrics = async (ws: ServerWebSocket<WSData>): Promise<void> => {
  try {
    const metrics = await getServerMetrics(ws.data.serverId);
    ws.send(JSON.stringify(metrics));
  } catch (error) {
    const message = error instanceof Error ? error.message : "Failed to get metrics";
    ws.send(JSON.stringify({ error: message }));
  }
};

export const wsHandlers = {
  open(ws: ServerWebSocket<WSData>): void {
    // Push immediately on connect, then every second
    void sendMetrics(ws);
    ws.data.intervalId = setInterval(() => {
      void sendMetrics(ws);
    }, PUSH_INTERVAL_MS);
  },

  close(ws: ServerWebSocket<WSData>): void {
    if (ws.data.intervalId !== null) {
      clearInterval(ws.data.intervalId);
      ws.data.intervalId = null;
    }
  },

  // Required by Bun's WebSocket interface; we don't use client messages here
  message(_ws: ServerWebSocket<WSData>, _message: string | Buffer): void {},
};

/**
 * Attempts to upgrade an incoming request to a WebSocket connection.
 * Returns a Response if the upgrade fails (caller should return it),
 * or null if the upgrade succeeded (Bun handles the response).
 */
export const upgradeMetricsWS = (req: Request, server: ReturnType<typeof Bun.serve>): Response | null => {
  const url = new URL(req.url);
  const match = url.pathname.match(/^\/api\/ws\/metrics\/([^/]+)$/);
  if (!match) {
    return new Response("Not found", { status: 404 });
  }

  const serverId = decodeURIComponent(match[1]);
  if (!getServerById(serverId)) {
    return new Response(JSON.stringify({ error: "Unknown server" }), {
      status: 404,
      headers: { "Content-Type": "application/json" },
    });
  }

  const upgraded = server.upgrade(req, {
    data: { serverId, intervalId: null } satisfies WSData,
  });

  if (!upgraded) {
    return new Response("WebSocket upgrade failed", { status: 400 });
  }

  return null;
};
