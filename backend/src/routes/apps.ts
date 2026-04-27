import { Hono } from "hono";
import { eq, and } from "drizzle-orm";
import { getAllApps, getServerById, getAppById } from "../config";
import { envConfig } from "../config";
import { executeCommand } from "../services/serverContext";
import { createCopyPartyShareLink } from "../services/copyparty";
import { db } from "../db";
import { appBuilds } from "../db/schema";

export const appsRoutes = new Hono();

// GET /api/apps
// Returns all configured IPA apps across all servers, enriched with the last build info.
appsRoutes.get("/", async (c) => {
  try {
    const apps = getAllApps();

    const rows = await db.select().from(appBuilds);

    const buildMap = new Map(
      rows.map((row) => [`${row.serverId}:${row.appId}`, row]),
    );

    const result = apps.map((app) => {
      const build = buildMap.get(`${app.serverId}:${app.id}`);
      return {
        id: app.id,
        displayName: app.displayName,
        serverId: app.serverId,
        serverName: app.serverName,
        ipaPath: app.ipaPath,
        copypartyConfigured: !!envConfig.COPYPARTY_URL,
        lastBuiltAt: build?.lastBuiltAt?.toISOString() ?? null,
        lastBuildExitCode: build?.lastBuildExitCode ?? null,
        lastBuildOutput: build?.lastBuildOutput ?? null,
      };
    });

    return c.json({ apps: result });
  } catch (error) {
    const message = error instanceof Error ? error.message : "Failed to list apps";
    return c.json({ error: message }, 500);
  }
});

// POST /api/apps/:serverId/:appId/build
// Triggers the configured build command on the owning server.
// Stores the result in the database.
appsRoutes.post("/:serverId/:appId/build", async (c) => {
  const server = getServerById(c.req.param("serverId"));
  if (!server) {
    return c.json({ error: "Unknown server" }, 404);
  }

  const app = getAppById(server, c.req.param("appId"));
  if (!app) {
    return c.json({ error: "Unknown app" }, 404);
  }

  try {
    // Run the build command via shell so complex commands with pipes and env vars work.
    const result = await executeCommand(server.id, ["/bin/sh", "-c", app.buildCommand], {
      allowNonZero: true,
      timeoutMs: 10 * 60 * 1000, // 10-minute build timeout
    });

    const output = [result.stdout, result.stderr].filter(Boolean).join("\n").trim();
    const now = new Date();

    // Upsert build record.
    await db
      .insert(appBuilds)
      .values({
        appId: app.id,
        serverId: server.id,
        lastBuiltAt: now,
        lastBuildOutput: output || null,
        lastBuildExitCode: result.exitCode,
      })
      .onConflictDoUpdate({
        target: [appBuilds.appId, appBuilds.serverId],
        set: {
          lastBuiltAt: now,
          lastBuildOutput: output || null,
          lastBuildExitCode: result.exitCode,
        },
      });

    return c.json({
      ok: result.exitCode === 0,
      exitCode: result.exitCode,
      output,
      builtAt: now.toISOString(),
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : "Build failed";
    return c.json({ error: message }, 500);
  }
});

// POST /api/apps/:serverId/:appId/share
// Asks CopyParty to create a 5-minute share link for the app's IPA file.
// The IPA must already exist (i.e. the app must have been built at least once).
appsRoutes.post("/:serverId/:appId/share", async (c) => {
  const server = getServerById(c.req.param("serverId"));
  if (!server) {
    return c.json({ error: "Unknown server" }, 404);
  }

  const app = getAppById(server, c.req.param("appId"));
  if (!app) {
    return c.json({ error: "Unknown app" }, 404);
  }

  if (!envConfig.COPYPARTY_URL) {
    return c.json({ error: "COPYPARTY_URL is not configured on this server" }, 503);
  }

  try {
    const share = await createCopyPartyShareLink(app.copypartyVirtualPath);

    return c.json({
      url: share.url,
      expiresAt: share.expiresAt.toISOString(),
      ttlMinutes: 5,
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : "Failed to create share link";
    return c.json({ error: message }, 500);
  }
});
