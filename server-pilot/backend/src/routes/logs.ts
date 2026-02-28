import { Hono } from "hono";

export const logsRoutes = new Hono();

logsRoutes.get("/:id/logs/:source", (c) => {
  return c.json(
    {
      error: "WebSocket log streaming is not implemented yet in this scaffold",
    },
    501,
  );
});
