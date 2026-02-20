# Environment Variables

---

## Backend (`backend/.env`)

Copy from `backend/.env.example`:

```bash
cp backend/.env.example backend/.env
```

| Variable | Required | Example | Notes |
|---|---|---|---|
| `TMDB_API_KEY` | Yes | `abc123...` | Get at [themoviedb.org/settings/api](https://www.themoviedb.org/settings/api) |
| `OMDB_API_KEY` | Yes | `def456...` | Get at [omdbapi.com/apikey.aspx](http://www.omdbapi.com/apikey.aspx) |
| `SECRET_KEY` | Yes | `long-random-string` | JWT signing key; use a strong random value in production |
| `ADMIN_TOKEN` | Yes | `another-long-secret` | Required to create user accounts via `POST /api/auth/admin/users` |
| `DATABASE_URL` | Yes | `sqlite:///./app.db` | SQLite path; use absolute path with volume in production |
| `CORS_ORIGINS` | Yes | `http://localhost:5173,http://localhost:3000` | Comma-separated allowed origins |

**In production**, ensure:
- `SECRET_KEY` is unique and unpredictable (e.g., `openssl rand -hex 32`)
- `CORS_ORIGINS` is set to your actual frontend domain, not `*`
- `DATABASE_URL` points to a persistent volume path

---

## Frontend (`frontend/.env`)

Copy from `frontend/.env.example`:

```bash
cp frontend/.env.example frontend/.env
```

| Variable | Required | Example | Notes |
|---|---|---|---|
| `VITE_API_URL` | Yes | `http://localhost:8000` | Backend base URL (no trailing slash, no `/api`) |

In production, this is typically not needed because the frontend is served from the same origin as the backend. The API calls use relative URLs (`/api/...`) automatically when same-origin.

---

## iOS App (`mobile/.env`)

Copy from `mobile/.env.example`, or create manually:

```bash
touch mobile/.env
```

| Variable | Required | Example | Notes |
|---|---|---|---|
| `API_BASE_URL` | Yes | `https://api.example.com/api` | Must be HTTPS; must end in `/api` |
| `MOBILE_API_BASE_URL` | Alternative | `https://api.example.com/api` | Either name is accepted by the generator script |

This file is read by `mobile/scripts/generate-env-xcconfig.sh`, which produces `mobile/Config/Env.generated.xcconfig`. The xcconfig injects the URL into `Sources/Info.plist` at build time.

The file is **gitignored**. Each developer (and CI) must generate it locally.

**iOS enforces HTTPS (ATS).** To use a local HTTP backend during development, add an ATS exception for the specific IP in `Sources/Info.plist`:

```xml
<key>NSAppTransportSecurity</key>
<dict>
  <key>NSExceptionDomains</key>
  <dict>
    <key>192.168.1.100</key>
    <dict>
      <key>NSExceptionAllowsInsecureHTTPLoads</key>
      <true/>
    </dict>
  </dict>
</dict>
```

---

## GitHub Actions Secrets & Variables

Configure these in **Repository Settings → Secrets and variables → Actions**.

### For the iOS Swift Build (`.github/workflows/build-mobile.yml`)

| Secret | Required | Example | Notes |
|---|---|---|---|
| `MOBILE_API_BASE_URL` | Yes | `https://api.example.com/api` | Must be HTTPS; workflow fails if missing or invalid |

### For the Expo/React Native Build (`.github/workflows/build-ios-simple.yml`)

| Variable or Secret | Required | Example | Notes |
|---|---|---|---|
| `EXPO_PUBLIC_API_URL` | Yes | `https://api.example.com/api` | Baked into the JS bundle at build time |

---

## Summary Table

| Variable | Where | Who sets it |
|---|---|---|
| `TMDB_API_KEY` | `backend/.env` | Developer / ops |
| `OMDB_API_KEY` | `backend/.env` | Developer / ops |
| `SECRET_KEY` | `backend/.env` | Developer / ops |
| `ADMIN_TOKEN` | `backend/.env` | Developer / ops |
| `DATABASE_URL` | `backend/.env` | Developer / ops |
| `CORS_ORIGINS` | `backend/.env` | Developer / ops |
| `VITE_API_URL` | `frontend/.env` | Developer (local only) |
| `API_BASE_URL` | `mobile/.env` | Developer |
| `MOBILE_API_BASE_URL` | GitHub Secret | Repo admin |
| `EXPO_PUBLIC_API_URL` | GitHub Variable/Secret | Repo admin |

---

## Related Docs

- [Local Development](../setup/local-development.md)
- [Deployment](../setup/deployment.md)
- [iOS Build & Distribution](../setup/ios-build.md)
