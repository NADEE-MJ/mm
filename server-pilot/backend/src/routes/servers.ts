import { Hono } from "hono";
import { appConfig } from "../config";
import { sshPool } from "../services/sshClient";

export const serversRoutes = new Hono();

serversRoutes.get("/", (c) => {
  const states = sshPool.getStates();

  return c.json({
    servers: appConfig.servers.map((server) => {
      const sshState = server.type === "remote" ? (states[server.id] ?? "unreachable") : "connected";
      return {
        id: server.id,
        name: server.name,
        type: server.type,
        online: server.type === "local" ? true : sshState === "connected",
        sshState,
        canWake: server.type === "remote" && Boolean(server.mac && server.broadcastAddress),
      };
    }),
  });
});
