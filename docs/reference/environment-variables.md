# Environment Variables

## Backend (`backend/.env`)

Create from template:

```bash
cp backend/.env.example backend/.env
```

| Variable | Required | Example | Notes |
|---|---|---|---|
| `TMDB_API_KEY` | Yes | `abc123` | Used by backend TMDB proxy |
| `OMDB_API_KEY` | Yes | `def456` | Used by backend OMDb proxy |
| `ADMIN_TOKEN` | Yes | `long-random-token` | Required for `POST /api/auth/admin/login` |
| `DATABASE_URL` | No | `sqlite:///./app.db` | Defaults to local SQLite |
| `CORS_ORIGINS` | No | `http://localhost:5173` | Comma-separated origins |
| `SECRET_KEY` | No (dev), Yes (prod) | `very-long-random-string` | JWT signing key (default is insecure; override in production) |

## Frontend (`frontend/.env`)

Create from template:

```bash
cp frontend/.env.example frontend/.env
```

| Variable | Required | Example | Notes |
|---|---|---|---|
| `VITE_API_URL` | Optional | `http://localhost:8155` | If empty, frontend uses same-origin |

## iOS App (`mobile/.env`)

Create manually (no committed template file):

```bash
cat > mobile/.env <<'ENV'
API_BASE_URL=https://api.example.com/api
ENV
```

Accepted keys (either works):

| Variable | Required | Example | Notes |
|---|---|---|---|
| `API_BASE_URL` | Yes | `https://api.example.com/api` | Preferred key |
| `MOBILE_API_BASE_URL` | Alternative | `https://api.example.com/api` | Backward-compatible alias |

Used by `mobile/scripts/generate-env-xcconfig.sh` to generate:
- `mobile/Config/Env.generated.xcconfig`

## GitHub Actions Secrets

### iOS build workflow (`.github/workflows/build-mobile.yml`)

| Secret | Required | Example |
|---|---|---|
| `MOBILE_API_BASE_URL` | Yes | `https://api.example.com/api` |

The workflow validates this value and fails fast if it is missing/invalid.

## Summary

| Variable | Where set |
|---|---|
| `TMDB_API_KEY` | `backend/.env` |
| `OMDB_API_KEY` | `backend/.env` |
| `ADMIN_TOKEN` | `backend/.env` |
| `DATABASE_URL` | `backend/.env` |
| `CORS_ORIGINS` | `backend/.env` |
| `SECRET_KEY` | `backend/.env` |
| `VITE_API_URL` | `frontend/.env` |
| `API_BASE_URL` | `mobile/.env` |
| `MOBILE_API_BASE_URL` | GitHub Actions secret (and optionally `mobile/.env`) |

## Related Docs

- [Local Development](../setup/local-development.md)
- [Deployment](../setup/deployment.md)
- [iOS Build & Distribution](../setup/ios-build.md)
