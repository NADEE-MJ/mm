# Dead Code Report

**Scope:** Full codebase — `backend/src/` (TypeScript/Bun) and `mobile/Sources/` (Swift/SwiftUI)
**Last updated:** 2026-03-04 (post SSH-tunnel migration + post-audit-fix commits)

Status legend:
- **FIXED** — dead code removed or wired up
- **N/A** — the file/symbol no longer exists
- **STILL OPEN** — still present and unused

---

## Summary

| Category | Backend | Mobile | Total |
|---|---|---|---|
| Unused exports | 4 | 2 | 6 |
| Exported symbols never called externally | 2 | — | 2 |
| Placeholder / stub routes | 1 | 1 | 2 |
| Duplicate implementations | 1 | — | 1 |
| Schema / DDL duplication | 1 | — | 1 |
| Never-called infrastructure | 1 | 1 | 2 |
| Dead-code cluster (WebSocket/log-streaming) | 1 backend + 2 mobile | — | 3 |

---

## Backend (`backend/src/`)

### 1. `db` (Drizzle ORM instance) — exported but never imported at runtime — STILL OPEN
**File:** `backend/src/db/index.ts:85`

```ts
export const db = drizzle(sqlite, { schema });
```

`db` is never imported in any route, service, or middleware. All queries use the raw `sqlite` instance directly. The `migrate.ts` script imports `db` for migrations, but that is a standalone CLI invocation — not the live server. The Drizzle schema import on line 6 is also only used to construct `db`, making both dead weight at runtime.

**Impact:** Adds Drizzle ORM to the dependency footprint and confuses maintainers about which query layer is authoritative.

---

### 2. `schema` named re-export in `db/schema.ts` — STILL OPEN
**File:** `backend/src/db/schema.ts:52–59`

```ts
export const schema = {
  devices,
  enrollmentTokens,
  seenNonces,
  jobs,
  packageState,
  auditLog,
};
```

The named `schema` export is never imported by anything. `db/index.ts` imports `* as schema` (the module namespace) — not the named export. The named export is entirely redundant.

**Note:** Several of the table symbols listed here (`devices`, `enrollmentTokens`, `seenNonces`, `auditLog`) are also likely dead since the auth system was deleted — confirm and prune accordingly.

---

### 3. `requireServer` — exported from `serverContext.ts` but never imported externally — STILL OPEN
**File:** `backend/src/services/serverContext.ts:23–30`

```ts
export const requireServer = (serverId: string): ServerConfig => { ... }
```

`requireServer` is `export`-ed but no other file imports it. Both `executeCommand` and `executeArbitraryCommand` called it internally — `executeArbitraryCommand` is now deleted. The `export` keyword is dead; the function should be module-private.

---

### 4. `getState` (singular) — public method on `SSHClientPool`, never called externally — STILL OPEN
**File:** `backend/src/services/sshClient.ts:40–42`

```ts
getState(serverId: string): SSHConnectionState {
  return this.records.get(serverId)?.state ?? "unreachable";
}
```

No route or service ever calls `sshPool.getState(id)`. The plural `getStates` (line 44) is the live one used by the servers route.

---

### 5. `logsRoutes` — stub route that always returns 501 — STILL OPEN
**File:** `backend/src/routes/logs.ts:1–12`

```ts
logsRoutes.get("/:id/logs/:source", (c) => {
  return c.json(
    { error: "WebSocket log streaming is not implemented yet in this scaffold" },
    501,
  );
});
```

Registered in `app.ts`, reachable but unconditionally returns `501 Not Implemented`. The corresponding mobile `LogStreamView` and `WebSocketManager` were also built against this unimplemented endpoint (see Mobile section).

---

### 6. `resolveProjectRelativePath` — duplicated in two files — STILL OPEN
**Files:**
- `backend/src/config.ts:68–74`
- `backend/src/db/index.ts:8–14`

Identical function defined twice. Neither file imports the other's copy.

---

### 7. `AppVariables` — exported from `types.ts` but never imported anywhere — NEW
**File:** `backend/src/types.ts:1`

```ts
export type AppVariables = Record<string, never>;
```

`AppVariables` is defined as the Hono context generic type (intended for `Hono<{ Variables: AppVariables }>`), but is never imported by `app.ts` or any route file. The Hono app and all routes use the bare `Hono` type with no context generic applied. The file exists solely for this single dead export.

**Impact:** Misleads maintainers into thinking a typed Hono context is in use when it is not.

---

### 8. `db/index.ts` inline raw SQL duplicates Drizzle schema — NEW
**File:** `backend/src/db/index.ts:30–40`

```ts
sqlite.exec(`
CREATE TABLE IF NOT EXISTS jobs ( ... );
CREATE TABLE IF NOT EXISTS package_state ( ... );
`);
```

The same tables (`jobs`, `package_state`) are also defined in `backend/src/db/schema.ts` using Drizzle's schema builder. The raw SQL `CREATE TABLE IF NOT EXISTS` block runs unconditionally at every startup, bypassing Drizzle's migration system. The migration file (`0000_initial.sql`, if present) becomes a no-op. This creates two diverging sources of truth for the schema: if a column is added in `schema.ts` for a future migration, the raw SQL will silently win on a fresh database and ignore the migration.

**Impact:** Schema drift is possible between fresh installs (raw SQL wins) and migrated installs (migration file applies); the divergence is silent.

**Fix:** Remove the `sqlite.exec(...)` raw DDL block. Let migrations (via `db:migrate`) exclusively own table creation. Add the migration SQL to the proper `0000_initial.sql` file.

---

### Previously reported items now resolved or N/A

| Finding | Status |
|---|---|
| `isMutatingRequest` in `deviceAuth.ts` | **N/A** — `deviceAuth.ts` deleted |
| `EnrollmentTokenRow` type duplication in `auth.ts` | **N/A** — `auth.ts` deleted |
| `NetworkService.signedRequest` — zero call sites | **N/A** — method removed in SSH migration |

---

## Mobile (`mobile/Sources/`)

### 7. `AppLog.info` — never called anywhere — STILL OPEN (CHANGED)
**File:** `mobile/Sources/Services/AppLogging.swift:3–12`

`AppLog.info` is **never called anywhere** in the codebase. `AppLog.error` is called only in `WebSocketManager.swift` (lines 36, 46), which is itself unused (see finding 8). If the WebSocket cluster is deleted, `AppLog` becomes entirely dead.

---

### 8. `WebSocketManager` — singleton never used — STILL OPEN
**File:** `mobile/Sources/Services/WebSocketManager.swift:3–49`

`WebSocketManager.shared` is never accessed anywhere. All four methods (`connect`, `disconnect`, `send`, `receiveNextMessage`) are unreachable from any View or Service. The class was rebuilt during the SSH migration but remains unconnected. The backend endpoint is also a 501 stub (finding 5).

---

### 9. `LogStreamView` — View never presented anywhere — STILL OPEN
**File:** `mobile/Sources/Views/LogStreamView.swift:3–19`

```swift
struct LogStreamView: View {
    let serverId: String
    let source: String
    @State private var text = "Log streaming placeholder"
    ...
}
```

Never navigated to or presented from any other View. Contains a hardcoded placeholder string. The corresponding backend endpoint returns 501.

---

### 10. `AppTheme.textPrimary` and `AppTheme.textSecondary` — defined, never referenced — STILL OPEN
**File:** `mobile/Sources/Theme/AppTheme.swift:7–8`

```swift
static let textPrimary = Color(red: 0.12, green: 0.14, blue: 0.16)
static let textSecondary = Color(red: 0.33, green: 0.36, blue: 0.40)
```

`AppTheme.accent`, `AppTheme.background`, and `AppTheme.card` are used by Views. `textPrimary` and `textSecondary` are not referenced anywhere.

---

### 11. `ConfirmActionSheet` — component never presented — STILL OPEN
**File:** `mobile/Sources/Views/Components/ConfirmActionSheet.swift:3–37`

A reusable `ConfirmActionSheet` view is defined with a full navigation stack, destructive confirm button, and cancel button. It is never used by any other View. Both `ServicesView` and `DockerView` implement their own inline `alert` modifiers rather than using this component.

---

### Previously reported items now resolved or N/A

| Finding | Status |
|---|---|
| `AppLog.info` never called in production | **CHANGED** — `AppLog.info` is now called in `SSHConnectionManager.swift`; `AppLog.error` is still only called in the dead `WebSocketManager`. The `info` path is no longer entirely dead, but `error` remains reachable only through dead code. |
| `NetworkService.signedRequest` — zero call sites | **N/A** — method removed in SSH migration |
| `ServerDetailView` passes `authManager` but never uses it | **FIXED** — `authManager` parameter removed |
| `AppConfiguration.swift` dead code | **N/A** — file deleted |

---

## Cross-Cutting: The WebSocket / Log Streaming Dead Cluster

Findings 5, 7, 8, and 9 form a coherent dead cluster — an incomplete feature that was scaffolded end-to-end but never connected:

| Layer | Dead symbol | File |
|---|---|---|
| Backend route | `logsRoutes` 501 stub | `routes/logs.ts` |
| Mobile service | `WebSocketManager` | `Services/WebSocketManager.swift` |
| Mobile service | `AppLog.error` (via WebSocketManager) | `Services/AppLogging.swift:11` |
| Mobile view | `LogStreamView` | `Views/LogStreamView.swift` |

The entire cluster can be deleted or finished as a unit.

---

## Recommended Actions

| Priority | Action | Files |
|---|---|---|
| High | Delete the WebSocket/log cluster or wire it up | `routes/logs.ts`, `WebSocketManager.swift`, `LogStreamView.swift`, `AppLog.error` |
| High | Remove `export` from `requireServer` | `services/serverContext.ts:23` |
| High | Remove `getState` singular or add a caller | `services/sshClient.ts:40` |
| Medium | Remove unused `db` Drizzle export (or commit to using it) | `db/index.ts:85` |
| Medium | Remove duplicate `resolveProjectRelativePath` | `config.ts:68`, `db/index.ts:8` |
| Medium | Replace raw DDL block with proper migration file | `db/index.ts:30–40`, `db/schema.ts` |
| Medium | Delete `ConfirmActionSheet` or wire it in | `Components/ConfirmActionSheet.swift` |
| Low | Remove `AppVariables` type or apply it to the Hono app | `types.ts:1`, `app.ts` |
| Low | Remove named `schema` re-export; prune deleted-auth table symbols | `db/schema.ts:52` |
| Low | Remove `AppTheme.textPrimary` and `AppTheme.textSecondary` | `Theme/AppTheme.swift:7–8` |
