import { Hono } from "hono";
import { z } from "zod";
import { getRepoByName, getServerById } from "../config";
import { executeCommand } from "../services/serverContext";

const pullSchema = z.object({
  repoName: z.string().min(1),
  force: z.boolean().optional(),
});

const checkoutSchema = z.object({
  repoName: z.string().min(1),
  branch: z.string().min(1).max(256)
    .regex(/^[A-Za-z0-9._\/-]+$/, "Invalid branch name")
    .refine((b) => !b.includes(".."), "Branch name must not contain '..'"),
});

export const gitRoutes = new Hono();

gitRoutes.get("/:id/git", async (c) => {
  const server = getServerById(c.req.param("id"));
  if (!server) {
    return c.json({ error: "Unknown server" }, 404);
  }

  const repos = await Promise.all(
    server.git.map(async (repo) => {
      const branchResult = await executeCommand(
        server.id,
        ["git", "-C", repo.path, "rev-parse", "--abbrev-ref", "HEAD"],
        { allowNonZero: true, timeoutMs: 8000 },
      );

      return {
        name: repo.name,
        path: repo.path,
        branch: branchResult.exitCode === 0 ? branchResult.stdout : "unknown",
      };
    }),
  );

  return c.json({ repos });
});

gitRoutes.post("/:id/git/pull", async (c) => {
  const server = getServerById(c.req.param("id"));
  if (!server) {
    return c.json({ error: "Unknown server" }, 404);
  }

  const parsed = pullSchema.safeParse(await c.req.json().catch(() => null));
  if (!parsed.success) {
    return c.json({ error: "Invalid payload" }, 400);
  }

  const repo = getRepoByName(server, parsed.data.repoName);
  if (!repo) {
    return c.json({ error: "Unknown repo" }, 404);
  }

  const args = ["git", "-C", repo.path, "pull"];
  if (!parsed.data.force) {
    args.push("--ff-only");
  }

  try {
    const result = await executeCommand(server.id, args, {
      allowNonZero: true,
      timeoutMs: 30000,
    });

    return c.json({
      ok: result.exitCode === 0,
      exitCode: result.exitCode,
      output: result.stdout || result.stderr,
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : "Git pull failed";
    return c.json({ error: message }, 500);
  }
});

gitRoutes.post("/:id/git/checkout", async (c) => {
  const server = getServerById(c.req.param("id"));
  if (!server) {
    return c.json({ error: "Unknown server" }, 404);
  }

  const parsed = checkoutSchema.safeParse(await c.req.json().catch(() => null));
  if (!parsed.success) {
    return c.json({ error: "Invalid payload" }, 400);
  }

  const repo = getRepoByName(server, parsed.data.repoName);
  if (!repo) {
    return c.json({ error: "Unknown repo" }, 404);
  }

  try {
    const result = await executeCommand(
      server.id,
      ["git", "-C", repo.path, "checkout", parsed.data.branch],
      {
        allowNonZero: true,
        timeoutMs: 20000,
      },
    );

    return c.json({
      ok: result.exitCode === 0,
      exitCode: result.exitCode,
      output: result.stdout || result.stderr,
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : "Git checkout failed";
    return c.json({ error: message }, 500);
  }
});
