# Deferred Issues

Issues identified during codebase audit but deferred — either cosmetic, low-impact, or intentional design decisions. Reviewed and confirmed as non-critical.

---

## Backend

### B-02 · `src/db/index.ts:20` — `chmodSync` only applied to new database files
`chmodSync(databasePath, 0o600)` is skipped when the database already exists. A pre-existing file with overly-permissive permissions is never corrected. Intentionally not fixed — `chmod`-ing files you didn't create can be surprising in deploy environments.

### B-03 · `src/config.ts:7` — Redundant `loadEnv()` call
`config.ts` calls `loadEnv()` at module-level, but the entry point (`index.ts`) already calls it before importing `config.ts`. The `loaded` guard makes this harmless.

### B-04 · `src/services/serverContext.ts:24` — `requireServer` exported but never imported externally
`requireServer` is only called within the same file. The `export` keyword is unused. Can be removed or inlined into `executeCommand`.

### B-05 · `src/services/docker.ts` + `src/services/systemInfo.ts` — Service layer re-validates server ID
`listContainers`, `getContainerLogs`, `runContainerAction`, and `getServerMetrics` each call `getServerById` and throw on unknown server. The routes that call these already perform the check and return 404 first. This is a double-lookup and layering violation — services should accept a `ServerConfig` directly. Low-impact since the dead code path is unreachable.

### B-06 · `src/services/docker.ts:32` — Double space in `docker ps` shell string when `all=false`
`` `docker ps ${allFlag} --format '{{json .}}'` `` produces two spaces when `allFlag` is `""`. Docker CLI ignores extra whitespace, so this is not a real bug.

### B-07 · `src/services/docker.ts:44` — Parsed Docker JSON cast to `Record<string, string>` without validation
`JSON.parse(line) as Record<string, string>` skips runtime type checking. Numeric or null values from Docker's JSON output are silently treated as strings. Consider a Zod schema or explicit type narrowing.

### B-09 · `src/services/scheduler.ts` — Jobs under `remote` server entries run on the local machine
The scheduler calls `runCommand` (local process runner) for all jobs regardless of `serverId`. Jobs configured under a `remote` server run on the local machine. This is the current intentional design (scheduler only runs on the host running the backend), but it is undocumented and the `serverId` field in `JobStatus` is misleading. Consider either documenting the local-only constraint or routing remote jobs through `executeCommand`.

### B-12 · `src/routes/packages.ts` — `package_state` table not scoped per server
The `packageState` table has a single row with no `serverId` column. All servers share one update timestamp. The route validates the server ID but does not use it in queries. If multiple servers are configured this produces incorrect data. Requires a schema migration to add `server_id` and update both route handlers.

### B-14 · `src/routes/git.ts:51` — Validation error detail discarded
`safeParse` failures always return the generic `"Invalid payload"` message, discarding Zod's error details. Intentional to avoid leaking schema structure to callers.

### B-15 · `src/routes/docker.ts:65` — `as` cast before runtime validation
`const action = c.req.param("action") as "start" | "stop" | "restart"` casts before the `ACTIONS.has()` guard. Functionally correct but misleads the type system.

### B-16 · `src/services/wol.ts:10` — Magic packet construction is fragile
`Buffer.alloc(6 + 16 * macBytes.length, 0xff)` is correct but relies on `macBytes.length === 6`. There is no assertion guarding this — a malformed MAC that bypasses the regex check would produce a silently malformed packet. The MAC regex validation earlier in the route is the real guard here.

### B-17 · `src/services/systemInfo.ts:81` — Remote metrics use `cat /proc/...`
Remote server metrics are collected by shelling out to `cat /proc/loadavg`, `cat /proc/meminfo`, and `cat /proc/uptime`. This is Linux-only and not portable. The local server path uses the Node.js `os` module. The Linux-only assumption is undocumented.

### B-18 · `src/middleware/logger.ts` — `/health` endpoint is not logged
The logger middleware is applied only to `/api/*` routes. The `/health` endpoint is not logged. This may be intentional (health checks are noisy) but is undocumented.

---

## Mobile

### M-04 · `Sources/Views/Components/ConfirmActionSheet.swift` — Unused component
`ConfirmActionSheet` is defined but never instantiated. `ServicesView` and `DockerView` use inline `.alert(...)` modifiers instead. Either delete the file or replace the inline alerts with this reusable component for consistency.

### M-05 · `Sources/Views/Components/StatusBadgeView.swift:7` — Missing color cases for `"enabled"` / `"disabled"`
`JobsView` passes `"enabled"` and `"disabled"` to `StatusBadgeView`, but neither is in the color switch — both fall through to `.gray`. Enabled jobs appear visually indistinguishable from unknown/error states. Add `.green` for `"enabled"` and `.secondary` for `"disabled"`.

### M-06 · `Sources/Views/ServerDetailView.swift:34` — Jobs tab only shown for local servers
The Jobs tab is conditionally shown for `server.type == .local`, but `/api/jobs` returns all jobs globally (not filtered by server). A user with only remote servers never sees the Jobs tab.

### M-07 · `Sources/Views/SetupView.swift:88` — Wrong API port placeholder
The "API Port" input field shows placeholder `"3000"`, but the actual default is `4310` (matching `SSHConfigManager` and `backend/src/config.ts`).

### M-10 · `Sources/Services/SSHConnectionManager.swift:255` — Redundant `MainActor.run {}` inside `@MainActor` method
The class is `@MainActor`-isolated, so explicit `await MainActor.run { self.tunnelPort = ...; self.state = ... }` wrappers at lines 255–258 and 265–268 are unnecessary. Property assignments are already main-actor-safe within any method of this class.

### M-11 · `Sources/Services/SSHConnectionManager.swift:321` — `.cascade(to: nil)` discards tunnel child-channel errors
The `childChannelInitializer` closure ends with `.cascade(to: nil)`, meaning errors in the SSH forwarding pipeline setup are silently dropped. The function always returns `makeSucceededVoidFuture()`. Channel errors will eventually surface through connection closure, but the root cause is lost.

### M-15 · `Sources/Views/JobsView.swift` + `Sources/Views/PackagesView.swift` — Duplicate `formatDate(milliseconds:)` helper
Both files define an identical private `formatDate(milliseconds:)` function. Extract to a shared utility (e.g. `Sources/Utils/DateFormatting.swift`).

### M-17 · `Sources/Views/DashboardView.swift:21` — Uptime displayed as raw seconds
`Text("Uptime: \(metrics.uptime) s")` shows a raw integer (e.g. `"Uptime: 1209600 s"`). Format as days/hours/minutes for readability.

### M-18 · `Sources/Services/SSHConnectionManager.swift:98` — `reconnectTask` not cleared after `hostKeyRejected` early return
When `connectLoop()` returns early due to a `.hostKeyRejected` error, `reconnectTask` still holds a reference to the now-completed (but non-nil) `Task`. A subsequent call to `start()` returns immediately due to the `guard reconnectTask == nil` check, preventing reconnection after a host key is reset. Fix: add `defer { reconnectTask = nil }` inside `connectLoop()`.
