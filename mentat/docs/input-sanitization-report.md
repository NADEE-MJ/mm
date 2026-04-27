# Input Sanitization Audit Report

**Scope:** All places where user-supplied input (request body, query params, path params, headers) flows into the database, filesystem, shell commands, or HTTP responses that echo user data back.

**Covers:** `backend/src/routes/`, `backend/src/services/`, `backend/src/middleware/`, `backend/src/db/`

**Last updated:** 2026-03-04 (post SSH-tunnel migration + post-audit-fix commits)

Status legend:
- **N/A** — the affected code no longer exists
- **STILL OPEN** — issue persists in the current codebase

---

## Summary Table

| # | File | Line(s) | Input Source | Sink | Sanitization Present | Severity | Status |
|---|------|---------|-------------|------|---------------------|----------|--------|
| 1 | ~~`routes/ssh.ts`~~ | ~~24~~ | ~~`body.command`~~ | ~~Shell exec (arbitrary)~~ | — | ~~CRITICAL~~ | **N/A** |
| 2 | ~~`routes/jobs.ts` + `services/scheduler.ts`~~ | ~~23, 102~~ | ~~`body.command`~~ | ~~Shell exec (scheduled) + DB write~~ | — | ~~CRITICAL~~ | **N/A** |
| 3 | ~~`routes/jobs.ts`~~ | ~~14, 24~~ | ~~`body.command`, `body.id`~~ | ~~HTTP response (echo)~~ | — | ~~Medium~~ | **N/A** |
| 4 | `routes/git.ts`, `routes/services.ts`, `routes/docker.ts` | 75, 115, 30 | Command stdout/stderr | HTTP response (echo) | None | Medium | **STILL OPEN** |
| 5 | ~~`routes/auth.ts`~~ | ~~79–82, 115~~ | ~~`body.keyAPem`, `body.keyBPem`~~ | ~~DB write (+ crypto)~~ | — | ~~Medium~~ | **N/A** |
| 6 | ~~`routes/auth.ts`, `admin/routes/devices.ts`~~ | ~~115, 28–34~~ | ~~`body.deviceName`~~ | ~~DB write + HTTP response~~ | — | ~~Low–Medium~~ | **N/A** |
| 7 | ~~`routes/jobs.ts`, `services/scheduler.ts`~~ | ~~57–65, 111–117~~ | ~~`body.id` (job ID)~~ | ~~DB write + notification string~~ | — | ~~Low–Medium~~ | **N/A** |
| 8 | ~~`services/audit.ts`, `admin/routes/audit.ts`~~ | ~~37–42, 31–40~~ | ~~`c.req.path`~~ | ~~DB write + HTTP response~~ | — | ~~Low–Medium~~ | **N/A** |
| 9 | `routes/docker.ts`, `services/docker.ts` | 35, 64, 84–94 | `param :containerId` | Shell exec (via SSH) | Regex allowlist + `shellEscape` | Low (mitigated) | **STILL OPEN** |
| 10 | `routes/git.ts` | 94–106 | `body.branch` | Shell arg (spawn or SSH) | Regex allows `../`; `shellEscape` applied | Low | **STILL OPEN** |
| 11 | `routes/docker.ts` | 32–35 | `query.lines` | Shell arg (`--tail`) | `parseInt` + `isFinite`; no upper bound | Medium | **STILL OPEN** |
| 12 | Multiple routes | Various | `param :id` (serverId) | Error message (echo) | In-memory lookup; JSON-encoded | Low | **STILL OPEN** |
| 13 | `services/docker.ts` | 39–44 | `all` boolean (from `query.all`) | Shell script string (`/bin/sh -lc`) | Boolean coercion; values controlled | Low (architectural) | **STILL OPEN** |
| 14 | ~~`admin/routes/enrollments.ts`~~ | ~~74–75~~ | ~~`param :code`~~ | ~~DB DELETE~~ | — | ~~Very Low~~ | **N/A** |
| 15 | `routes/git.ts` | 56–59, 98–101 | `body.repoName` | Config allowlist lookup | Config-only path resolution | Negligible | **STILL OPEN** |
| 16 | `routes/services.ts` | 53–54, 72 | `param :action`, `param :name` | Shell arg + HTTP response | Strict action set; config allowlist | Negligible | **STILL OPEN** |
| 17 | `services/sshClient.ts` | 206, 214 | `sshKeyPath` from `servers.json` | Filesystem read | `existsSync` check; Zod `string().min(1)` | Low (config-only) | **STILL OPEN** |
| 18 | `db/index.ts`, `config.ts` | 8–16, 68–82 | Env vars `DATABASE_PATH`, `SERVERS_CONFIG_PATH` | Filesystem open | `path.resolve` normalizes | Very Low (env-only) | **STILL OPEN** |
| 19 | `routes/git.ts` | 74, 110 | `body.branch` | `git checkout` arg (spawn array / SSH) | `BRANCH_PATTERN` regex; no `--` separator | Low | **STILL OPEN** |

---

## Critical Findings

### ~~Finding 1 — Arbitrary Shell Command Execution via SSH Route~~ — N/A

**Resolution:** The `/api/servers/:id/ssh` route (`backend/src/routes/ssh.ts`) and `executeArbitraryCommand` function (`backend/src/services/serverContext.ts`) have been deleted entirely. The corresponding mobile client code (`SSHView.swift`, `SSHCommandResult.swift`, `NetworkService.runSSHCommand`) has also been removed.

---

### ~~Finding 2 — Arbitrary Shell Command Stored in DB and Executed on Schedule~~ — N/A

**Resolution:** Jobs are no longer API-mutable. They are defined statically in `servers.json` under a `jobs` array per server, loaded and Zod-validated at startup. The SQLite `jobs` table now only stores `(id, last_run_at)` runtime state. `POST /api/jobs` and `DELETE /api/jobs/:id` have been removed. The scheduler now calls `["/bin/zsh", "-c", command]` without the `-l` login flag.

---

## Medium Findings

### ~~Finding 3 — Command Strings Echoed Back in HTTP Responses~~ — N/A

**Resolution:** `POST /api/jobs` no longer exists. `GET /api/jobs` returns operator-defined values from config; this is acceptable.

---

### Finding 4 — Raw Command Output (stdout/stderr) Echoed in HTTP Responses — STILL OPEN

**Files:**
- `backend/src/routes/git.ts:75, 115` — output of git commands
- `backend/src/routes/services.ts:30, 38` — systemctl output
- `backend/src/routes/docker.ts:35, 38–39` — docker output

**Input:** Downstream of user-controlled inputs (`body.branch`, `:containerId`, etc.)
**Sink:** HTTP response body

Remote command output is placed directly into JSON responses without size bounds or sanitization. There is no output size limit — a command producing unbounded output will be buffered and returned in full. If a UI renders these strings as HTML, injection is possible.

**Fix:** Enforce a maximum output size (e.g., 1 MB). Ensure any UI that renders these strings escapes HTML (the mobile client does not — see mobile report UI-11).

---

### ~~Finding 5 — PEM Keys Stored Without Cryptographic Validation~~ — N/A

**Resolution:** `routes/auth.ts` and the entire ECDSA device-auth system have been deleted.

---

### Finding 11 — `query.lines` Has No Upper Bound for Docker Log Tail — STILL OPEN

*(Promoted to Medium given unbounded memory impact)*

**File:** `backend/src/routes/docker.ts:32-35`
**Input:** `query.lines`
**Sink:** Shell argument `docker logs --tail <lines>`

`parseInt` + `isFinite` fallback applied — no shell injection possible. However, there is no upper bound. A caller can pass `lines=999999999` to stream enormous log output and exhaust server memory.

**Fix:** Add `Math.min(lines, 10000)` after the `isFinite` check.

---

## Low–Medium Findings

### ~~Finding 6 — `deviceName` Stored and Reflected Without Content Sanitization~~ — N/A

**Resolution:** `routes/auth.ts` and the admin device management routes deleted.

---

### ~~Finding 7 — Job ID is User-Controlled Primary Key~~ — N/A

**Resolution:** Jobs are no longer API-creatable. Job IDs come from `servers.json`.

---

### ~~Finding 8 — Raw URL Path Stored in Audit Log Without Sanitization~~ — N/A

**Resolution:** `services/audit.ts` and `admin/routes/audit.ts` deleted.

---

## Low Findings

### Finding 9 — `containerId` Path Param Flows Into Shell Argument (Mitigated) — STILL OPEN

**Files:** `backend/src/routes/docker.ts:35, 64`, `backend/src/services/docker.ts:84–94`
**Input:** `param :containerId`
**Sink:** Shell exec via SSH (`docker logs --tail N <containerId>`, `docker <action> <containerId>`)

**Sanitization:** `assertContainerId` validates against `/^[A-Za-z0-9_.-]+$/` before use. For remote servers, the value is also passed as a discrete argument (not shell-interpolated). Both layers are present. The `.` character is unnecessary for Docker container IDs/names.

**Fix:** Remove `.` from `CONTAINER_ID_PATTERN` to minimize allowed surface.

---

### Finding 10 — `body.branch` Regex Permits `../` Sequences — STILL OPEN

**File:** `backend/src/routes/git.ts:94–106`
**Input:** `body.branch`
**Sink:** Shell argument (`git checkout <branch>` via spawn array or SSH)

`BRANCH_PATTERN = /^[A-Za-z0-9._\/-]+$/` allows `.`, `/`, and combinations. For local servers, `Bun.spawn` with an array arg is safe. For remote, `shellEscape` is applied. However, a branch value like `../../some/path` passes the regex and `git checkout` may interpret such values as path specs.

**Fix:** Reject `..` sequences and leading `-`: `if (/\.\./.test(branch) || branch.startsWith('-')) return 400`.

---

### Finding 12 — `param :id` (serverId) Reflected in Error Messages — STILL OPEN

**Files:** `backend/src/services/serverContext.ts:53–55`, multiple routes
**Input:** `param :id` URL path parameter
**Sink:** JSON error response body

No format validation applied to `:id`. The raw value appears in error strings like `` `Remote command failed on ${server.id}` `` returned to the client. JSON encoding escapes control characters, so exploitation is not practical. The concern is consistency and information leakage.

**Fix:** Add a character allowlist or format check on `:id` at the route level.

---

### Finding 13 — Docker Shell String Uses `/bin/sh -lc` (Architectural Risk) — STILL OPEN

**File:** `backend/src/services/docker.ts:39–44`
**Input:** `all` boolean derived from `query.all !== "false"`
**Sink:** `/bin/sh -lc "docker ps ${allFlag} --format '{{json .}}'"` — a shell-interpolated string

`allFlag` can only be `"-a"` or `""` — no injection is possible with current code. However, this is the **only location in the entire service layer** that builds a shell command via template string. All other `executeCommand` callers use argument arrays.

**Fix:** Replace with an argument array:
```typescript
["docker", "ps", ...(all ? ["-a"] : []), "--format", "{{json .}}"]
```

---

### ~~Finding 14 — Enrollment Token Delete Has No Format Validation~~ — N/A

**Resolution:** `admin/routes/enrollments.ts` deleted.

---

### Finding 15 — `sshKeyPath` From Config Accepts Any String — STILL OPEN

**File:** `backend/src/services/sshClient.ts:206, 214`
**Input:** `server.sshKeyPath` from `servers.json`
**Sink:** `readFileSync(server.sshKeyPath)` — filesystem read

Config-controlled, not API-controlled. An `existsSync` guard was added, but the Zod schema validates only `z.string().min(1)` — no path format restrictions.

**Fix:** Add `.startsWith("/")` enforcement (absolute paths only) to the Zod schema for `sshKeyPath`. Add a `statSync` permission check (`0o600` or stricter).

---

### Finding 16 — Env Var Path Resolution Lacks Directory Restriction — STILL OPEN

**Files:** `backend/src/db/index.ts:8–16`, `backend/src/config.ts:68–82`
**Input:** `DATABASE_PATH`, `SERVERS_CONFIG_PATH` environment variables
**Sink:** `path.resolve(process.cwd(), rawPath)` → filesystem open

`path.resolve` normalizes `..` sequences, so traversal attempts produce a well-formed absolute path that may be outside the project directory. Operator-controlled only.

**Fix:** Validate resolved paths are within an expected base directory if defense-in-depth is desired.

---

### Finding 19 — `git checkout` Missing `--` Separator Before Branch Argument — STILL OPEN

**File:** `backend/src/routes/git.ts:74, 110`
**Input:** `body.branch` (validated by `BRANCH_PATTERN`)
**Sink:** `["git", "-C", repo.path, "checkout", branch]` (spawn array or SSH command)

The branch argument is passed as the last positional argument without a `--` separator. Without `--`, git's argument parser disambiguates between revision names and path specs using its own heuristics, which can behave differently across git versions. A branch name that happens to match a git flag (e.g. one that starts with `--`, though currently blocked by `BRANCH_PATTERN`) or that git's own disambiguation logic interprets as a path spec could cause unexpected behavior. The `--` separator is the canonical, version-safe way to signal "everything after this is a ref name, not a flag."

**Fix:** Insert `"--"` before the branch argument:
```typescript
["git", "-C", repo.path, "checkout", "--", branch]
["git", "-C", repo.path, "pull", "origin", "--", branch]
```

---

## Top Remediation Priorities

1. **Finding 13 (Low / Architectural)** — The only shell-interpolation pattern remaining in the service layer (`docker.ts`). Rewrite as an argument array to eliminate the pattern entirely.

2. **Finding 11 (Medium)** — Add an upper bound cap (`Math.min(lines, 10000)`) on the `lines` docker log parameter to prevent memory exhaustion.

3. **Finding 10 (Low)** — Tighten `BRANCH_PATTERN` to reject `..` sequences and leading `-` to close the git path traversal vector.

4. **Finding 4 (Medium)** — Enforce a maximum output size on command output returned to clients, and ensure the mobile UI truncates error/output strings before display (see mobile-input-sanitization-report.md UI-11).

5. **Finding 15 (Low / Config)** — Add absolute-path enforcement and `0o600` permission check on `sshKeyPath`.
