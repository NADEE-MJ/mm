# AGENTS.md — Mentat Codebase Guide

## Repository Structure

Monorepo with two primary workspaces:
- `backend/` — Bun/TypeScript REST API server (Hono framework, SQLite via Drizzle)
- `mobile/` — Swift iOS app (SwiftUI, XcodeGen)
- `scripts/` — Shell orchestration scripts
- Root `package.json` delegates to `scripts/mentat-cli.sh`; no source code lives at the root

## Build / Run Commands

```bash
# Backend (run from backend/)
bun run dev          # Watch mode (hot reload)
bun run start        # Production server
bun run db:generate  # Generate Drizzle migration SQL from schema
bun run db:migrate   # Apply migrations

# iOS (from repo root)
npm run swift:xcconfig   # Generate Env.generated.xcconfig from mobile/.env
npm run swift:xcodegen   # Run xcodegen to regenerate Mentat.xcodeproj
npm run swift:build      # Build for iOS Simulator (Debug)
npm run swift:run        # Build + install + launch in simulator
npm run simulator:list   # List available simulators
```

## Test Commands

There is no dedicated linter or formatter. TypeScript strict mode is the primary enforcement mechanism.

```bash
# Run all backend tests (from backend/)
bun test

# Run a single test file
bun test test/integration/app.integration.test.ts

# Run tests matching a name pattern
bun test --test-name-pattern "health endpoint"
```

Tests live in `backend/test/integration/`. The integration test spins up the Hono app in-process with a temporary SQLite database and temporary git repo — no external services required.

## Code Style — TypeScript (Backend)

### Formatting
- 2-space indentation
- Double quotes for strings
- Semicolons required
- Trailing commas in multi-line structures
- No ESLint or Prettier config — be consistent with surrounding code

### TypeScript
- `strict: true` is enforced; **no `any` types**
- Prefer `import type { ... }` for type-only imports
- No `enum` keyword — use string literal union types instead (`"A" | "B"`)
- Use `readonly` on class fields where applicable
- Explicit return type annotations on all exported functions
- Derive static types from Zod schemas via `z.infer<typeof schema>` rather than duplicating type definitions

### Imports
Order imports in this sequence:
1. Node built-ins using the `node:` prefix: `import { existsSync } from "node:fs";`
2. Third-party packages: `import { Hono } from "hono";`
3. Local relative imports: `import { getServerById } from "../config";`

Rules:
- Always use the `node:` protocol for Node/Bun built-ins (`node:fs`, `node:path`, `node:crypto`, etc.)
- Omit `.ts` extension in relative imports (Bun resolves them)
- No path aliases — all imports are relative
- No barrel/index files — import directly from the source file

### Naming Conventions

| Construct | Convention | Example |
|---|---|---|
| Files | `camelCase.ts` | `sshClient.ts`, `processRunner.ts` |
| Exported functions | `camelCase` | `getServerById`, `executeCommand` |
| Classes | `PascalCase` | `SSHClientPool`, `JobScheduler` |
| Module-level singleton instances | `camelCase` | `sshPool`, `scheduler` |
| Private/module-level constants | `SCREAMING_SNAKE_CASE` | `UNAUTHENTICATED_PATHS`, `UUID_V4_PATTERN` |
| Route exports | `camelCase` + `Routes` | `serversRoutes`, `metricsRoutes` |
| Middleware exports | `camelCase` + `Middleware` | `loggerMiddleware`, `corsMiddleware` |
| Zod schemas | `camelCase` + `Schema` | `createJobSchema`, `serverConfigSchema` |
| Types and interfaces | `PascalCase` | `AppVariables`, `ServerConfig`, `CommandResult` |
| DB column names (raw SQL) | `snake_case` | `key_a_pem`, `last_seen_at` |
| TS object properties | `camelCase` | `createdAt`, `deviceId`, `keyAPem` |

### Error Handling

Universal route-level pattern — every route handler follows this exactly:

```ts
try {
  const result = await someOperation();
  return c.json(result);
} catch (error) {
  const message = error instanceof Error ? error.message : "Operation failed";
  return c.json({ error: message }, 500);
}
```

Additional rules:
- Always parse request bodies with `schema.safeParse(await c.req.json().catch(() => null))` — never `parse()` which throws, and always handle malformed JSON with `.catch(() => null)`
- Return 404 early for unknown resources: `return c.json({ error: "Unknown server" }, 404)`
- Services throw `new Error("message")` — never throw raw strings
- Fire-and-forget async calls must use `void` prefix: `void this.connect(record)`
- Do not `console.error` in route handlers — let the global `onError` handler do it
- The global `onError` in `app.ts` catches `HTTPException` and generic errors; add new error types there if needed

### Async Patterns
- `async/await` everywhere; no `.then()/.catch()` chains
- `Promise.all()` for concurrent independent operations
- `void expr` for intentionally fire-and-forget calls (never naked floating promises)

### Architecture Rules
- **`routes/` files are thin** — HTTP parsing, Zod validation, delegation only; no business logic
- **`services/` files are pure logic** — no Hono types, no `c.req`/`c.json` references
- Stateful services that manage long-lived resources use **classes** and export a **single module-level instance**
- Stateless utilities use **exported functions** directly
- **Fail fast on config errors** — Zod-validate all env vars at module load time; let the app crash loudly at startup if config is missing/invalid

## Code Style — Swift (Mobile)

### Formatting
- 4-space indentation
- `// MARK: -` comments to separate logical sections within a file
- Document security-sensitive decisions with inline comments

### Naming Conventions

| Construct | Convention | Example |
|---|---|---|
| Types (struct, class, enum) | `PascalCase` | `ServerInfo`, `SSHConnectionManager` |
| Properties and methods | `camelCase` | `tunnelPort`, `fetchServers()` |
| Enum cases | `camelCase` | `.connectedLocal`, `.keyCreationFailed` |
| Views | `PascalCase` + `View` | `ServerListView`, `DashboardView` |
| Manager/Service types | `PascalCase` + `Manager`/`Service` | `SSHConnectionManager`, `NetworkService` |
| Error enums | `PascalCase` + `Error` | `SSHConnectionError`, `HostKeyError` |
| Theme/config constants | `static let` on enum namespace | `AppTheme.accent`, `AppConfiguration.tunnelBaseURL` |

### Error Handling
- Use `do/catch` with `error.localizedDescription` in Views
- Each View that makes network calls holds `@State private var errorMessage: String?` for display
- Throw `NSError(domain: "Mentat", code: statusCode, userInfo: [...])` from `NetworkService`
- Conform error enums to `LocalizedError` by implementing `errorDescription`
- Use `guard ... else { return/throw }` for early exit on optionals — avoid nested `if let`
- Use `defer { isLoading = false }` to guarantee loading-state cleanup
- `fatalError` only for unrecoverable programmer errors at launch-time (e.g., missing required Keychain entry)

### Async Patterns (Swift)
- `async/await` throughout; use `Task { }` to call async code from non-async contexts (e.g., button actions)
- `await MainActor.run { }` for UI updates originating from background tasks
- Annotate classes that own UI state with `@MainActor`
- `defer` for cleanup after `async` operations

## Security Conventions
- Never trust `X-Forwarded-For` or `X-Real-IP` on direct Tailscale connections — document this inline when relevant
- Use the Web Crypto API (`crypto.subtle`) in TypeScript; use `SecKey`/`CryptoKit` in Swift — no third-party crypto libraries
- Sensitive headers are explicitly listed in a `Set` and redacted in request logs (see `REDACTED_HEADERS` in `middleware/logger.ts`)
- All cryptographic key material stays in Keychain (iOS) or the database (backend); never in plain text files or logs

## File Organization

```
backend/src/
├── index.ts          # Entry point — Bun.serve bound to 127.0.0.1 only
├── app.ts            # Hono app assembly, middleware registration, onError
├── config.ts         # Env + servers.json Zod validation and exports
├── types.ts          # Shared AppVariables Hono context type
├── db/               # Drizzle schema, migration runner, SQLite singleton
├── middleware/       # logger
├── routes/           # One file per resource (thin HTTP layer)
└── services/         # Business logic (no HTTP concerns)

mobile/Sources/
├── Models/           # Codable structs and enums (pure data)
├── Services/         # Network, auth, crypto, WebSocket logic
├── Views/            # SwiftUI screens
│   └── Components/   # Reusable sub-views
└── Theme/            # AppTheme color/style constants
```
