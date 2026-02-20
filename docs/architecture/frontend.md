# Frontend Architecture

The frontend is a React SPA built with Vite. It is server-backed (FastAPI) and uses WebSocket events for near real-time refresh.

## File Structure

```text
frontend/
├── src/
│   ├── main.tsx
│   ├── App.tsx
│   ├── contexts/
│   │   ├── AuthContext.tsx
│   │   └── MoviesContext.tsx
│   ├── hooks/
│   │   ├── usePeople.ts
│   │   └── useSync.ts
│   ├── pages/
│   │   ├── MoviesPage.tsx
│   │   ├── PeoplePage.tsx
│   │   ├── PersonDetailPage.tsx
│   │   ├── ListsPage.tsx
│   │   ├── AccountPage.tsx
│   │   └── AdminPage.tsx
│   ├── components/
│   │   ├── layout/
│   │   ├── ui/
│   │   └── ...
│   ├── services/
│   │   ├── api.ts
│   │   ├── tmdbAPI.ts
│   │   └── omdbAPI.ts
│   └── utils/
└── package.json
```

## Key Dependencies

| Package | Purpose |
|---|---|
| `react` | UI runtime |
| `react-router-dom` | Routing |
| `vite` | Dev server and build |
| `tailwindcss` | Styling |
| `lucide-react` | Icons |

## App Flow

1. `AuthContext` manages JWT login state.
2. `MoviesContext` loads server movie data from `/api/movies`.
3. Route pages render filtered/projected views of shared context state.
4. Mutations call backend APIs, then refresh state.
5. `useSync` opens WebSocket `/ws/sync?token=...` and triggers reload on update events.

## Routing

`App.tsx` routes:
- `/` movies
- `/people`
- `/people/:name`
- `/lists`
- `/account`
- `/admin`

## Backup UI

`AccountPage` includes:
- Auto-backup toggle (`GET/PUT /api/backup/settings`)
- Export (`GET /api/backup/export`)
- Import (`POST /api/backup/import`)

After import, the page can call metadata refresh for returned IMDb IDs.

## Environment

`VITE_API_URL` controls API base URL in development.
If unset, the app uses same-origin requests.

## Build

```bash
cd frontend
npm install
npm run dev
npm run build
```

Production output: `frontend/dist/`

## Related Docs

- [API Reference](../reference/api.md)
- [Environment Variables](../reference/environment-variables.md)
- [Deployment](../setup/deployment.md)
