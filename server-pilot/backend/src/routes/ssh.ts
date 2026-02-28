import { Hono } from "hono";
import { z } from "zod";
import { getServerById } from "../config";
import { executeArbitraryCommand } from "../services/serverContext";

const payloadSchema = z.object({
  command: z.string().min(1).max(5000),
});

export const sshRoutes = new Hono();

sshRoutes.post("/:id/ssh", async (c) => {
  const server = getServerById(c.req.param("id"));
  if (!server) {
    return c.json({ error: "Unknown server" }, 404);
  }

  const parsed = payloadSchema.safeParse(await c.req.json().catch(() => null));
  if (!parsed.success) {
    return c.json({ error: "Invalid payload" }, 400);
  }

  try {
    const result = await executeArbitraryCommand(server.id, parsed.data.command);
    return c.json({
      exitCode: result.exitCode,
      stdout: result.stdout,
      stderr: result.stderr,
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : "SSH command failed";
    return c.json({ error: message }, 500);
  }
});
