# Plan: ServerPilot — iOS Server Controller App

## Context

The user's Mac Mini runs several services managed today via a Discord bot (`references/discord-bot`). The bot is clunky — it requires Discord, has awkward UX for a single-person admin tool, and lacks a native mobile feel. The goal is a dedicated, extremely secure iOS 26 SwiftUI app (`ServerPilot`) paired with a Bun/Hono backend daemon on the Mac Mini.

The Mac Mini is the **always-on control plane**. It also needs to manage a second (older) server that is not always on — the iPhone can send a **Wake-on-LAN** magic packet via the Mac Mini, then issue commands to the old server over **SSH** proxied through the Mac Mini backend. The iOS app provides identical controls for both servers via a server-picker UI.

Security is the top priority: the app can run arbitrary system commands, control Docker, restart services, and manage git branches on both servers.

**Folder:** `server-pilot/`
**App name placeholder:** `ServerPilot`

---

## Confirmed Decisions

| Question | Answer |
|---|---|
| Backend stack | **Bun + Hono** (following `references/pepperminty` patterns) |
| TLS | **Tailscale WireGuard tunnel** for transport; no public TLS termination required |
| Network | **Tailscale-only access** for app API and SSH |
| Services config | **Config file** (allowlist of named services) |
| Push notifications | **Pushover API** (server calls Pushover → phone notification) |

---

## Security Architecture (Multi-Layer)

### Layer 1 — Device Identity: Two-Key ECDSA Model (Secure Enclave)

**Two Secure Enclave keys per enrolled device:**

**Key A — Device identity (routine requests, no per-request biometric prompt)**
- Created with `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` — no explicit prompt per signing.
- **Access is gated by the app-level Face ID lock.** You must pass Face ID to open the app before any Key A calls are made. Background refresh / polling happen only while the app is in foreground (after Face ID already passed) — no silently-running background requests.
- Used for all read operations: metrics, service status, docker list, log streaming, etc.

**Key B — Destructive operations (explicit Face ID required per use)**
- Created with `kSecAccessControlBiometryCurrentSet` — signing requires explicit biometric on every call.
- Used only for: service start/stop/restart, docker stop/restart, git pull/checkout, SSH commands, job changes, package record.
- Mirrors Apple Pay: card stored in SE, Face ID required to authorize payment.

Both keys share the same `deviceId`; the server stores two public keys per device (`keyA_pem`, `keyB_pem`). The request header `X-Key-Type: A|B` tells the server which key to verify against.

**Canonical signing input** (identical for both keys, colon-separated, UTF-8):
```
{timestamp}:{nonce}:{METHOD}:{host}:{path+query}:{bodyHash}
```
- `timestamp` — Unix seconds as decimal integer string (e.g. `"1709000000"`)
- `nonce` — UUID v4 lowercase with hyphens
- `METHOD` — uppercase HTTP verb
- `host` — the `Host` header value as sent (e.g. `"api.example.com"`) — included to prevent cross-domain replay if hostname ever changes
- `path+query` — **the exact path+query string as it will appear on the wire**, percent-encoded, starting with `/`. No sorting or normalization of query params.
- `bodyHash` — **always present**, lowercase hex SHA-256 of the **exact body bytes that will be sent**. Build the request body first, hash those bytes, then sign — never re-serialize JSON after signing. Empty/no-body requests use SHA-256 of zero bytes: `e3b0c44298fc1c149afbf4c8996fb924...855`. Never omit this field.

**Headers sent:** `X-Timestamp`, `X-Nonce`, `X-Device-ID`, `X-Key-Type`, `X-Signature` (base64 DER ECDSA P-256)

Server verifies ECDSA signature using **Bun's native `crypto.subtle.importKey` + `crypto.subtle.verify`** directly — no `jose` or other third-party library for this path, minimizing dependency surface for security-critical code.

### Layer 2 — Anti-Replay: Timestamp + Persisted Nonce Set

- Server rejects requests where `|now - timestamp| > 30 seconds` (clock skew protection)
- **Nonce deduplication** closes the replay window: any duplicate nonce → `403`
- **Nonces are persisted in SQLite** (`seen_nonces` table), not just in-memory — this survives server reboots. A background cleanup job deletes entries older than 30 seconds. An in-memory cache is layered on top for speed.
  - On startup: delete all expired nonces from DB (catches the reboot-replay edge case by purging stale entries)
  - On every request: check in-memory map first, then DB; write to both
- Unknown or disabled device keys → `403 Forbidden`
- **Why no JWT?** A stolen JWT could be used from any machine for its lifetime, defeating the Secure Enclave's device-possession guarantee. Per-request signing ensures every call cryptographically proves the private key is present in hardware on the authorized phone.

### Layer 3 — Idempotency for Destructive Operations (reliability, not security)
- For all mutating endpoints (service restart, docker stop, job delete, git pull, etc.), the iOS app sends an `Idempotency-Key: <UUID>` header
- Server stores the result of each unique key in an `idempotency_cache` table (key, result JSON, statusCode, created_at) with a 5-minute TTL
- If the same `(deviceId, key)` pair is seen again within 5 minutes, the server returns the cached result without re-executing. Scoped to `deviceId` to prevent a leaked idempotency key UUID from one device returning results for another.
- The iOS app generates a new UUID per intent, not per HTTP attempt (retries reuse the same key)

### Layer 4 — App-Level Biometric Lock (gates all Key A use)
- `BiometricAuthManager` shows a lock screen overlay and calls `LAContext.evaluatePolicy(.deviceOwnerAuthentication)` when:
  - App cold-launches
  - App returns to foreground from background (any backgrounding — even a brief switch to another app)
- Implemented via `scenePhase` handler in `ServerPilotApp.swift`: `.active` → trigger lock if not already unlocked (same pattern as mm)
- **You cannot view any content or trigger any API call without passing this Face ID check first.** Key A is never used outside an authenticated session.
- Once inside: Key A signs requests silently (no per-request prompt). For destructive ops: Key B adds a second explicit Face ID prompt.
- Three biometric moments: (1) Face ID every time app becomes active (gates Key A), (2) Key A — silent, device-unlocked, (3) Key B — explicit Face ID per destructive signing

### Layer 5 — Transport Security
- All app/API traffic runs over the Tailscale WireGuard tunnel.
- Backend is reachable via Tailscale IP (`100.x.y.z`) or MagicDNS (`*.ts.net`).
- HTTP is acceptable inside the tailnet because transport encryption and mutual device identity are provided by Tailscale.
- No Cloudflare/public-domain dependency for the ServerPilot API path.
- All secrets stay in `.env`, never in source.

### Device Recovery & Revocation

- **Lost phone:** SSH to Mac Mini → hit localhost admin panel → disable or delete the device entry. The lost phone's key is now rejected.
- **Phone upgrade:** while you still have both phones, enroll the new device via setup, SSH to register the new public key, then disable the old entry via admin panel.
- **Emergency (locked out of app):** SSH to Mac Mini is the ultimate fallback — the admin panel is localhost-only so it's always accessible via SSH tunnel.
- **Re-enrollment after Secure Enclave wipe (restore/reset):** the old key is gone from the SE; re-run setup to generate a new key, SSH to register it.

### Server-Side Hardening

**Rate limiting (single layer + abuse slowing):**
- **Per-device post-auth limit:** max 120 req/min per `deviceId` after signature verification. Catches compromised but valid device keys used in scripted attacks.
- Repeated auth failures can still trigger temporary tarpit behavior for abuse slowing, but internet-wide pre-auth IP filtering is removed in the Tailscale-only model.

**Audit logging:**
- Every authenticated request logged to `audit_log` table in SQLite: `{ id, deviceId, method, path, statusCode, timestampMs, failed }`
- **Failed auth events also logged** (bad signature, unknown device, replay rejection, rate limit violation) with `failed=true` and a `failReason` field — these are the most security-relevant entries
- Logged after the handler responds (non-blocking)
- Retention: configurable, default 10,000 most recent entries (pruned on insert)
- Queryable via the localhost admin panel

**ECDSA verification (avoiding timing side-channels):**
- Use Bun's native `crypto.subtle.importKey` + `crypto.subtle.verify` directly — no `jose` or other third-party library. This minimizes dependency surface for the most security-critical code path and uses platform crypto to avoid custom timing-sensitive code.
- Do not compare signatures with `===` or string equality at any point

**Response signing (not implemented):**
- Tailscale transport + per-request device signatures are sufficient for this personal threat model
- Response signing (signing every server response so the app can verify it came from the real server) would close this gap but adds significant complexity for marginal benefit — skipping for now

### Localhost-Only Admin Panel

A second Hono server binds to `127.0.0.1:ADMIN_PORT` (default 4311) **only** — not `0.0.0.0`. It is not reachable from any device on the network, only via direct localhost or SSH tunnel (`ssh -L 4311:localhost:4311 user@server`). Protected by a static `ADMIN_TOKEN` from env (belt-and-suspenders even on localhost).

Admin routes:
```
GET    /devices           → list all registered devices (id, name, enabled, lastSeenAt)
PATCH  /devices/:id       → enable/disable device { enabled: true|false }
DELETE /devices/:id       → permanently remove device
POST   /enrollments       → generate a new 256-bit enrollment token { deviceName }
                            returns { code: "<64-hex>", expiresAt }
GET    /enrollments       → list all pending/invalidated tokens (code, deviceName, status, failedAttempts)
DELETE /enrollments/:code → cancel/clear a token (pending, expired, or permanently invalidated)
GET    /audit-log?limit=  → view recent audit log entries (includes failed auth events)
```

`ADMIN_TOKEN` must be long and random (e.g., 48 hex chars from `openssl rand -hex 24`). Document this requirement in `.env.example`.

---

## Project Structure

```
server-pilot/
├── backend/
│   ├── src/
│   │   ├── index.ts              # Entry: Bun.serve() — mirrors pepperminty pattern
│   │   ├── app.ts                # Hono app factory, middleware stack
│   │   ├── env.ts                # dotenv loading with fallback paths
│   │   ├── config.ts             # Type-safe env config object
│   │   ├── db/
│   │   │   ├── index.ts          # bun:sqlite + Drizzle setup (WAL mode, FK on)
│   │   │   ├── schema.ts         # devices, enrollment_tokens, seen_nonces, idempotency_cache, jobs, package_state, audit_log
│   │   │   └── migrations/       # Drizzle-kit generated migrations
│   │   ├── middleware/
│   │   │   ├── deviceAuth.ts     # ECDSA signature verification on every request
│   │   │   └── logger.ts         # Request logging (redacts sensitive headers)
│   │   ├── routes/
│   │   │   ├── auth.ts           # POST /auth/enroll (unauthenticated, token-gated)
│   │   │   ├── servers.ts        # GET /servers (list + online status)
│   │   │   ├── metrics.ts        # GET /servers/:id/metrics
│   │   │   ├── services.ts       # GET+POST /servers/:id/services/...
│   │   │   ├── docker.ts         # GET+POST /servers/:id/docker/...
│   │   │   ├── git.ts            # GET+POST /servers/:id/git/...
│   │   │   ├── packages.ts       # GET+POST /servers/:id/packages/...
│   │   │   ├── wol.ts            # POST /servers/:id/wake
│   │   │   ├── ssh.ts            # POST /servers/:id/ssh (arbitrary cmd)
│   │   │   ├── logs.ts           # WS /servers/:id/logs/:source
│   │   │   └── jobs.ts           # CRUD /jobs (Mac Mini scheduler)
│   │   ├── admin/                # Bound to 127.0.0.1:ADMIN_PORT only
│   │   │   ├── adminApp.ts       # Separate Hono app for localhost admin
│   │   │   └── routes/
│   │   │       ├── devices.ts    # CRUD /devices (disable, delete)
│   │   │       ├── enrollments.ts # POST /enrollments (generate token, admin-only)
│   │   │       └── audit.ts      # GET /audit-log
│   │   └── services/
│   │       ├── serverContext.ts  # Resolves serverId → local exec or SSH session
│   │       ├── systemInfo.ts     # CPU/RAM/disk for local execution
│   │       ├── docker.ts         # dockerode for local; ssh exec for remote
│   │       ├── processRunner.ts  # Safe subprocess exec (array args, no shell injection)
│   │       ├── sshClient.ts      # ssh2 connection pool — exec, stream, keepalive
│   │       ├── wol.ts            # dgram UDP magic packet sender
│   │       ├── scheduler.ts      # node-cron job manager with persistence
│   │       └── pushover.ts       # Pushover API client for alerts
│   ├── config/
│   │   └── servers.json          # All servers config: local Mac Mini + remote servers
│   ├── data/
│   │   └── server-pilot.db       # SQLite database (gitignored)
│   ├── package.json              # Bun workspaces, hono, drizzle-orm, zod, etc.
│   ├── drizzle.config.ts
│   ├── tsconfig.json
│   ├── .env.example
│   └── server-pilot.service      # systemd service file for the daemon
└── mobile/
    ├── project.yml               # XcodeGen config (mirrors mm pattern)
    ├── Config/
    │   └── App.xcconfig          # API_BASE_URL injection
    └── Sources/
        ├── ServerPilotApp.swift  # App entry, @Observable managers, scene lifecycle
        ├── Models/
        │   ├── Server.swift           # ServerInfo (id, name, type, online status)
        │   ├── SystemMetrics.swift
        │   ├── ServiceStatus.swift
        │   ├── Container.swift
        │   ├── Job.swift
        │   └── PackageState.swift
        ├── Services/
        │   ├── DeviceKeyManager.swift    # Secure Enclave key gen, signing, public key export
        │   ├── AuthManager.swift         # Device registration state, registration polling
        │   ├── NetworkService.swift      # Signs every request via DeviceKeyManager
        │   ├── WebSocketManager.swift    # Live log streaming (URLSessionWebSocketTask)
        │   ├── BiometricAuthManager.swift # Face ID lock screen + Secure Enclave key gate (mirrors mm)
        │   ├── AppConfiguration.swift    # Server URL + Tailscale host validation
        │   └── AppLogging.swift          # Categorized logging (mirrors mm)
        ├── Views/
        │   ├── SetupView.swift           # First-run: paste enrollment token, generate SE keys
        │   ├── ServerListView.swift      # Home: card per server, online status, Wake button
        │   ├── ServerDetailView.swift    # Tab host for a selected server (wraps all below)
        │   ├── DashboardView.swift       # Metric gauges, alert banner, quick actions
        │   ├── ServicesView.swift        # Service cards: status badge, start/stop/restart
        │   ├── DockerView.swift          # Container list, logs sheet, manage actions
        │   ├── LogStreamView.swift       # Full-screen WebSocket log tail with search/pause
        │   ├── JobsView.swift            # Cron jobs (Mac Mini only tab)
        │   ├── GitView.swift             # Pull, checkout branch
        │   ├── PackagesView.swift        # Days since update, check available
        │   ├── SSHView.swift             # Arbitrary SSH command input + streaming output
        │   ├── SettingsView.swift        # Server URL, cert pin, biometric toggle
        │   └── Components/
        │       ├── ServerCardView.swift       # Server card with online indicator + Wake button
        │       ├── MetricGaugeView.swift      # Circular CPU/RAM/disk gauge
        │       ├── StatusBadgeView.swift      # Running/stopped/error pill
        │       └── ConfirmActionSheet.swift   # Destructive action confirmation dialog
        └── Theme/
            └── AppTheme.swift            # Colors, typography constants
```

---

## Backend: Bun + Hono (following pepperminty)

**Dependencies (package.json):**
```
hono, @hono/zod-validator
drizzle-orm, drizzle-kit
bun:sqlite (built-in)
zod
dockerode
node-cron
ssh2
dotenv
```
Note: `dgram` (UDP for WoL) is built into Node/Bun — no extra package needed. No TOTP library needed.

**Middleware stack (app.ts pattern from pepperminty):**
```
All routes → logger → deviceAuth (ECDSA signature verify on every request)
Destructive routes → confirm dialog on client side only
```

**deviceAuth.ts — request verification order:**
```typescript
// Nonce: in-memory Map (speed) + SQLite seen_nonces table (reboot persistence)
// On startup: DELETE FROM seen_nonces WHERE expires_at < now
// setInterval(cleanup, 30_000)

// Verification steps (in order):
// 1. Parse X-Timestamp, X-Nonce, X-Device-ID, X-Key-Type (A|B), X-Signature
// 2. Check timestamp within ±30s
// 3. Check nonce not in memory map → then check DB → 403 + log if replay detected
// 4. Look up deviceId in DB, check enabled=true; select keyA_pem or keyB_pem per X-Key-Type
// 5. Verify ECDSA: crypto.subtle.importKey(spki, {name:"ECDSA",namedCurve:"P-256"}) → crypto.subtle.verify()
// 6. Per-device post-auth rate limit (120 req/min)
// 7. Write nonce to memory map + SQLite with 30s TTL
// 8. For mutating routes: check Idempotency-Key header; return cached response if seen within 5min
// 9. Update device.lastSeenAt, audit log
```

**Multi-server architecture:**
- All routes are scoped under `/servers/:serverId/...`
- `serverId=local` → executes directly on Mac Mini (child_process, dockerode)
- `serverId=<remote-id>` → proxies commands over SSH via `ssh2` library
- Mac Mini backend maintains persistent SSH connection pool to known-online remote servers
- **SSH connection state enum per server:** `connected | connecting | unreachable` — surfaced in `GET /servers` response and shown as status indicators on iOS server cards
- **Reconnect behavior:** exponential backoff with ±20% jitter (1s → 2s → 4s → ... → 30s max). On WoL, reset backoff and start connecting immediately. If a server's boot time is ~30s, the pool will have connected by the time the iOS app tries to issue commands.
- Connection health checked via keepalive (ssh2 `keepaliveInterval` option); if keepalive fails → mark `unreachable`, begin reconnect cycle

**Key routes:**
```
GET  /servers
  → list all configured servers + online status (ping / ssh reachable)

POST /servers/:id/wake
  → send WoL magic packet via UDP broadcast (dgram built-in)
  → only valid for remote servers with a configured MAC address

GET  /servers/:id/metrics
  → local: os + child_process
  → remote: ssh exec "cat /proc/meminfo && df -h && uptime && ..."
  → { cpu, memory, disk, uptime, loadAvg }

GET  /servers/:id/services
  → systemctl status <unit> for each configured service
  → local: child_process; remote: ssh exec

POST /servers/:id/services/:name/start|stop|restart
  body: {}
  → systemctl <action> via local or SSH (auth is the ECDSA sig + Face ID)

GET  /servers/:id/docker/containers?all=true
  → local: dockerode; remote: ssh exec "docker ps --format json"

GET  /servers/:id/docker/:containerId/logs?lines=100
POST /servers/:id/docker/:containerId/start|stop|restart
  body: {}

WS   /servers/:id/logs/:source
  → WebSocket auth via first message (not URL/headers — WebSocket handshake can't carry custom headers):
    1. Client connects (no credentials in URL)
    2. Client immediately sends: { type: "auth", deviceId, timestamp, nonce, signature, keyType }
       signature covers: timestamp:nonce:GET:/servers/:id/logs/:source:<empty-body-hash>
    3. Server validates signature (same deviceAuth logic); sends { type: "auth_ok" } or closes
    4. Streaming begins
  → local: spawn tail / docker logs; remote: ssh exec streaming
  → Connection closed on auth failure or server disconnect

GET  /servers/:id/git
  → list configured repos and current branch for this server

POST /servers/:id/git/pull   body: { repoName, force? }
POST /servers/:id/git/checkout  body: { repoName, branch }

GET  /servers/:id/packages
POST /servers/:id/packages/record  body: {}

POST /servers/:id/ssh
  body: { command }
  → arbitrary SSH command (remote only); local equivalent runs via processRunner
  → gated by ECDSA device signature + Face ID (same as all routes)

GET  /jobs → list scheduled jobs (Mac Mini only, not per-server)
POST /jobs  body: { id, command, schedule }
DELETE /jobs/:id  body: {}

```

**servers.json config:**
```json
{
  "servers": [
    {
      "id": "mac-mini",
      "name": "Mac Mini",
      "type": "local",
      "services": [
        { "name": "nginx", "displayName": "Nginx", "systemdUnit": "nginx" },
        { "name": "discord-bot", "displayName": "Discord Bot", "systemdUnit": "discord-bot" }
      ],
      "git": [
        { "name": "discord-bot", "path": "/opt/discord-bot" }
      ]
    },
    {
      "id": "old-server",
      "name": "Old Server",
      "type": "remote",
      "host": "192.168.1.x",
      "port": 22,
      "user": "nadeem",
      "sshKeyPath": "/home/nadeem/.ssh/old-server-key",
      "mac": "AA:BB:CC:DD:EE:FF",
      "broadcastAddress": "192.168.1.255",
      "services": [
        { "name": "app", "displayName": "My App", "systemdUnit": "my-app" }
      ],
      "git": []
    }
  ],
  "alerts": {
    "cpu_threshold": 80,
    "memory_threshold": 80,
    "disk_threshold": 90,
    "pushover_user_key": "",
    "pushover_api_token": ""
  }
}
```

---

## iOS App: SwiftUI / iOS 26 (following mm)

**Build system:** XcodeGen (`project.yml`) — same as mm
**Dependencies (SPM only):** zero third-party libraries (Security framework + CryptoKit are built in)

**DeviceKeyManager.swift — Two Secure Enclave keys:**
```swift
// Key A: device identity — accessible when device is unlocked, no per-use biometric prompt
let accessA = SecAccessControlCreateWithFlags(nil,
    kSecAttrAccessibleWhenUnlockedThisDeviceOnly, [.privateKeyUsage], nil)

// Key B: destructive operations — Face ID required on every signing operation
let accessB = SecAccessControlCreateWithFlags(nil,
    kSecAttrAccessibleWhenUnlockedThisDeviceOnly, [.privateKeyUsage, .biometryCurrentSet], nil)

func makeKey(tag: String, access: SecAccessControl) -> SecKey { ... }

// Canonical signing input — must match server exactly:
// "{timestamp}:{nonce}:{METHOD}:{host}:{path+query}:{bodyHash}"
// - Build body bytes first, hash them, then sign
// - path+query = exact wire string (no normalization or param sorting)
// - bodyHash = lowercase hex SHA-256; always present; empty body = "e3b0c44..."
let bodyHash = SHA256.hash(data: bodyBytes).map { String(format: "%02x", $0) }.joined()
let signingInput = "\(timestamp):\(nonce):\(method):\(host):\(pathAndQuery):\(bodyHash)"
let messageData = signingInput.data(using: .utf8)!
let key = isDestructive ? keyB : keyA
let signature = SecKeyCreateSignature(key, .ecdsaSignatureMessageX962SHA256, messageData, nil)
// X-Key-Type header = isDestructive ? "B" : "A"
```

**Auth flow:**
1. App becomes active → `BiometricAuthManager` shows lock screen → Face ID required
2. If no device keys exist → `SetupView` (paste enrollment token, generate Key A + Key B in Secure Enclave)
3. Routine requests → Key A signs silently (no prompt, device already unlocked by Face ID)
4. Destructive actions → `ConfirmActionSheet` → user taps Confirm → Key B signing triggers Face ID prompt

**scenePhase / biometric lock debounce:**
- Set `needsRelock = true` when scene transitions through `.background` (user actually left the app)
- On `.active`, only prompt if `needsRelock == true` AND `!isPrompting`
- Set `isPrompting = true` before calling `LAContext.evaluatePolicy`, reset when done — prevents the Face ID system overlay itself from triggering a second prompt (the overlay causes an `.inactive` → `.active` cycle on some OS versions)
- `needsRelock` is NOT set when `.inactive` fires without a prior `.background` (covers system dialogs/alerts/sheets)
- Mirrors mm's existing pattern — carry it over directly

**Network error / offline behavior:**
- **Read operations** (metrics, status, docker list): show last-known stale data with a banner ("Last updated X seconds ago — backend unreachable"), auto-retry every 10 seconds
- **Destructive operations** (restart, stop, delete, git pull): **fail immediately** — show error toast, never queue. The user must explicitly tap again to retry. A queued restart firing 10 minutes later after reconnection would be dangerous.
- No offline queue for any operations — this is not an offline-first app; it's a control plane that requires live connectivity

---

## Drizzle Schema (db/schema.ts)

```typescript
export const devices = sqliteTable("devices", {
  id: text("id").primaryKey(),               // UUID
  name: text("name").notNull(),
  keyAPem: text("key_a_pem").notNull(),      // routine requests (no biometric prompt)
  keyBPem: text("key_b_pem").notNull(),      // destructive ops (Face ID required)
  enabled: integer("enabled", { mode: "boolean" }).default(true),
  createdAt: integer("created_at", { mode: "timestamp_ms" }).notNull(),
  lastSeenAt: integer("last_seen_at", { mode: "timestamp_ms" }),
});

export const enrollmentTokens = sqliteTable("enrollment_tokens", {
  code: text("code").primaryKey(),           // 64-char hex (256-bit random)
  deviceName: text("device_name").notNull(),
  expiresAt: integer("expires_at", { mode: "timestamp_ms" }).notNull(),
  usedAt: integer("used_at", { mode: "timestamp_ms" }),
  failedAttempts: integer("failed_attempts").default(0),
});

export const seenNonces = sqliteTable("seen_nonces", {
  nonce: text("nonce").primaryKey(),
  deviceId: text("device_id").notNull(),
  expiresAt: integer("expires_at", { mode: "timestamp_ms" }).notNull(),
});
// Cleanup: delete WHERE expires_at < now() on startup and every 30s

export const idempotencyCache = sqliteTable("idempotency_cache", {
  // composite primary key: (deviceId, key) — prevents cross-device key collision
  deviceId: text("device_id").notNull(),
  key: text("key").notNull(),                // Idempotency-Key header UUID
  statusCode: integer("status_code").notNull(),
  responseJson: text("response_json").notNull(),
  createdAt: integer("created_at", { mode: "timestamp_ms" }).notNull(),
  expiresAt: integer("expires_at", { mode: "timestamp_ms" }).notNull(),  // +5 minutes
}, (t) => [primaryKey({ columns: [t.deviceId, t.key] })]);

export const jobs = sqliteTable("jobs", {
  id: text("id").primaryKey(),
  command: text("command").notNull(),
  schedule: text("schedule").notNull(),
  enabled: integer("enabled", { mode: "boolean" }).default(true),
  createdAt: integer("created_at", { mode: "timestamp_ms" }).notNull(),
  lastRunAt: integer("last_run_at", { mode: "timestamp_ms" }),
});

export const packageState = sqliteTable("package_state", {
  id: integer("id").primaryKey({ autoIncrement: true }),
  lastUpdatedAt: integer("last_updated_at", { mode: "timestamp_ms" }),
});

export const auditLog = sqliteTable("audit_log", {
  id: integer("id").primaryKey({ autoIncrement: true }),
  deviceId: text("device_id"),            // null for requests that fail before device lookup
  method: text("method").notNull(),
  path: text("path").notNull(),
  statusCode: integer("status_code").notNull(),
  timestampMs: integer("timestamp_ms").notNull(),
  failed: integer("failed", { mode: "boolean" }).default(false),
  failReason: text("fail_reason"),        // "bad_signature" | "replay" | "rate_limit" | "unknown_device" | "expired_token"
});
// Keep latest 10,000 entries; prune on insert when over limit
```

---

## Device Registration Flow

The Mac Mini can't scan a QR code and manually copying a raw ECDSA public key is impractical. Instead, use a **server-generated enrollment token** — a single-use, high-entropy code transferred via macOS Universal Clipboard (or AirDrop):

**Server side (one-time per new device):**
1. SSH tunnel to Mac Mini admin panel: `ssh -L 4311:localhost:4311 user@server`
2. `POST /admin/enrollments { deviceName: "iPhone 16 Pro" }` via curl or browser
3. Returns a **64-character hex token** (`crypto.randomBytes(32).toString('hex')`) — 256 bits of entropy, valid for 10 minutes, stored in `enrollment_tokens` DB table
4. Copy the token on your Mac → it's instantly available on iPhone via **Universal Clipboard** (Handoff/iCloud)

**iPhone side (first launch):**
1. `SetupView` shows a text field: "Paste enrollment code from server"
2. User long-presses → Paste (from Universal Clipboard)
3. App generates two ECDSA P-256 key pairs in Secure Enclave: Key A (no per-use biometric) and Key B (Face ID required per signing)
4. App sends `POST /auth/enroll { code: "<64-hex>", keyAPem: "...", keyBPem: "...", deviceName: "iPhone 16 Pro" }` — the **only unauthenticated endpoint**
5. Server verifies:
   - Code exists in DB, not expired, not yet used
   - Rate limit on `/auth/enroll`: max 5 failed attempts → token permanently invalidated (regardless of expiry)
6. Server stores both device public keys (keyAPem + keyBPem) → **immediately and permanently marks token as used** (used tokens are never re-validatable)
7. App stores `deviceId` in Keychain
8. All subsequent requests are ECDSA-signed — `/auth/enroll` is the only unauthenticated call that will ever exist

**Security of the enrollment token:**
- 256 bits of entropy — brute force is physically impossible
- 10-minute expiry window
- Single-use: invalidated the instant it's redeemed, not on expiry — a captured code is worthless after first use
- 5 failed attempts → token is permanently invalidated (forces new token generation to prevent patient brute-force)
- Permanently invalidated tokens can be **deleted from the admin panel** via `DELETE /admin/enrollments/:code`, clearing the record so a fresh token can be generated if needed
- Only generable via localhost admin panel — requires SSH access to the server


---

## Pushover Alert Monitoring

- Backend runs a loop every 60 seconds (same as discord-bot's AlertManager)
- Thresholds from `config/servers.json`
- On threshold breach → `POST https://api.pushover.net/1/messages.json`
- Cooldown tracking in memory to prevent spam

---

## Verification Plan

1. **Backend unit tests:** Bun test runner — test ECDSA signature verification, processRunner arg safety, WoL packet construction
2. **Integration test:** admin panel `POST /enrollments` → `/auth/enroll` → `curl` with hand-crafted signed headers → verify 200; unsigned request → 403; old timestamp → 403; replay nonce → 403
3. **iOS simulator:** First-run setup flow (Secure Enclave uses software fallback in simulator, no Face ID prompt)
4. **End-to-end on device:** Register iPhone → server list loads both servers → dashboard metrics → restart a test service → WoL the old server → SSH command → Pushover notification fires on threshold
5. **Security check:** Replay (resend old timestamp) → 403; unregistered key → 403; disabled device → 403

---

## Critical Files to Create

| File | Purpose |
|---|---|
| `backend/src/app.ts` | Hono app (mirrors pepperminty/apps/api/src/app.ts) |
| `backend/src/middleware/deviceAuth.ts` | ECDSA signature verification on every request |
| `backend/src/db/schema.ts` | Drizzle schema (devices, enrollment_tokens, seen_nonces, idempotency_cache, jobs, package_state, audit_log) |
| `backend/src/services/serverContext.ts` | Dispatch local exec vs SSH for a given serverId |
| `backend/src/services/sshClient.ts` | ssh2 connection pool for remote servers |
| `backend/src/services/wol.ts` | UDP magic packet sender |
| `backend/config/servers.json` | All servers config (local + remote with MAC/SSH info) |
| `backend/src/admin/adminApp.ts` | Localhost-only admin Hono app (device management, enrollment tokens, audit log) |
| `mobile/Sources/Services/DeviceKeyManager.swift` | Secure Enclave key management |
| `mobile/Sources/Services/NetworkService.swift` | Auto-signing HTTP client |
| `mobile/Sources/Views/SetupView.swift` | First-run registration UI |
| `mobile/Sources/Views/ServerListView.swift` | Home screen with server cards + Wake button |
| `mobile/Sources/Views/ServerDetailView.swift` | Tab host per server |
| `mobile/Sources/Views/DashboardView.swift` | Metrics + quick actions |
| `mobile/project.yml` | XcodeGen config |
