# Mentat Backend — Security & Code Audit

**Last updated:** 2026-03-04 (post SSH-tunnel migration + post-audit-fix commits)

Status legend for items from the original pre-migration audit:
- **FIXED** — resolved in the SSH-tunnel migration or post-audit-fix commit
- **N/A** — the affected code no longer exists
- **STILL OPEN** — issue persists in the current codebase
- **CHANGED** — issue partially addressed or context changed; see note

---

## 1. Security Vulnerabilities

---

**~~[CRITICAL] Arbitrary command execution with no key-type restriction~~ — N/A**
- ~~`backend/src/routes/ssh.ts:12-33`~~
- **Resolution:** The entire `/api/servers/:id/ssh` endpoint and `routes/ssh.ts` have been deleted. Arbitrary command execution via the API is no longer possible.

---

**~~[CRITICAL] Local-server arbitrary command runs as the server process user with a login shell~~ — N/A**
- ~~`backend/src/services/serverContext.ts:71`~~
- **Resolution:** `executeArbitraryCommand` has been removed entirely. The SSH route that invoked it has been deleted.

---

**~~[CRITICAL] Scheduled jobs run as login shell (operator-controlled command, not API-controlled)~~ — FIXED**
- ~~`backend/src/services/scheduler.ts:78`~~
- **Resolution:** The `-l` flag has been dropped. `scheduler.ts:78` now calls `["/bin/zsh", "-c", command]`, no longer sourcing login profiles.

---

**[CRITICAL] Docker remote path injects shell via `/bin/sh -lc` — STILL OPEN**
- `backend/src/services/docker.ts:39-44`
- `listContainers` for remote servers still wraps a `docker ps` command inside `/bin/sh -lc` with `${allFlag}` interpolated into the string. Although `allFlag` is only ever `""` or `"-a"` (controlled internally, not user input), this is the **only location in the entire service layer** that builds a shell command via template string and passes it to a shell interpreter. All other `executeCommand` callers use argument arrays.
- **Fix:** Build the args array without a shell: `["docker", "ps", ...(all ? ["-a"] : []), "--format", "{{json .}}"]` and pass via `executeCommand`.

---

**~~[HIGH] `isLikelyPem` is trivially bypassable~~ — N/A**
- ~~`backend/src/routes/auth.ts:24-25`~~
- **Resolution:** `routes/auth.ts` and the entire ECDSA device-auth system have been deleted in the SSH-tunnel migration. PEM key enrollment no longer exists.

---

**~~[HIGH] Enrollment token `failed_attempts` check allows code enumeration~~ — N/A**
- ~~`backend/src/routes/auth.ts:79-105`~~
- **Resolution:** `routes/auth.ts` deleted.

---

**[HIGH] SSH key loaded from disk on every connection attempt — STILL OPEN (CHANGED)**
- `backend/src/services/sshClient.ts:214`
- `readFileSync(server.sshKeyPath)` is called inside `toConnectConfig`, which is called inside every `connect()` call. An `existsSync` guard was added (line 206), but there is still no check that the file permissions are restrictive (`0o600` or stricter), and the key is not cached at startup.
- **Fix:** Read and cache the key at startup; add a `statSync` check that the file mode is `0o600` or stricter before reading.

---

**~~[HIGH] `FailureTracker` and `SlidingWindowLimiter` are in-memory only~~ — N/A**
- ~~`backend/src/middleware/deviceAuth.ts`~~ / ~~`backend/src/utils/rateLimiter.ts`~~
- **Resolution:** `deviceAuth.ts` and `rateLimiter.ts` have been deleted. Device authentication no longer exists.

---

**~~[MEDIUM] Admin token compared with length-leaking fast path~~ — N/A**
- ~~`backend/src/admin/adminApp.ts:12-16`~~
- **Resolution:** The entire `admin/` directory has been deleted.

---

**~~[MEDIUM] `x-nonce` header lowercased before UUID validation~~ — N/A**
- ~~`backend/src/middleware/deviceAuth.ts:191`~~
- **Resolution:** `deviceAuth.ts` deleted.

---

**[MEDIUM] No upper bound on `lines` query parameter in docker logs — STILL OPEN**
- `backend/src/routes/docker.ts:32-35`
- `lines` is parsed from a query param; `Number.isFinite` is checked but there is no upper bound. A caller can pass `lines=999999999` to stream enormous log output and exhaust memory.
- **Fix:** Add `Math.min(lines, 10000)` (or similar cap) after the `isFinite` check.

---

**[MEDIUM] `BRANCH_PATTERN` allows `..` and leading `-` — STILL OPEN**
- `backend/src/routes/git.ts:16`
- The regex `^[A-Za-z0-9._\/-]+$` permits `.`, `/`, and combinations thereof, so values like `../../etc/passwd` or `--upload-pack=malicious` pass the pattern. `git checkout` is called with an arg array (no shell injection), but `git checkout ../../../file` can affect files outside the repo.
- **Fix:** `if (/\.\./.test(branch) || branch.startsWith('-')) return 400`.

---

**[LOW] `broadcastAddress` not validated as IP — STILL OPEN**
- `backend/src/config.ts:52`
- `broadcastAddress: z.string().optional()` with no format constraint. A misconfigured value could cause `dgram.send` to fail silently or send packets to unexpected hosts.
- **Fix:** Add `.ip()` or a regex validator on `broadcastAddress`.

---

**[LOW] Pushover error body logged verbatim — STILL OPEN**
- `backend/src/services/pushover.ts:24-25`
- If the Pushover API call fails, `response.text()` is included verbatim in the thrown error which propagates to `console.error`. Pushover sometimes echoes back parts of the request in error responses.
- **Fix:** Sanitize or truncate Pushover error responses before including them in thrown errors.

---

**[LOW] Pushover alerts fail silently — errors from `sendPushover` are swallowed — NEW**
- `backend/src/services/alertMonitor.ts:52-54`
- `checkOneServer` wraps the entire alert dispatch in `try/catch` with an empty body: `} catch { // Monitoring is best-effort }`. If Pushover credentials are misconfigured or the Pushover API is unreachable, all alerts fail silently with nothing written to logs. Operators have no visibility that alerting is broken.
- **Fix:** Add at minimum `console.warn("Alert check failed for", serverId, error)` in the catch block.

---

**[LOW] `scheduler.ts` sends full raw `stderr` of failed jobs to Pushover with no size cap — NEW**
- `backend/src/services/scheduler.ts:88-92`
- The Pushover notification body includes `result.stderr || "no stderr"` verbatim. A command that writes megabytes of output to stderr (e.g. a misconfigured tool or a crash dump) would create an enormous Pushover API payload. Pushover imposes a 1024-char message limit and will reject or truncate silently.
- **Fix:** Truncate `result.stderr` to a safe maximum (e.g. 500 chars) before including in the notification.

---

**[LOW] Backend SSH connections accept any host key — no host key verification — NEW**
- `backend/src/services/sshClient.ts:205-218`
- The `ConnectConfig` passed to `ssh2` does not include a `hostVerifier` callback. The backend will connect to any host presenting any SSH host key, leaving backend-to-server connections vulnerable to MITM. The mobile app (`SSHConnectionManager.swift`) correctly implements Trust-On-First-Use via `HostKeyStore`; the backend has no equivalent.
- **Fix:** Add a `hostVerifier` callback that compares the host key fingerprint against a stored value. Store expected fingerprints in `servers.json` alongside `host`/`user`.

---

**[LOW] `backend/.env.example` still contains ghost variables from the deleted auth system — NEW**
- `backend/.env.example:1-9`
- `ADMIN_TOKEN`, `ADMIN_PORT`, `TIMESTAMP_TOLERANCE_SECONDS`, `AUDIT_LOG_MAX_ROWS`, `POSTAUTH_RATE_LIMIT_PER_MINUTE`, and `API_HOST` are all present in the example file but none are referenced anywhere in `backend/src/`. `config.ts` does not declare or consume any of them. An operator reading this file might believe `ADMIN_TOKEN` still gates administrative access when it does not — access control is now entirely via SSH tunnel.
- **Fix:** Remove all deleted-auth variables. Add a comment explaining that authentication is handled by the SSH tunnel and no token configuration is required.

---

**[LOW] `REDACTED_HEADERS` set in `logger.ts` is too narrow and undocumented — NEW**
- `backend/src/middleware/logger.ts:3-6`
- Only `authorization` and `cookie` are redacted from request logs. There is no comment instructing maintainers to add new auth headers here. All other request headers — including any custom future auth header — would be logged in cleartext. The full request header object is serialized via `JSON.stringify` to `console.info` on every request.
- **Fix:** Add a comment: `// Add any new authentication header names here`. Consider also redacting `x-api-key` and `proxy-authorization` preemptively.

---

**[LOW] `config.ts` — `host` and `user` in `remoteServerSchema` not validated — NEW**
- `backend/src/config.ts:50-52`
- `host: z.string().min(1)` and `user: z.string().min(1)` accept any non-empty string. Neither is validated as a valid RFC-1123 hostname / IPv4 / IPv6 address, nor as a shell-safe POSIX username (alphanumeric + `_` + `-`). If either field were ever interpolated into a shell string or log message, injection becomes possible.
- **Fix:** Add `.regex(/^[a-zA-Z0-9._-]+$/)` to `user` and a hostname/IP pattern check to `host`. At minimum add `.startsWith("-")` denial to prevent leading-dash values.

---

**[LOW] `git checkout` missing `--` separator before branch argument — NEW**
- `backend/src/routes/git.ts:110`, `backend/src/routes/git.ts:74`
- Git branch names are passed as the final argument to `["git", "-C", repo.path, "checkout", parsed.data.branch]` (and pull equivalent). Without the `--` separator, a branch name starting with `-` (or one that matches a git option like `--orphan`) is interpreted as a git flag rather than a ref name. The `BRANCH_PATTERN` regex currently permits `-` mid-string but not at the start — however tightening the regex alone is insufficient because `--` also prevents edge cases where git's own disambiguation logic might misinterpret a valid-looking branch name as a path spec on some git versions.
- **Fix:** Insert `"--"` before the branch argument: `["git", "-C", repo.path, "checkout", "--", branch]`.

---

## 2. Code Quality

---

**[MEDIUM] `resolveProjectRelativePath` is duplicated in two files — STILL OPEN**
- `backend/src/config.ts:68-74` and `backend/src/db/index.ts:8-14`
- Identical function body in both files.
- **Fix:** Extract to `backend/src/utils/paths.ts` and import.

---

**[MEDIUM] `docker.ts` — `assertContainerId` + `getServerById` guard duplication — STILL OPEN**
- `backend/src/services/docker.ts:63-68`, `102-107`
- The same guard sequence (`assertContainerId` + `getServerById` null check + `throw`) is repeated in both `getContainerLogs` and `runContainerAction`.
- **Fix:** Introduce a `resolveContainer(serverId, containerId)` helper that combines both guards.

---

**[MEDIUM] `package_state` table treated as singleton via INSERT+UPDATE — STILL OPEN**
- `backend/src/routes/packages.ts:13-28`
- The table can accumulate multiple rows (`INSERT` on first run, `UPDATE` on subsequent), but queries use `LIMIT 1`. Old rows are never cleaned up.
- **Fix:** Use `INSERT OR REPLACE` with a fixed `id=1` to enforce a true singleton row.

---

**[MEDIUM] `packages.ts` `serverId` route param validated but never stored — NEW**
- `backend/src/routes/packages.ts:7-55`
- Both `GET /:id/packages` and `POST /:id/packages/record` validate that the `serverId` exists via `getServerById`, but the `package_state` table has no `server_id` column. All servers share one global `package_state` row. Updating packages on server A silently resets the `lastUpdatedAt` timestamp for all servers; querying server B returns server A's data.
- **Fix:** Add a `server_id TEXT NOT NULL` column to `package_state` and scope all queries with `WHERE server_id = ?` using the validated `server.id`.

---

**~~[MEDIUM] `FailureTracker.shouldTarpit` re-filters bucket on every call~~ — N/A**
- ~~`backend/src/middleware/deviceAuth.ts:33-39`~~
- **Resolution:** `deviceAuth.ts` deleted.

---

**[MEDIUM] `logsRoutes` is a stub that always returns 501 — STILL OPEN**
- `backend/src/routes/logs.ts`
- The entire route file returns `501 Not Implemented`. It adds noise to logs and misleads clients.
- **Fix:** Remove the route from `app.ts` until implemented, or return `404`.

---

**[LOW] `db` (Drizzle ORM instance) exported but never used at runtime — STILL OPEN (CHANGED)**
- `backend/src/db/index.ts:85`
- All database access uses the raw `sqlite` Bun.Database instance; the `db` Drizzle wrapper is only used by the offline `migrate.ts` script, never by the live server.
- **Fix:** Either remove the Drizzle dependency and use raw SQLite consistently, or migrate all queries to Drizzle.

---

**[LOW] `startAlertMonitor` interval never unref'd — STILL OPEN**
- `backend/src/services/alertMonitor.ts:58-62`
- The alert monitor interval does not call `.unref()`. In test environments this keeps the process alive.
- **Fix:** `const interval = setInterval(...); interval.unref?.();`

---

## 3. Best Practices Violations

---

**~~[HIGH] `config.ts` calls `loadEnv()` at module load — double invocation~~ — FIXED**
- ~~`backend/src/config.ts:6`~~ / ~~`backend/src/index.ts:1-3`~~
- **Resolution:** `index.ts` now pre-loads env with a guard before other imports; `config.ts` does not independently call `loadEnv()`.

---

**~~[HIGH] SSH route passed user command to `executeArbitraryCommand` with no sanitization~~ — N/A**
- ~~`backend/src/routes/ssh.ts:24`~~
- **Resolution:** SSH route and `executeArbitraryCommand` deleted.

---

**[MEDIUM] Error messages from internal commands leaked to API clients verbatim — STILL OPEN**
- `backend/src/services/serverContext.ts:53-57`, multiple route files
- When a remote command fails, the full error string including the command string (file paths, server IDs) is returned to the API client.
- **Fix:** Log the full error server-side; return a generic `"Command failed"` with optional `exitCode` to the client.

---

**~~[MEDIUM] `routes/auth.ts` uses unprepared queries in hot path~~ — N/A**
- ~~`backend/src/routes/auth.ts:84-86`~~
- **Resolution:** `routes/auth.ts` deleted.

---

**[MEDIUM] `docker.ts` remote path parses JSON with no error handling — STILL OPEN**
- `backend/src/services/docker.ts:49`
- `JSON.parse(line)` — if `docker ps --format '{{json .}}'` emits a non-JSON line (e.g. a Docker daemon warning), this throws an unhandled exception that returns a 500 with the raw error message.
- **Fix:** Wrap in `try/catch` and skip/log malformed lines.

---

**[MEDIUM] `sshClient.ts` — TOCTOU gap in `connect()` — STILL OPEN**
- `backend/src/services/sshClient.ts:137-186`
- After `connectPromise` resolves and is cleared (line 160), a concurrent `ensureConnected` call could enter `connect()` again and create a second client for the same server.
- **Fix:** Ensure `connectPromise` is not cleared until *after* the `ready` event resolves the outer call stack. Currently it is cleared inside the `ready` handler before `resolve()` returns, which is correct only if there are no concurrent waiters — the guard on line 138 closes the race only partially.

---

**[MEDIUM] `wol.ts` uses `macBytes.length` instead of constant `6` — STILL OPEN**
- `backend/src/services/wol.ts:11`
- `Buffer.alloc(6 + 16 * macBytes.length, 0xff)` — ties the WoL packet size to the runtime byte count of the MAC rather than the correct constant `6` (102-byte packet).
- **Fix:** `Buffer.alloc(6 + 16 * 6, 0xff)`.

---

**[LOW] `processRunner.ts` does not kill child on stream failure — STILL OPEN**
- `backend/src/services/processRunner.ts:34-65`
- If `readStream` throws, the child process is never killed and the timeout timer is never cleared, leaking both.
- **Fix:** Wrap the `Promise.all` in `try/finally { process.kill(); clearTimeout(timeout); }`.

---

**~~[LOW] `enrollments.ts` token status logic: used + attacked shows as "invalidated"~~ — N/A**
- ~~`backend/src/admin/routes/enrollments.ts:54-56`~~
- **Resolution:** `admin/` directory deleted.

---

**[LOW] `sshClient.ts` exit code defaults to `0` when SSH stream closes with `null` — STILL OPEN**
- `backend/src/services/sshClient.ts:119`
- `exitCode: exitCode ?? 0` — a null exit code from ssh2 typically means the session was closed unexpectedly, not that the command succeeded. Defaulting to `0` can mask errors silently.
- **Fix:** Default to `-1` or throw when `exitCode` is null.

---

**[LOW] `systemInfo.ts` uses 1-minute load average as CPU% with no explanatory comment — STILL OPEN (CHANGED)**
- `backend/src/services/systemInfo.ts:60`
- `(load[0] / cpus) * 100` — load average is not CPU utilization and can exceed 100% (clamped by `Math.min`). No comment explains the approximation.
- **Fix:** Add a comment explaining the limitation, or use `/proc/stat` for a true utilization sample.

---

**[LOW] `docker.ts` — local Dockerode instantiated unconditionally at module load — STILL OPEN**
- `backend/src/services/docker.ts:13`
- `const docker = new Dockerode()` runs at import time even if no local servers are configured or Docker is not installed. Silent failure until a request arrives.
- **Fix:** Lazily instantiate inside the `local` branch, or check socket existence at startup and log a warning.

---

## 4. Weird / Suspicious Logic

---

**~~[MEDIUM] `deviceAuth.ts`: `updateLastSeenStmt` called twice~~ — N/A**
- ~~`backend/src/middleware/deviceAuth.ts:271-295`~~
- **Resolution:** `deviceAuth.ts` deleted.

---

**[MEDIUM] `alertMonitor.ts` `shouldSend` mutates cooldown state as side effect of condition check — STILL OPEN**
- `backend/src/services/alertMonitor.ts:8-16`
- `shouldSend` both reads *and writes* the cooldown map. If `sendPushover` throws after `shouldSend` returns `true`, the cooldown is already set — meaning the alert is silenced for 10 minutes even though it was never delivered.
- **Fix:** Separate the check from the commit: return `true` from `shouldSend` without writing, then call `markSent(key)` only after `sendPushover` succeeds.

---

**~~[MEDIUM] `enrollments.ts` status logic has unreachable branch~~ — N/A**
- **Resolution:** `admin/` deleted.

---

**~~[MEDIUM] Magic number `20` for failure threshold is undocumented~~ — N/A**
- ~~`backend/src/middleware/deviceAuth.ts:46`~~
- **Resolution:** `deviceAuth.ts` deleted.

---

## 5. New Issues Introduced by SSH-Tunnel Migration

---

**[MEDIUM] `SSHIdentityManager`: nil `SecAccessControl` silently degrades key security**
- `mobile/Sources/Services/SSHIdentityManager.swift`
- If `SecAccessControlCreateWithFlags` returns nil (e.g., on older OS versions or under memory pressure), the key is created without access control rather than failing hard. This is a silent security degradation — the private key is stored with no biometric/passcode protection and no error is surfaced to the caller.
- **Fix:** Treat a nil `SecAccessControl` as a hard error and throw/return an error instead of proceeding.

---

**[LOW] `SSHConnectionManager.shared` uses `MainActor.assumeIsolated` in a static initializer — crash risk — NEW**
- `mobile/Sources/Services/SSHConnectionManager.swift:64-66`
- The `nonisolated(unsafe) static let shared` initializer calls `MainActor.assumeIsolated { SSHConnectionManager() }`. If `shared` is first accessed from a non-`@MainActor` context (e.g., from a background `Task`, a library callback, or a unit test), the `assumeIsolated` precondition fires and crashes the app. Concurrently, the `@MainActor`-isolated `SSHConnectionManager()` init is not `nonisolated`, so the design assumption is fragile.
- **Fix:** Replace with `@MainActor static let shared = SSHConnectionManager()` and ensure all call sites access it on the main actor via `await MainActor.run { SSHConnectionManager.shared }` or use `@MainActor` context at call sites.

---

## Summary by Severity

| Severity | Count | Notes |
|---|---|---|
| **Critical** | 1 open (3 resolved/N/A) | Docker remote path still uses `/bin/sh -lc` with template string |
| **High** | 1 open (3 N/A) | SSH key not cached, no permission check |
| **Medium** | 13 open (7 N/A) | Branch path traversal; docker log size unbounded; `shouldSend` mutates on check; error details leaked to clients; JSON.parse unguarded; TOCTOU in connect(); `package_state` not scoped per-server; SSH tunnel nil access control; etc. |
| **Low** | 16 open (3 N/A) | WoL packet size; processRunner leak; docker unconditional init; SSH null exit code; backend SSH no host key verification; ghost `.env.example` vars; scheduler unlimited stderr; Pushover silent discard; `SSHConnectionManager.assumeIsolated` crash risk; etc. |

### Top 3 urgent fixes

1. **`services/docker.ts:39-44`** — replace `/bin/sh -lc` template string with an argument array. This is the last shell-interpolation pattern in the service layer.
2. **`routes/git.ts:16` / `BRANCH_PATTERN`** — reject `..` and leading `-` in branch names to close the git path traversal vector.
3. **`services/sshClient.ts:214`** — add a file-permission check (`statSync` mode `0o600`) and cache the key at startup rather than reading from disk on every reconnect.
