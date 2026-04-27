# Mobile Input Sanitization Audit Report

**Scope:** All places in the iOS mobile app (`mobile/Sources/`) where user-supplied input or server-returned data flows into network requests, Keychain storage, or SwiftUI UI rendering. Also covers logging privacy and URL construction hygiene.

**Last updated:** 2026-03-04 (post SSH-tunnel migration + post-audit-fix commits)

Status legend:
- **N/A** — the affected code no longer exists
- **STILL OPEN** — issue persists in the current codebase

---

## Summary Table

| ID | File(s) | Line(s) | Input Source | Sink | Sanitization Present | Severity | Status |
|---|---|---|---|---|---|---|---|
| N-1 | `SetupView.swift`, `NetworkService.swift` | 20, 27, 65 / 63–68 | User `TextField` (`code`, `deviceName`) | JSON POST body | `lowercased()` on `code` only | Medium | **STILL OPEN** |
| N-2 | `NetworkService.swift` | 95, 105, 117, 128, 140, 151, 162, 174 | Server-returned `serverId`, `containerId`, `serviceName` | URL path segment | Trim `/` only; no percent-encoding | Medium | **STILL OPEN** |
| N-3 | ~~`JobsView.swift`, `NetworkService.swift`~~ | — | ~~User `TextField` (`id`, `command`, `schedule`)~~ | — | — | ~~Medium~~ | **N/A** |
| N-4 | ~~`SSHView.swift`, `NetworkService.swift`~~ | — | ~~User `TextField` (`command`)~~ | — | — | ~~Low–Medium~~ | **N/A** |
| N-5 | `GitView.swift`, `NetworkService.swift` | 38–41, 116–120 / 197 | User `TextField` (branch name, pre-seeded from server) | JSON POST body | `.trimmingCharacters` only | Low–Medium | **STILL OPEN** |
| N-6 | `NetworkService.swift`, `ServicesView.swift` | 128 / 28–30 | Server-returned `serviceName` | URL path segment | None | Low | **STILL OPEN** |
| N-7 | `NetworkService.swift` | 151, 162 | Server-returned `containerId` | URL path segment | None | Low | **STILL OPEN** |
| N-8 | `AppLogging.swift` | 7, 11 | Any string passed to log functions | OS system log (`.public`) | None | Low | **STILL OPEN** |
| K-1 | ~~`AuthManager.swift`, `SetupView.swift`~~ | — | ~~Server-returned `deviceId`~~ | ~~Keychain → `X-Device-ID` header~~ | — | ~~Medium~~ | **N/A** |
| K-2 | ~~`AuthManager.swift`~~ | — | ~~Keychain-stored `deviceId` on read~~ | ~~`X-Device-ID` header~~ | — | ~~Low~~ | **N/A** |
| UI-1 | `ServerCardView.swift` | 11, 13, 26 | Server-returned `name`, `id`, `sshState` | SwiftUI `Text` (no length limit) | None | Low–Medium | **STILL OPEN** |
| UI-2 | `ServerDetailView.swift` | 47 | Server-returned `name` | Navigation title | None | Low | **STILL OPEN** |
| UI-3 | ~~`SSHView.swift`~~ | — | ~~Server-returned SSH stdout/stderr~~ | — | — | ~~Medium~~ | **N/A** |
| UI-4 | `DockerView.swift` | 28, 30, 69 | Server-returned container name, image, log text | SwiftUI `Text` (unbounded) | None | Medium | **STILL OPEN** |
| UI-5 | `ServicesView.swift` | 17, 23, 70 | Server-returned `displayName`, `unit` | SwiftUI `Text`; native alert body | None | Medium | **STILL OPEN** |
| UI-6 | `GitView.swift` | 17, 20, 27, 64 | Server-returned repo name/path/branch, git output | SwiftUI `Text` | None | Low–Medium | **STILL OPEN** |
| UI-7 | `JobsView.swift` | 22, 28–32 | Server-returned job `id`, `command`, `schedule` | SwiftUI `Text` | None | Low | **STILL OPEN** |
| UI-8 | `PackagesView.swift` | 15 | Server-returned `serverId` | SwiftUI `LabeledContent` | None | Low | **STILL OPEN** |
| UI-9 | `LogStreamView.swift` | 18 | Caller-supplied `source` string | Navigation title | None | Low | **STILL OPEN** (dead code) |
| UI-10 | `StatusBadgeView.swift` | 20 | Server-returned `status` string | SwiftUI `Text` in Capsule badge | `.capitalized` only | Low | **STILL OPEN** |
| UI-11 | 8 views (see below) | Various | Server HTTP error response body | Error banner `Text` | None | Medium | **STILL OPEN** |
| UI-12 | `SetupView.swift` | 81–83 | User `TextField` (`localIP`, `tailscaleIP`, `sshUsername`) | `UserDefaults` via `SSHConfigManager` binding | None | Low | **STILL OPEN** |
| UI-13 | `ServicesView.swift` | 23 | Server-returned `service.unit` | SwiftUI `Text` (monospaced) | None | Low | **STILL OPEN** |
| UI-14 | `SettingsView.swift` | 13–15 | `sshManager.lastError` (NIO error string) | SwiftUI `Text` (no length cap) | None | Low | **STILL OPEN** |
| N-9 | `WebSocketManager.swift` | 23 | Caller-supplied `path` string | WebSocket URL construction | Prefix `/` check only; no percent-encoding | Low | **STILL OPEN** (dead code) |

---

## Medium Findings

### N-1 — Enrollment TextFields Have No Length Limits or Format Validation — STILL OPEN

**Files:** `mobile/Sources/Views/SetupView.swift:20, 27, 65` → `mobile/Sources/Services/NetworkService.swift:63–68`

**Input:** Two `TextField` views — `$code` (enrollment one-time code) and `$deviceName`.

**Sink:** Both values are placed into a JSON POST body sent to `POST /api/auth/enroll`.

**Sanitization present:**
- `code.lowercased()` is applied at `SetupView.swift:65`. That is the only transformation.
- `deviceName` receives no transformation.
- Neither field has a length cap. No character allowlist is applied.

**Risk:** An arbitrarily large `deviceName` can be submitted and may cause layout breakage in views that display it. No injection risk client-side (JSON serialization handles escaping).

**Fix:** Apply `.onChange { value in newValue = String(value.prefix(64)) }` or equivalent to both fields. Validate `code` against the expected format before submission and show an inline error if invalid.

---

### N-2 — Server-Returned Path Segments Interpolated Into URLs Without Percent-Encoding — STILL OPEN

**File:** `mobile/Sources/Services/NetworkService.swift`

**Affected lines:**
- `95`: `"/api/servers/\(serverId)/metrics"`
- `105`: `"/api/servers/\(serverId)/wake"`
- `117`: `"/api/servers/\(serverId)/services"`
- `128`: `"/api/servers/\(serverId)/services/\(serviceName)/\(action)"`
- `140`: `"/api/servers/\(serverId)/docker/containers?all=..."`
- `151`: `"/api/servers/\(serverId)/docker/\(containerId)/logs?lines=\(lines)"`
- `162`: `"/api/servers/\(serverId)/docker/\(containerId)/\(action)"`
- `174`: `"/api/servers/\(serverId)/git"`

**Input:** `serverId`, `containerId`, `serviceName` decoded from JSON server responses.

**Sink:** Inserted into URL path strings, then passed to `buildURL(path:)`. Trim of `/` characters only. `URLComponents` will re-encode characters that are invalid in a path overall, but a `?` or `#` in a segment value would be interpreted as a query or fragment delimiter before `URLComponents` processes the assembled string, causing path truncation or query injection.

**Risk:** A compromised server returning a `serverId` containing `/` causes path traversal; a `?` injects a query string; `%2f` sequences allow further traversal after `URLComponents` normalization.

**Fix:** Apply `.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)` to each dynamic segment before interpolation, or use `URLComponents` and build path components individually.

---

### ~~N-3 — Jobs Form TextFields Have No Length Limits~~ — N/A

**Resolution:** The Jobs tab is now read-only. `JobsView.swift` contains no `TextField` inputs. `upsertJob` and `deleteJob` have been removed from `NetworkService.swift`. The path-injection vector via a user-typed job `id` no longer exists.

---

### ~~K-1 — Server-Returned `deviceId` Stored in Keychain Without Validation~~ — N/A

**Resolution:** The ECDSA device-auth system has been deleted. `AuthManager.swift` no longer stores or uses a `deviceId` from the server. Authentication is now handled via the SSH tunnel; there is no enrollment flow or Keychain-backed device identity.

---

### ~~UI-3 — SSH Command Output Displayed Without Truncation~~ — N/A

**Resolution:** `SSHView.swift` has been deleted. No SSH output is rendered anywhere in the app.

---

### UI-4 — Docker Container Log Text Displayed Without Truncation — STILL OPEN

**File:** `mobile/Sources/Views/DockerView.swift:28, 30, 69`

**Input:** `logText: String` — raw container log lines returned by the server, plus `container.name` and `container.image` from server JSON.

**Sink:** `Text(logText)` at line 69, displayed in a `ScrollView`.

**Risk:** A container producing high-volume logs will have the full log body fetched and rendered in a single `Text` allocation. Docker container names and image names also have no display length limit.

**Fix:** Enforce a reasonable default of ≤ 500 log lines via the `lines` query parameter. Cap `logText` at 100 KB before assigning to state. Apply `.lineLimit()` to container name and image `Text` views.

---

### UI-5 — Server-Returned `displayName` Interpolated Into Native Alert Body — STILL OPEN

**File:** `mobile/Sources/Views/ServicesView.swift:17, 23, 70`

**Input:** `service.displayName` decoded from server JSON.

**Sink:**
- `Text(service.displayName)` — displayed as `.font(.headline)` in the list row.
- Alert message at line 70: `"\(pendingAction.action.capitalized) \(pendingAction.service.displayName)?"` — interpolated directly into the body of a native system `Alert`.

**Risk:** A service with a crafted `displayName` can inject misleading text into the confirmation alert users see before performing an action (social-engineering vector on a compromised backend).

**Fix:** Apply a character length cap (e.g., 64 chars) and `.lineLimit(2)` to all `displayName` usages. Consider displaying a fixed message in the alert body and showing `displayName` only as the alert title.

---

### UI-11 — Server HTTP Error Response Body Rendered Verbatim in All Views — STILL OPEN

**Files affected:** `ServerListView.swift`, `DashboardView.swift`, `ServicesView.swift`, `DockerView.swift`, `GitView.swift`, `PackagesView.swift`, `JobsView.swift`

**Input:** `NetworkService.validateResponse()` constructs `NSError` using the raw HTTP response body as `NSLocalizedDescriptionKey`. This `localizedDescription` is assigned to `errorMessage` in each view and displayed in a `Text(errorMessage)` block.

**Risk:** A compromised backend can inject arbitrary text into every error-display location. There is also no length cap — a large error body would be stored in `@State var errorMessage` and rendered fully.

**Fix:** Truncate error messages to a maximum of 200 characters before display: `errorMessage = message.prefix(200).description`. Consider displaying a generic `"Request failed"` message with an optional "Details" disclosure.

---

## Low–Medium Findings

### ~~N-4 — SSH Command TextField Has No Length Limit~~ — N/A

**Resolution:** `SSHView.swift` deleted entirely.

---

### N-5 — Git Branch Name Only Whitespace-Trimmed — STILL OPEN

**File:** `mobile/Sources/Views/GitView.swift:38–41, 116–120` → `mobile/Sources/Services/NetworkService.swift:197`

**Input:** `TextField` bound to `branchInputs[repo.name]`, pre-populated from server-returned `repo.branch`.

**Sanitization:** `.trimmingCharacters(in: .whitespacesAndNewlines)` before submission. No allowlist, no length limit.

**Risk:** A branch name pre-populated from a compromised server and submitted without inspection could contain `../` sequences (which pass the backend regex) and cause unexpected git behavior.

**Fix:** Validate the trimmed branch name against `/^[A-Za-z0-9._-]+(\/[A-Za-z0-9._-]+)*$/` before enabling the checkout button. Cap at 256 characters.

---

### UI-1 — Server-Returned Strings in `ServerCardView` Have No Length Limits — STILL OPEN

**File:** `mobile/Sources/Views/Components/ServerCardView.swift:11, 13, 26`

**Input:** `server.name`, `server.id`, `server.sshState` — all server-returned.

**Sink:** `Text(server.name)`, `Text(server.id)`, `Text(server.sshState)` — no `.lineLimit()` applied.

**Risk:** A long `name` causes the card layout to overflow. `sshState` is a free-form string that could display social-engineering text on the main server list.

**Fix:** Apply `.lineLimit(1)` and `.truncationMode(.tail)` to all three `Text` views.

---

### UI-6 — Git Repo Filesystem Path Displayed and Git Output Unbounded — STILL OPEN

**File:** `mobile/Sources/Views/GitView.swift:17, 20, 27, 64`

**Input:** `repo.name`, `repo.path`, `repo.branch` (server-returned), `outputMessage` (raw server response from git operations).

**Sink:** Displayed in `Text` views without length limits. `repo.path` exposes server-side filesystem paths in the UI.

**Fix:** Apply `.lineLimit()` to repo metadata fields. Cap `outputMessage` at 50 KB.

---

## Low Findings

### N-6 — Service Name From Server Interpolated Into URL Path — STILL OPEN

**File:** `mobile/Sources/Services/NetworkService.swift:128`

`"/api/servers/\(serverId)/services/\(serviceName)/\(action)"` — `serviceName` is server-returned and not percent-encoded. Same path-injection risk as N-2.

**Fix:** Apply `.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)` to `serviceName`.

---

### N-7 — Container ID From Server Interpolated Into URL Path — STILL OPEN

**File:** `mobile/Sources/Services/NetworkService.swift:151, 162`

`containerId` from server JSON placed directly into URL path string without percent-encoding. Same risk as N-2/N-6.

**Fix:** Apply `.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)` to `containerId`.

---

### N-8 — `AppLog` Uses `.public` Privacy Level for All Messages — STILL OPEN

**File:** `mobile/Sources/Services/AppLogging.swift:7, 11`

All log messages are emitted with `.privacy: .public`, making them visible in the system log to any process on a jailbroken device or via Console.app on a paired Mac.

**Fix:** Change the default to `.privacy: .private` and explicitly promote only non-sensitive messages to `.public` at the call site.

---

### ~~K-2 — `deviceId` Not Validated on Keychain Read~~ — N/A

**Resolution:** `AuthManager.swift` Keychain-backed device identity removed with the auth system.

---

### UI-2 — Server Name Used as Navigation Title Without Length Limit — STILL OPEN

**File:** `mobile/Sources/Views/ServerDetailView.swift:47`

`.navigationTitle(server.name)` — no length cap. Very long or misleading names display prominently in the nav bar.

**Fix:** Truncate: `server.name.prefix(40)`.

---

### UI-7 — Job Command and Schedule Displayed Without Length Limit — STILL OPEN

**File:** `mobile/Sources/Views/JobsView.swift:44, 50–54`

`job.command` is displayed in a `.font(.caption.monospaced())` `Text` view with no `.lineLimit()`. A long command string (up to the backend's 5,000-char limit) would render across many lines.

**Fix:** Apply `.lineLimit(3)` and `.truncationMode(.tail)`.

---

### UI-8 — `serverId` in Packages View Has No Length Limit — STILL OPEN

**File:** `mobile/Sources/Views/PackagesView.swift:15`

`LabeledContent("Server", value: state.serverId)` — no length constraint on the value.

**Fix:** Apply `.lineLimit(1)` to the value display.

---

### UI-9 — `LogStreamView` Navigation Title Uses Caller-Supplied String — STILL OPEN (dead code)

**File:** `mobile/Sources/Views/LogStreamView.swift:18`

`.navigationTitle("\(source) logs")` — `source` is caller-supplied with no length cap. Risk is low currently since `LogStreamView` is never presented (see dead-code report), but should be hardened before the feature is completed.

**Fix:** Truncate `source` before passing to the view.

---

### UI-10 — `StatusBadgeView` Status String Not Length-Capped — STILL OPEN

**File:** `mobile/Sources/Views/Components/StatusBadgeView.swift:20`

`Text(status.capitalized)` inside a `Capsule()` background — no `.lineLimit(1)`. A long status string overflows the capsule shape.

**Fix:** Apply `.lineLimit(1)` and a max character count (e.g., `.prefix(20)`).

---

### UI-12 — `SetupView.swift` IP and Username Fields Have No Length Cap or Format Validation — NEW

**File:** `mobile/Sources/Views/SetupView.swift:81–83`

`LabeledField` views for `config.localIP`, `config.tailscaleIP`, and `config.sshUsername` are bound directly to `SSHConfigManager` `@Observable` properties, which persist to `UserDefaults`. There is no length cap, no IP address format check, and no POSIX username allowlist applied before storage. Values are stored on every keystroke via the binding.

**Risk:** An arbitrarily long or malformed IP/username value persists to `UserDefaults` and is later used as SSH connection parameters. While the SSH connection will simply fail, storing unsanitized values can trigger unexpected behavior in downstream formatting (e.g., in `SettingsView.swift` status display or error rendering).

**Fix:** Apply `.onChange { value in newValue = String(value.prefix(253)) }` (hostname max) to IP fields and `.prefix(64)` to the username field. Consider an inline format hint if the value doesn't match a basic IP or hostname pattern before attempting connection.

---

### UI-13 — `ServicesView.swift` `service.unit` Has No Length Limit — NEW

**File:** `mobile/Sources/Views/ServicesView.swift:23–24`

```swift
Text(service.unit)
    .font(.caption.monospaced())
    .foregroundStyle(.secondary)
```

`service.unit` is the server-returned systemd unit name rendered in a monospaced caption below the service display name. There is no `.lineLimit()`. A systemd unit name returned by a compromised backend could be arbitrarily long, causing the list row to expand vertically.

**Fix:** Apply `.lineLimit(1)` and `.truncationMode(.tail)` to this `Text` view.

---

### UI-14 — `SettingsView.swift` SSH Error String Rendered Verbatim Without Length Cap — NEW

**File:** `mobile/Sources/Views/SettingsView.swift:13–16`

```swift
if let error = sshManager.lastError {
    Text(error)
        .font(.footnote)
        .foregroundStyle(.red)
}
```

`sshManager.lastError` is the last error string from `SSHConnectionManager`, which is set directly from `error.localizedDescription` of NIO/NIOSSH errors. These can contain IP addresses, port numbers, internal NIO channel state details, and arbitrary-length stack context strings. There is no `.lineLimit()` or character cap applied before display in the `Form`.

**Fix:** Apply `.lineLimit(4)` and truncate at a safe limit: `Text(String(error.prefix(300)))`.

---

### N-9 — `WebSocketManager.swift` `path` Not Percent-Encoded in WebSocket URL — NEW

**File:** `mobile/Sources/Services/WebSocketManager.swift:23`

```swift
let url = URL(string: "ws://127.0.0.1:\(tunnelPort)\(path.hasPrefix("/") ? path : "/\(path)")")
```

`path` is interpolated directly into the WebSocket URL string without percent-encoding. A path containing spaces, `#`, or `?` would produce a malformed or misinterpreted URL. `URL(string:)` will return `nil` for paths with spaces, silently aborting the connection; a `#` or `?` would be interpreted as a fragment or query delimiter, truncating the actual path. `WebSocketManager` is currently dead code (never called), but this is a latent defect that should be fixed before the feature is wired up.

**Fix:** Apply `.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)` to `path` before interpolation, or use `URLComponents` to build the URL.

---

## Category 4 — Shell/Process Execution

The iOS sandbox does not permit spawning subprocesses. **No findings.**

---

## Category 5 — URL / Deep-Link Handling

- SSH tunnel connection parameters are stored via `SSHConfigManager` (host, port, username) and sourced from app-internal user-configured values, not from arbitrary server responses.
- No `openURL` calls with user-controlled values, no URL scheme handlers, and no universal link handlers were found.
- **N-2** (server-returned path segment injection) is the primary URL-construction risk.

**No new findings beyond N-2.**

---

## Top Remediation Priorities

1. **N-2 (Medium) — URL path segment percent-encoding:** Apply `.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)` to every dynamic path segment (`serverId`, `containerId`, `serviceName`) before string interpolation.

2. **UI-11 (Medium) — Server error body in UI:** Truncate error messages derived from server responses to a maximum of 200 characters before display.

3. **UI-4 (Medium) — Unbounded output in `Text`:** Cap Docker log output at 50 KB before assigning to view state. Add `.lineLimit()` to list-row `Text` views.

4. **UI-5 (Medium) — Server string in native alert:** Apply a character cap and `.lineLimit(2)` to `displayName` before interpolating into alert message text.

5. **N-5 (Low–Medium) — Git branch validation:** Validate against a strict allowlist regex and cap at 256 characters before enabling the checkout button.

6. **N-8 (Low) — Logging privacy:** Change `AppLog` default privacy from `.public` to `.private`.

7. **UI-14 (Low) — SSH error string in SettingsView:** Apply `.lineLimit(4)` and truncate to 300 characters before rendering `sshManager.lastError`.

8. **UI-12 (Low) — Setup IP/username fields:** Apply length caps and basic format validation to `localIP`, `tailscaleIP`, and `sshUsername` fields before storage.

9. **UI-13 (Low) — Service unit name truncation:** Apply `.lineLimit(1)` to `service.unit` in `ServicesView`.

10. **N-9 (Low) — WebSocket path percent-encoding:** Percent-encode `path` before WebSocket URL construction (fix before the feature is wired up).
