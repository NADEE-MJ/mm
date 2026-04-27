import { Hono } from "hono";
import { getServerById } from "../config";
import { sshPool } from "../services/sshClient";
import { sendMagicPacket } from "../services/wol";

export const wolRoutes = new Hono();

wolRoutes.post("/:id/wake", async (c) => {
  const server = getServerById(c.req.param("id"));
  if (!server) {
    return c.json({ error: "Unknown server" }, 404);
  }

  if (server.type !== "remote") {
    return c.json({ error: "Wake is only valid for remote servers" }, 400);
  }

  if (!server.mac || !server.broadcastAddress) {
    return c.json({ error: "Server does not have WoL configuration" }, 400);
  }

  try {
    await sendMagicPacket(server.mac, server.broadcastAddress);
    sshPool.triggerImmediateReconnect(server.id);
    return c.json({ ok: true });
  } catch (error) {
    const message = error instanceof Error ? error.message : "Failed to send WoL packet";
    return c.json({ error: message }, 500);
  }
});
