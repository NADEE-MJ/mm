# Movie Manager

A full-stack Progressive Web App for tracking movie recommendations with offline-first architecture. Built with React, FastAPI, and SQLite.

## Features

- **Offline-First**: Works without internet connection using IndexedDB and service workers
- **Movie Search**: Search and add movies using TMDB API with OMDb ratings
- **Recommendations Tracking**: Track who recommended each movie and when
- **Watch History**: Mark movies as watched and rate them (1-10)
- **Smart Status Management**: Automatically categorize movies as "To Watch", "Watched", "Questionable", or "Deleted"
- **People Management**: Mark recommenders as trusted or untrusted
- **Rating-Based Prompts**: When rating a movie below 6, get prompted to manage that person's other recommendations
- **Sync Queue**: All changes sync automatically when online with conflict resolution
- **Mobile-First Design**: Bottom navigation, dark mode, and touch-optimized UI
- **PWA Features**: Install to home screen, offline caching, background sync

## Tech Stack

### Backend
- **FastAPI**: Modern Python web framework
- **SQLite**: Lightweight database with Alembic migrations
- **uv**: Fast Python package manager
- **SQLAlchemy**: ORM for database operations

### Frontend
- **React**: UI library with hooks
- **Vite**: Fast build tool
- **Tailwind CSS**: Utility-first CSS framework (dark mode)
- **IndexedDB**: Local-first storage via `idb` library
- **React Router**: Client-side routing
- **Lucide React**: Icon library

### APIs
- **TMDB API**: Movie search and metadata (proxied through backend with caching)
- **OMDb API**: IMDb and Rotten Tomatoes ratings (proxied through backend with caching)
- **In-Memory Cache**: TTL-based caching (1 hour, 500 items) to reduce external API calls

## Project Structure

```
mm/
├── backend/
│   ├── main.py              # FastAPI app with all endpoints
│   ├── models.py            # SQLAlchemy models
│   ├── database.py          # Database configuration
│   ├── pyproject.toml       # Python dependencies
│   ├── alembic.ini          # Alembic configuration
│   ├── alembic/             # Database migrations
│   ├── app.db              # SQLite database (gitignored)
│   └── .env.example        # Environment variables template
│
├── frontend/
│   ├── src/
│   │   ├── components/      # React components
│   │   ├── services/        # API clients and storage
│   │   ├── hooks/           # React hooks
│   │   ├── utils/           # Helper functions
│   │   ├── App.jsx          # Main app component
│   │   └── index.css        # Tailwind CSS
│   ├── public/
│   │   ├── manifest.json    # PWA manifest
│   │   └── sw.js           # Service worker
│   ├── package.json         # Node dependencies
│   └── .env.example        # Environment variables template
│
├── mobile/
│   ├── app/                 # Expo Router screens
│   ├── src/                 # React Native app code
│   ├── app.json             # Expo app config
│   ├── .env.example         # EXPO_PUBLIC_API_URL template
│   └── README.md            # Mobile-specific setup
│
├── mobile-swift/
│   ├── Sources/             # Swift source code
│   │   ├── MobileSwiftApp.swift  # App entry point
│   │   ├── Models/          # Data models
│   │   ├── Services/        # Network, database, WebSocket
│   │   ├── Views/           # SwiftUI views
│   │   └── Theme/           # App theming
│   ├── project.yml          # XcodeGen configuration
│   └── README.md            # Mobile Swift setup
│
├── ios-test-swift/
│   ├── Sources/             # Swift test app (UI demo)
│   ├── project.yml          # XcodeGen configuration
│   └── README.md            # Test app documentation
│
└── README.md
```

## Setup Instructions

### Prerequisites

- **Python 3.11+** (for backend)
- **Node.js 18+** (for frontend)
- **uv** (Python package manager) - Install: `curl -LsSf https://astral.sh/uv/install.sh | sh`
- **TMDB API Key** - Get from: https://www.themoviedb.org/settings/api
- **OMDb API Key** - Get from: http://www.omdbapi.com/apikey.aspx

### Backend Setup

1. Navigate to backend directory:
   ```bash
   cd backend
   ```

2. Install dependencies:
   ```bash
   uv sync
   ```

3. Create `.env` file and add your API keys:
   ```bash
   cp .env.example .env
   ```

   Edit `.env` and add your TMDB and OMDb API keys:
   ```env
   TMDB_API_KEY=your_tmdb_api_key_here
   OMDB_API_KEY=your_omdb_api_key_here
   DATABASE_URL=sqlite:///./app.db
   CORS_ORIGINS=http://localhost:5173,http://localhost:3000
   ```

4. Run migrations (database is auto-created):
   ```bash
   uv run alembic upgrade head
   ```

5. Start the backend server:
   ```bash
   uv run uvicorn main:app --reload --host 0.0.0.0 --port 8000
   ```

   The API will be available at: `http://localhost:8000`
   API docs: `http://localhost:8000/docs`

### Frontend Setup

1. Navigate to frontend directory:
   ```bash
   cd frontend
   ```

2. Install dependencies:
   ```bash
   npm install
   ```

3. Create `.env` file:
   ```bash
   cp .env.example .env
   ```

4. Edit `.env` and configure the backend URL:
   ```env
   VITE_API_URL=http://localhost:8000
   ```

   **Note**: API keys for TMDB and OMDb are now configured in the backend for security.
   The frontend proxies all external API requests through the backend.

5. Start the development server:
   ```bash
   npm run dev
   ```

   The app will be available at: `http://localhost:5173`

### Mobile Setup (Expo + iOS IPA CI)

1. Navigate to mobile directory:
   ```bash
   cd mobile
   ```

2. Install dependencies:
   ```bash
   npm install
   ```

3. Create mobile env file:
   ```bash
   cp .env.example .env
   ```

4. Set API URL in `mobile/.env`:
   ```env
   EXPO_PUBLIC_API_URL=http://YOUR_LOCAL_IP:8000/api
   ```

5. Start Expo for on-device development:
   ```bash
   npx expo start
   ```

6. Open with Expo Go on your iPhone for hot refresh development from Linux.

### iOS Build Pipeline (Unsigned IPA)

This repo now has two iOS unsigned build workflows:

- Expo app: `.github/workflows/build-ios-simple.yml`
- Native Swift test app: `.github/workflows/build-ios-swift-test.yml`

Expo app flow:
1. Set GitHub repository variable or secret `EXPO_PUBLIC_API_URL` (production API URL used by CI builds).
2. Push to `main` (or run workflow manually).
3. Workflow builds unsigned `.ipa` on macOS runner.
4. Download from:
   - Action artifact `ios-unsigned-ipa`, or
   - Release tag `ios-latest` in GitHub Releases (easiest on GitHub mobile app).

Swift test app flow:
1. Run **Build iOS Swift Test App (Unsigned)** from GitHub Actions.
2. Optional workflow inputs:
   - `runner_image` (`macos-latest` default, `macos-15` fallback, `macos-26` if available).
   - `deployment_target` (default `26.0`) for the iOS build setting.
   - `publish_release` to control rolling release updates.
   - `artifact_suffix` to append a suffix to the IPA filename.
3. Download from:
   - Action artifact `ios-swift-test-unsigned-ipa`, or
   - Release tag `ios-swift-test-latest` in GitHub Releases.

Install flow:
- Import IPA into SideStore / LiveContainer.
- Use iOS Shortcuts + custom icons to launch multiple LiveContainer apps.

## Usage

### Adding a Movie

1. Click the **"Add"** button in the top right
2. Search for a movie using the search bar
3. Select the movie from results
4. Enter the name of who recommended it (autocomplete available)
5. Click **"Add Recommendation"**

The movie will be added to your "To Watch" list with TMDB and OMDb data.

### Marking as Watched

1. Click on a movie card to open details
2. Click **"Mark as Watched"**
3. Use the slider to rate the movie (1-10)
4. Click **"Save"**

If you rate below 6, you'll be prompted to manage other recommendations from that person.

### Managing People

1. Go to the **"People"** tab in bottom navigation
2. View all recommenders with their recommendation counts
3. Toggle **"Trust"** status for any person
4. Filter by trusted/untrusted

### Sync Status

The sync indicator in the top right shows:
- **✓ Synced** (green): All changes synced to server
- **↻ Pending** (yellow): Changes waiting to sync
- **⚠ Conflict** (orange): Some syncs failed (click to retry)
- **⊗ Offline** (gray): No internet connection

## API Endpoints

### Movies
- `GET /api/movies` - Get all movies
- `GET /api/movies/{imdbId}` - Get movie details
- `PUT /api/movies/{imdbId}/status` - Update movie status

### Recommendations
- `POST /api/movies/{imdbId}/recommendations` - Add recommendation
- `DELETE /api/movies/{imdbId}/recommendations/{person}` - Remove recommendation

### Watch History
- `PUT /api/movies/{imdbId}/watch` - Mark as watched with rating

### People
- `GET /api/people` - Get all people
- `POST /api/people` - Add person
- `PUT /api/people/{name}` - Update trusted status

### Sync
- `GET /api/sync?since={timestamp}` - Get changes since timestamp
- `POST /api/sync` - Process queued action

### Health
- `GET /api/health` - Health check

## Production Deployment

This app serves both frontend and backend from a single FastAPI server, making deployment simple.

### Build and Run Locally (Production Mode)

1. Build the frontend:
   ```bash
   cd frontend
   npm run build
   ```

2. Start the backend (serves both API and frontend):
   ```bash
   cd ../backend
   uv run uvicorn main:app --host 0.0.0.0 --port 8000
   ```

3. Access the app at `http://localhost:8000`

The backend automatically serves:
- API endpoints at `/api/*`
- Static assets at `/assets/*`
- The PWA frontend for all other routes

### Deploy to Railway/Render/Fly.io

1. Create a new project and connect your GitHub repository

2. Set build command:
   ```bash
   cd frontend && npm install && npm run build && cd ../backend && uv sync
   ```

3. Set start command:
   ```bash
   cd backend && uv run uvicorn main:app --host 0.0.0.0 --port $PORT
   ```

4. Add a persistent volume for `backend/app.db`

5. (Optional) Set environment variables for API key proxying:
   - `TMDB_API_KEY` - TMDB API key
   - `OMDB_API_KEY` - OMDb API key

6. Deploy!

Note: The frontend will automatically use the same server for API calls (same-origin) in production.

## Database Schema

### movies
- `imdb_id` (PK, TEXT) - IMDb ID
- `tmdb_data` (TEXT/JSON) - TMDB movie data
- `omdb_data` (TEXT/JSON) - OMDb movie data
- `last_modified` (FLOAT) - Unix timestamp

### recommendations
- `id` (PK, INTEGER) - Auto-increment ID
- `imdb_id` (FK, TEXT) - Movie IMDb ID
- `person` (TEXT) - Recommender name
- `date_recommended` (FLOAT) - Unix timestamp

### watch_history
- `imdb_id` (PK, FK, TEXT) - Movie IMDb ID
- `date_watched` (FLOAT) - Unix timestamp
- `my_rating` (FLOAT) - Rating 1.0-10.0

### people
- `name` (PK, TEXT) - Person name
- `is_trusted` (BOOLEAN) - Trusted status

### movie_status
- `imdb_id` (PK, FK, TEXT) - Movie IMDb ID
- `status` (TEXT) - Status: toWatch, watched, questionable, deleted

## Offline Architecture

### Data Flow

1. **User Action** → Saved to IndexedDB immediately (optimistic update)
2. **Sync Queue** → Action added to queue with timestamp and retry count
3. **Queue Processor** → Runs every 30s, when online, or on user action
4. **Backend** → Processes action and returns `lastModified` timestamp
5. **Conflict Resolution** → Last-write-wins using server timestamp

### IndexedDB Stores

- **movies**: Movie data with status, recommendations, watch history
- **syncQueue**: Pending actions to sync to server
- **metadata**: App metadata (lastSync timestamp)
- **people**: People/recommenders data

## Development

### Adding a New Migration

```bash
cd backend
uv run alembic revision --autogenerate -m "description"
uv run alembic upgrade head
```

### Clearing IndexedDB (for testing)

Open DevTools → Application → IndexedDB → Delete `movieRecommendations`

### Running Backend Tests

```bash
cd backend
uv run pytest  # (tests not included in MVP)
```

## Troubleshooting

### Backend won't start
- Check Python version: `python --version` (need 3.11+)
- Reinstall dependencies: `uv sync --reinstall`
- Check if port 8000 is already in use

### Frontend won't start
- Check Node version: `node --version` (need 18+)
- Delete `node_modules` and reinstall: `rm -rf node_modules && npm install`
- Check if port 5173 is already in use

### Sync not working
- Check backend is running and accessible
- Check browser console for errors
- Verify `VITE_API_URL` in frontend `.env`
- Check CORS settings in backend `main.py`

### Movies not appearing
- Check IndexedDB in DevTools → Application tab
- Verify API keys are correct in `.env`
- Check browser console for API errors

## License

MIT License - see LICENSE file

## CI/CD Pipelines

The repository includes automated build pipelines for all iOS apps that build unsigned IPAs for sideloading:

### Mobile Swift App (`mobile-swift/`)
- **Workflow**: `.github/workflows/build-mobile-swift.yml`
- **Triggers**: 
  - Manual dispatch from GitHub Actions UI
  - Pull requests when `mobile-swift/**` changes
  - Push to main when `mobile-swift/**` changes
- **Outputs**: 
  - Artifact: `mobile-swift-unsigned-ipa`
  - Release: `mobile-swift-latest` tag

### Mobile React Native App (`mobile/`)
- **Workflow**: `.github/workflows/build-ios-simple.yml`
- **Triggers**:
  - Manual dispatch from GitHub Actions UI
  - Pull requests when `mobile/**` changes
  - Push to main when `mobile/**` changes
- **Outputs**:
  - Artifact: `ios-unsigned-ipa`
  - Release: `ios-latest` tag

### iOS Test Swift App (`ios-test-swift/`)
- **Workflow**: `.github/workflows/build-ios-swift-test.yml`
- **Triggers**:
  - Manual dispatch from GitHub Actions UI
  - Pull requests when `ios-test-swift/**` changes
  - Push to main when `ios-test-swift/**` changes
- **Outputs**:
  - Artifact: `ios-swift-test-unsigned-ipa`
  - Release: `ios-swift-test-latest` tag

All pipelines use path-based filtering to ensure they only run when their respective folders change, reducing unnecessary builds and CI costs.

## Credits

- Movie data from [TMDB](https://www.themoviedb.org/)
- Ratings from [OMDb](http://www.omdbapi.com/)
- Icons from [Lucide](https://lucide.dev/)

---

Built with by [Your Name] • [GitHub](https://github.com/yourusername/mm)
