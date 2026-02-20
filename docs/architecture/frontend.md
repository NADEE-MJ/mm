# Frontend Architecture

The frontend is a **React** Progressive Web App built with **Vite** and styled with **Tailwind CSS**. It is designed mobile-first with dark mode, offline support via **IndexedDB**, and a sync queue that reconciles changes with the backend.

---

## File Structure

```
frontend/
├── src/
│   ├── App.tsx                  # Root component, routing
│   ├── main.tsx                 # React entry point
│   ├── index.css                # Tailwind base styles
│   ├── components/
│   │   ├── features/
│   │   │   ├── AddMovie/        # Add movie flow (search → recommender → confirm)
│   │   │   ├── People/          # People management UI
│   │   │   └── ...
│   │   └── ui/                  # Shared UI primitives
│   ├── pages/
│   │   ├── HomePage.tsx         # Movie list by status
│   │   ├── PeoplePage.tsx       # Recommenders list
│   │   ├── ListsPage.tsx        # Custom lists
│   │   └── AccountPage.tsx      # Settings, backup, data export
│   ├── hooks/
│   │   ├── useMovies.ts         # Movie data and actions
│   │   ├── usePeople.ts         # People data and actions
│   │   └── useSync.ts           # Sync queue processor
│   ├── services/
│   │   ├── api.ts               # Backend HTTP client
│   │   └── storage.ts           # IndexedDB abstraction
│   ├── utils/
│   │   └── constants.ts         # App-wide constants
│   └── contexts/
│       └── AuthContext.tsx       # Auth state provider
├── public/
│   ├── manifest.json            # PWA manifest
│   └── sw.js                    # Service worker
└── package.json
```

---

## Framework & Dependencies

| Package | Purpose |
|---|---|
| `react` | UI library |
| `vite` | Build tool and dev server |
| `tailwindcss` | Utility-first CSS |
| `react-router-dom` | Client-side routing |
| `idb` | IndexedDB with a Promise-based API |
| `lucide-react` | SVG icon library |

---

## Offline-First Architecture

### IndexedDB Stores

All data is stored locally in **IndexedDB** under the database name `movieRecommendations`:

| Store | Contents |
|---|---|
| `movies` | Movie objects (status, recommendations, watch history, TMDB/OMDb data) |
| `people` | Person objects (name, trust, color, emoji, quick_key) |
| `syncQueue` | Pending write operations waiting to be sent to the backend |
| `metadata` | App metadata: `lastSync` Unix timestamp |

### Sync Queue Lifecycle

```
User action (add movie, mark watched, etc.)
        │
        ▼
1. Write to IndexedDB immediately (optimistic)
2. Append action to syncQueue store
3. Update UI (no waiting for network)
        │
        ▼
Queue processor triggers:
  - Every 30 seconds
  - On window/app focus
  - After any write action
        │
        ▼
If online:
  POST /api/sync  (one action at a time, in order)
        │
        ▼
On success:
  Remove from syncQueue
  Update lastModified timestamp in local record

On failure:
  Increment retry count
  Keep in queue (retry next cycle)
  If retries > max → mark as failed, surface to user
```

### Conflict Resolution

Last-write-wins using the server-returned `lastModified` timestamp. If the server has a newer version of a record, the server value overwrites the local cache. No three-way merge is attempted.

### Sync Status Indicator

| State | Display | Meaning |
|---|---|---|
| Synced | ✓ green | All changes pushed |
| Pending | ↻ yellow | Changes in queue |
| Conflict | ⚠ orange | Some syncs failed — tap to retry |
| Offline | ⊗ gray | No internet connection |

---

## Progressive Web App (PWA)

### Installation

The app includes a `public/manifest.json` with:
- App name, short name, theme color
- Icons for home screen
- `display: standalone` — removes browser chrome when installed
- `start_url: /`

### Service Worker (`public/sw.js`)

The service worker handles:
- **Static asset caching**: JS/CSS/HTML cached on install for offline access
- **Background sync**: Queued sync actions replayed when connectivity is restored
- **Network-first strategy** for API calls (falls back to cached data if offline)

---

## People & Quick Recommenders

The frontend no longer maintains a hardcoded `DEFAULT_RECOMMENDERS` list. Quick recommenders (YouTube, Oscar, Random Person, Google) are seeded server-side on account creation and returned from `GET /api/people` with a `quick_key` field.

The frontend identifies quick recommenders by checking `person.quick_key !== null`. This replaces the old name-matching approach, which was fragile if a user renamed one.

**In the AddMovie flow:**
- Quick recommenders are listed first with a purple "Quick" badge
- Regular recommenders follow in a separate section

**In the People manager:**
- `isDefault: !!person.quick_key` drives filter/display logic
- Quick recommenders cannot be deleted (guarded server-side; the UI reflects this)

See [People & Recommenders](../features/people.md) for the full feature description.

---

## Backup & Export UI

The `AccountPage` includes a **Data & Backup** section:
- **Auto-backup toggle** — calls `PUT /api/backup/settings`; subtitle explains the 14-day server retention
- **Export Library** — calls `GET /api/backup/export`, triggers browser download of `moviemanager-export-{date}.json`
- **Import Library** — `<input type="file" accept=".json">` picks a file; calls `POST /api/backup/import`; shows a toast with import counts and an enrichment notice if any movies needed metadata refresh

See [Backup & Export](../features/backup-export.md) for the export format spec.

---

## Development

```bash
cd frontend
npm install
cp .env.example .env
# set VITE_API_URL=http://localhost:8000
npm run dev
# app at http://localhost:5173
```

### Building for Production

```bash
npm run build
# output in frontend/dist/
```

The backend serves `dist/` as static files in production.

---

## Related Docs

- [Backup & Export](../features/backup-export.md)
- [People & Recommenders](../features/people.md)
- [Environment Variables](../reference/environment-variables.md)
