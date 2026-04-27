# Gymbo — Gym Tracker Application Plan

## Context
Creating a new gym tracker app at `/Users/nadeem/Documents/random/gymbo/` that mirrors the mm (movie manager) app's full tech stack.

**Architecture split:**
- **Backend**: FastAPI + SQLite — source of truth
- **Web frontend**: Stateless thin client — no offline/sync complexity, just API calls per page
- **iOS mobile app**: Primary client — full local-first architecture (GRDB SQLite, pending operations, WebSocket sync, biometric auth, backup, Swift Charts)

**User preferences confirmed:**
- Weight units: toggle kg/lbs as a display label; always store the raw number the user typed (no unit conversion)
- Plates/barbell: user enters plates-per-side; app shows "X/side + Y kg bar = Z total"; barbell weight is a configurable user setting per user (default 20 kg)
- Weekly schedule: multiple templates can be assigned per day (one-to-many)
- Charts: Recharts for React web (stateless); Swift Charts (native) for iOS

---

## 1. Backend

### Directory Structure

```
gymbo/backend/
├── pyproject.toml
├── alembic.ini
├── .env / .env.example                 # PORT=8002, SECRET_KEY, ADMIN_TOKEN
├── database.py                         # identical to mm
├── models.py
├── auth.py                             # identical to mm
├── alembic/
│   ├── env.py
│   └── versions/0001_initial_schema.py
└── app/
    ├── main.py                         # factory + CORS + scheduler + seed + SPA
    ├── config.py                       # no external API keys needed
    ├── api/
    │   ├── router.py
    │   └── routers/
    │       ├── auth.py                 # identical to mm
    │       ├── health.py               # identical to mm
    │       ├── exercises.py
    │       ├── workout_types.py
    │       ├── templates.py
    │       ├── schedule.py
    │       ├── sessions.py
    │       ├── metrics.py
    │       ├── sync.py                 # WebSocket + batch (adapted from mm)
    │       └── backup.py               # identical pattern to mm
    ├── schemas/
    │   ├── exercises.py
    │   ├── templates.py
    │   ├── schedule.py
    │   ├── sessions.py
    │   ├── metrics.py
    │   └── sync.py                     # identical to mm
    └── services/
        ├── sessions.py                 # progressive overload logic
        ├── metrics.py                  # streak, volume, 1RM, PR detection
        ├── backup.py
        ├── seed.py                     # system exercises / templates / types
        ├── notifications.py            # adapted from mm
        ├── conflict_resolver.py        # identical to mm
        └── security.py                 # identical to mm
```

### Data Models (`models.py`)

All UUIDs as string PKs, Unix float timestamps, `last_modified` on every syncable entity.

**`User`** — identical to mm + two extra columns:
- `unit_preference` String default "kg"
- `barbell_weight` Float default 20.0

**`WorkoutType`**
- `id` UUID PK, `user_id` → users (NULL = system), `name`, `slug`, `icon`, `color`, `is_system`
- UNIQUE on `(user_id, slug)`

**`Exercise`**
- `id` UUID PK, `user_id` → users (NULL = system/visible to all)
- `name`, `description`, `muscle_group`
- `workout_type_id` → workout_types
- `weight_type` CHECK: `dumbbell | plates | machine | bodyweight | time_based | distance`
- `is_system`, `last_modified`

**`WorkoutTemplate`**
- `id` UUID PK, `user_id` → users (NULL = system)
- `name`, `description`, `workout_type_id`, `is_system`, `last_modified`, `created_at`

**`WorkoutTemplateExercise`** (join with ordering + defaults)
- `id` UUID PK, `template_id` CASCADE, `exercise_id` CASCADE
- `position` Int (UNIQUE per template), `default_sets`, `default_reps`, `default_weight`, `default_duration_secs`, `default_distance`, `notes`

**`WeeklySchedule`**
- `id` UUID PK, `user_id` CASCADE
- `day_of_week` Int CHECK 0–6 (0=Mon), `template_id` SET NULL
- No UNIQUE on (user_id, day_of_week) — multiple templates per day allowed

**`WorkoutSession`**
- `id` UUID PK, `user_id` CASCADE, `template_id` SET NULL (NULL = freeform)
- `date` Float (Unix timestamp), `started_at`, `finished_at`, `duration_secs`, `notes`
- `status` CHECK: `in_progress | completed | abandoned`
- `last_modified`; indexed on `(user_id, date)` and `(user_id, last_modified)`

**`SessionExercise`**
- `id` UUID PK, `session_id` CASCADE, `exercise_id` CASCADE, `position`, `notes`

**`SessionSet`**
- `id` UUID PK, `session_exercise_id` CASCADE
- `set_number` (1-indexed), `reps`, `weight` Float (raw user value — no unit conversion ever)
- `duration_secs` (time_based), `distance` Float km (distance), `completed` Bool, `rpe` Float

### API Routes

**Auth** (identical to mm): `POST /login`, `POST /admin/login`, `POST /admin/users`, `GET /me`, `PUT /me` (for unit_preference + barbell_weight)

**Workout Types**: `GET|POST /workout-types`, `PUT|DELETE /workout-types/{id}`

**Exercises**: `GET|POST /exercises`, `GET|PUT|DELETE /exercises/{id}`
- `GET /exercises` supports `?muscle_group=&weight_type=`; returns system + user exercises

**Templates**:
- `GET|POST /templates`, `GET|PUT|DELETE /templates/{id}`
- `POST /templates/{id}/exercises`, `PUT|DELETE /templates/{id}/exercises/{eid}`
- `POST /templates/{id}/reorder`
- `POST /templates` body accepts `clone_from` ID to clone a system template

**Schedule**:
- `GET /schedule` — all entries (may be multiple per day)
- `PUT /schedule` — replace full schedule (array of `{day_of_week, template_id}`)
- `DELETE /schedule/{id}` — remove one entry
- `GET /schedule/today` — today's templates + whether each has a completed session today

**Sessions**:
- `GET /sessions` `?since=&date=YYYY-MM-DD&template_id=&status=`
- `POST /sessions` — triggers progressive overload pre-population on backend
- `GET|PUT|DELETE /sessions/{id}`
- `POST /sessions/{id}/complete` — sets finished_at, computes duration, detects PRs
- `POST /sessions/{id}/exercises`, `PUT|DELETE /sessions/{id}/exercises/{eid}`
- `POST /sessions/{id}/exercises/{eid}/sets`, `PUT|DELETE /sessions/{id}/exercises/{eid}/sets/{sid}`

**Metrics**:
- `GET /metrics/summary` — streak, total sessions, total volume, PR count
- `GET /metrics/calendar` `?year=&month=` — `[{date, session_count, volume}]`
- `GET /metrics/exercise/{id}` — weight + estimated 1RM over time
- `GET /metrics/frequency` — sessions by workout_type over past N weeks
- `GET /metrics/prs` — all-time PRs per exercise
- `GET /metrics/streak` — `{current_streak, longest_streak}`

**Sync** (adapted from mm): `GET /sync/changes`, `POST /sync/batch`, `WS /ws/sync`

**Backup** (identical pattern to mm): `GET|POST /backup/export|import|settings|list|restore/{filename}`

**Health** (identical): `GET /health`

### Progressive Overload Logic (`services/sessions.py`)

On `POST /api/sessions` with a `template_id`:
1. Load template exercises ordered by position
2. For each exercise, call `get_prior_sets(db, user_id, template_id, exercise_id)`:
   - **Primary**: most recent completed session with same `template_id` + `exercise_id`
   - **Fallback 1**: most recent completed session with any `template_id` containing `exercise_id`
   - **Fallback 2**: template's `default_sets / default_reps / default_weight`
3. Create `SessionExercise` + `SessionSet` rows pre-populated with prior data, `completed=False`

### Sync Action Types

```
addExercise, updateExercise, deleteExercise
addTemplate, updateTemplate, deleteTemplate, updateTemplateExercises
updateSchedule
startSession, updateSession, logSet, completeSession, deleteSession
```

WebSocket push events: `sessionUpdated`, `sessionCompleted`, `templateUpdated`, `exerciseUpdated`, `scheduleUpdated`

### Seed Data (`services/seed.py`, runs at startup if workout_types empty)

**7 System Workout Types**: Lifting, Running, Pilates, Mobility/Stretching, Plyometric Drills, Hyrox Training, Custom

**~40 System Exercises** across: chest (Bench Press/plates, Incline DB Press/dumbbell, Push Up/bodyweight), back (Deadlift/plates, Pull Up/bodyweight, Barbell Row/plates, Lat Pulldown/machine, Seated Row/machine), shoulders (OHP/plates, Lateral Raise/dumbbell, Face Pull/machine), biceps (Barbell Curl/plates, Dumbbell Curl/dumbbell, Hammer Curl/dumbbell), triceps (Tricep Pushdown/machine, Skull Crushers/plates, Dip/bodyweight), legs (Squat/plates, Romanian DL/plates, Leg Press/machine, Leg Curl/machine, Leg Extension/machine, Calf Raise/machine, Bulgarian Split Squat/dumbbell, Lunges/dumbbell), core (Plank/time_based, Cable Crunch/machine), cardio (Treadmill Run/distance, Outdoor Run/distance, Rowing Machine/distance), plyometric (Box Jump/bodyweight, Burpee/bodyweight, Jump Rope/time_based), pilates (Hundred/bodyweight, Roll Up/bodyweight), mobility (Hip Flexor Stretch/time_based)

**5 System Templates**: Push Day, Pull Day, Leg Day, Full Body Strength, 5K Run

### Config Differences vs mm
- Port: `8002` (mm uses `8001`)
- No external API keys
- `User` model gains `unit_preference` + `barbell_weight`

---

## 2. Web Frontend (Stateless Thin Client)

The web app is a simple, stateless React app. No offline caching, no WebSocket sync, no local storage beyond the auth JWT. Each page fetches fresh from the API on load.

### Directory Structure

```
gymbo/frontend/
├── package.json                        # React 19, Recharts, no extra deps
├── vite.config.js                      # proxy to :8002
├── index.html
└── src/
    ├── main.tsx
    ├── App.tsx
    ├── index.css                        # same Tailwind + iOS tokens as mm
    ├── components/
    │   ├── AuthScreen.tsx               # identical to mm
    │   ├── layout/
    │   │   ├── AppShell.tsx
    │   │   └── Sidebar.tsx
    │   └── ui/
    │       └── Modal.tsx
    ├── contexts/
    │   └── AuthContext.tsx              # JWT only, key: gymbo_auth_token
    ├── pages/
    │   ├── DashboardPage.tsx
    │   ├── LogPage.tsx
    │   ├── ActiveSessionPage.tsx        # in-progress logging
    │   ├── HistoryPage.tsx
    │   ├── ExercisesPage.tsx
    │   ├── TemplatesPage.tsx
    │   ├── SchedulePage.tsx
    │   ├── MetricsPage.tsx              # Recharts charts
    │   └── AccountPage.tsx
    └── services/
        └── api.ts                       # APIClient singleton (mirrors mm)
```

### Routes

```
/                   DashboardPage   — today's schedule, recent sessions
/log                LogPage         — template picker
/log/:sessionId     ActiveSessionPage
/history            HistoryPage
/exercises          ExercisesPage
/templates          TemplatesPage
/schedule           SchedulePage
/metrics            MetricsPage     — Recharts charts
/account            AccountPage
```

### Simplified State
- `AuthContext` only (JWT + user object)
- Each page uses `useState` + `useEffect` to fetch on mount
- No WorkoutsContext, no useSync, no offline logic
- `api.ts`: singleton `APIClient` with all endpoints, Bearer token injection

---

## 3. iOS Mobile App (Primary Client)

Mirrors mm's mobile architecture exactly. Full local-first with GRDB SQLite, pending operations queue, WebSocket sync, biometric auth, backup, Swift Charts.

### Directory Structure

```
gymbo/mobile/
├── project.yml                          # XcodeGen config
├── .env.example                         # API_BASE_URL, FILE_LOGGING_ENABLED
├── Config/
│   └── App.xcconfig
├── scripts/
│   └── generate-env-xcconfig.sh         # identical to mm's
└── Sources/
    ├── GymboApp.swift                    # @main entry point
    ├── Info.plist
    ├── Assets.xcassets/
    ├── Models/
    │   ├── TabItem.swift
    │   ├── WorkoutModels.swift           # Codable structs (Exercise, Template, Session, Set, etc.)
    │   └── MetricsModels.swift           # Streak, PR, VolumePoint, CalendarDay
    ├── Services/
    │   ├── AuthManager.swift             # JWT + Keychain (identical to mm pattern)
    │   ├── NetworkService.swift          # REST API client (all gymbo endpoints)
    │   ├── DatabaseManager.swift         # GRDB wrapper + migrations
    │   ├── WorkoutRepository.swift       # Data repository (mirrors MovieRepository)
    │   ├── SyncManager.swift             # Pending operations retry (mirrors mm)
    │   ├── WebSocketManager.swift        # Real-time push (identical to mm pattern)
    │   ├── BiometricAuthManager.swift    # Face/Touch ID (identical to mm)
    │   ├── AppConfiguration.swift        # URL validation (identical to mm)
    │   └── AppLogging.swift              # Structured logging (identical to mm)
    ├── Theme/
    │   └── AppTheme.swift                # Colors + workout type colors
    └── Views/
        ├── LoginView.swift
        ├── RootTabHostView.swift         # TabView with 5 tabs
        ├── Tabs/
        │   ├── DashboardView.swift       # Today's schedule, streak, recent sessions
        │   ├── LogWorkoutView.swift      # Template picker + start session
        │   ├── HistoryView.swift         # Calendar heatmap + session list
        │   ├── MetricsView.swift         # Swift Charts: progress, volume, PRs
        │   └── AccountView.swift         # Settings, backup, biometrics
        ├── WorkoutSession/
        │   ├── ActiveSessionView.swift   # In-progress workout logging
        │   ├── ExerciseSection.swift     # Exercise + its sets
        │   ├── SetRowView.swift          # Individual set row
        │   └── WeightInputView.swift     # Renders per weight_type
        ├── Templates/
        │   ├── TemplatesListView.swift
        │   ├── TemplateDetailView.swift
        │   └── TemplateBuilderView.swift
        ├── Exercises/
        │   ├── ExercisesListView.swift
        │   └── ExercisePickerView.swift
        ├── Schedule/
        │   └── ScheduleEditorView.swift
        └── Components/
            └── WorkoutTypeChip.swift
```

### XcodeGen (`project.yml`)

```yaml
name: Gymbo
options:
  minimumXcodeGenVersion: 2.39.0
targets:
  Gymbo:
    type: application
    platform: iOS
    deploymentTarget: "17.0"        # iOS 17 for Swift Charts 2.0
    sources: Sources
    info:
      path: Sources/Info.plist
    settings:
      base:
        SWIFT_VERSION: 6.0
        API_BASE_URL: $(API_BASE_URL)
        FILE_LOGGING_ENABLED: $(FILE_LOGGING_ENABLED)
    configFiles:
      Debug: Config/App.xcconfig
      Release: Config/App.xcconfig
    dependencies:
      - package: Nuke
        product: NukeUI
      - package: GRDB
        product: GRDB
packages:
  Nuke:
    url: https://github.com/kean/Nuke
    exactVersion: 12.8.0
  GRDB:
    url: https://github.com/groue/GRDB.swift
    exactVersion: 7.5.0
```

**Note**: Swift Charts is built-in to iOS 16+; no extra package needed.

### GRDB Local Models (`DatabaseManager.swift`)

All local GRDB models mirror the backend SQLAlchemy schema. They conform to `FetchableRecord + PersistableRecord`.

```swift
// Stored locally in GRDB
struct CachedExercise: FetchableRecord, PersistableRecord {
    static let databaseTableName = "exercises"
    var id: String
    var name: String
    var muscleGroup: String?
    var workoutTypeId: String?
    var weightType: String           // "dumbbell"|"plates"|"machine"|"bodyweight"|"time_based"|"distance"
    var isSystem: Bool
    var userId: String?
    var lastModified: Double
}

struct CachedWorkoutType: FetchableRecord, PersistableRecord {
    static let databaseTableName = "workout_types"
    var id: String; var name: String; var slug: String
    var icon: String?; var color: String; var isSystem: Bool; var userId: String?
}

struct CachedTemplate: FetchableRecord, PersistableRecord {
    static let databaseTableName = "workout_templates"
    var id: String; var name: String; var description: String?
    var workoutTypeId: String?; var isSystem: Bool; var userId: String?
    var lastModified: Double; var jsonData: String  // full JSON for offline use
}

struct CachedSession: FetchableRecord, PersistableRecord {
    static let databaseTableName = "workout_sessions"
    var id: String; var templateId: String?; var date: Double
    var startedAt: Double?; var finishedAt: Double?; var durationSecs: Int?
    var notes: String?; var status: String; var lastModified: Double
    var jsonData: String   // full serialized session JSON
}

struct PendingOperation: FetchableRecord, PersistableRecord {
    static let databaseTableName = "pending_operations"
    var id: String; var type: String; var payload: String  // JSON
    var createdAt: Double; var retryCount: Int
}
```

**GRDB Migrations** (DatabaseManager):
- v1: `workout_types`, `exercises`, `workout_templates`, `workout_sessions`, `pending_operations`
- v2: Add `json_data` to templates + sessions for full offline access
- v3+: Additive migrations as schema evolves

**Database location**: `Documents/gymbo.sqlite3`

### Pending Operation Types (offline queue)

```swift
// type field values in PendingOperation
"start_session"           // payload: {template_id, date, notes}
"update_session"          // payload: {id, notes?, status?, duration_secs?}
"complete_session"        // payload: {id, finished_at}
"log_set"                 // payload: {session_id, exercise_id, set_number, reps, weight, completed, ...}
"add_session_exercise"    // payload: {session_id, exercise_id, position}
"delete_session"          // payload: {id}
"create_exercise"         // payload: {name, muscle_group, weight_type, ...}
"update_template"         // payload: {id, ...}
"update_schedule"         // payload: [{day_of_week, template_id}]
```

### Progressive Overload (Local)

`WorkoutRepository.getProgressiveOverloadDefaults(templateId:)`:
1. Query `workout_sessions` GRDB table for most recent completed session with same `template_id`
2. If found, extract sets from its `json_data`
3. Fallback to any session containing the same exercise
4. Fallback to template's defaults from `json_data`
5. Pre-populates the `ActiveSessionView` state before user starts

This works fully offline since all past sessions are cached in GRDB.

### WebSocket Manager

Identical to mm's `WebSocketManager.swift`. Event type names updated:
- `sessionUpdated`, `sessionCompleted`, `templateUpdated`, `exerciseUpdated`, `scheduleUpdated`
- On any event: triggers `WorkoutRepository.syncNow()`

### NetworkService (all gymbo endpoints)

Mirrors mm's `NetworkService.swift`. Methods cover all backend routes:
- Auth: `login()`, `verifyToken()`, `updateProfile()` (unit_preference, barbell_weight)
- Exercises: `fetchExercises()`, `createExercise()`, `updateExercise()`, `deleteExercise()`
- Workout Types: `fetchWorkoutTypes()`, `createWorkoutType()`
- Templates: `fetchTemplates()`, `fetchTemplate(id:)`, `createTemplate()`, `updateTemplate()`, `deleteTemplate()`, `cloneTemplate(id:)`, `reorderTemplateExercises()`
- Schedule: `fetchSchedule()`, `updateSchedule()`, `fetchTodaySchedule()`
- Sessions: `fetchSessions()`, `startSession()`, `fetchSession(id:)`, `updateSession()`, `completeSession()`, `addSet()`, `updateSet()`, `deleteSet()`, `addExerciseToSession()`, `deleteSession()`
- Metrics: `fetchMetricsSummary()`, `fetchCalendarData()`, `fetchExerciseProgress(id:)`, `fetchPRs()`, `fetchStreak()`
- Backup: `exportBackup()`, `importBackup()`, `getBackupSettings()`, `updateBackupSettings()`, `listBackups()`
- Sync: `fetchChanges(since:)`, `batchSync()`

### SwiftUI Views

**Tabs (5)**: Dashboard, Log Workout, History, Metrics, Account

**`DashboardView`**:
- Today's day name + date
- Today's scheduled workout(s) as tappable cards (from local cache or `/schedule/today`)
- "Start Workout" button per scheduled template → navigates to `ActiveSessionView`
- Recent sessions list (last 7, from GRDB cache)
- Streak badge (current streak from local calc or last fetched from metrics)

**`LogWorkoutView`**:
- System + user templates in a grid/list with workout type color accent
- "Start from Scratch" option (no template)
- Tapping a template → calls `WorkoutRepository.startSession(templateId:)` → navigates to `ActiveSessionView`
- If offline: operation queued in `PendingOperation`, optimistic session created in GRDB

**`ActiveSessionView`**:
- Timer (elapsed time via `Date()` diff)
- List of `ExerciseSection` views
- Each `ExerciseSection` contains `SetRowView` rows + "Add Set" button
- "Add Exercise" button opens `ExercisePickerView` sheet
- "Finish Workout" button → `WorkoutRepository.completeSession()` → navigates to `HistoryView`
- All set updates immediately written to GRDB + enqueued as `PendingOperation` if offline

**`SetRowView`**:
- `[set#] [reps] [WeightInputView] [done checkbox]`
- Tapping done checkbox: marks set completed, saves to GRDB + backend

**`WeightInputView`** (per weight_type):
- `dumbbell`: stepper/field + "per dumbbell" label + "2× X kg" display
- `plates`: stepper/field + "/side" label + "{X}/side + {barbell}kg bar = {total}kg" display (barbell_weight from user profile)
- `machine`: field + "kg total"
- `bodyweight`: label only "Bodyweight"
- `time_based`: field + "seconds"
- `distance`: field + "km" or "miles" (from unit_preference)

**`HistoryView`**:
- Monthly calendar grid with day cells colored by session count (0=none, 1=light green, 2+=bright green)
- List of sessions below calendar grouped by week
- Tap session → detail sheet with full exercise/set data

**`MetricsView`** (Swift Charts):
- Summary cards: streak, total sessions, total volume, PR count
- `LineChart` for weight progression on a selected exercise (1RM estimates overlaid)
- `BarChart` for weekly volume (total kg lifted per week)
- `AreaChart` for session frequency by workout type

**`AccountView`**:
- Profile: username, email
- Settings: unit toggle (kg/lbs), barbell weight input
- Backup section: Export, Import (document picker), List server backups
- Biometric toggle (Face/Touch ID)
- Developer tools: force sync, clear cache, view logs
- Sign out

**`TemplatesListView`** / **`TemplateBuilderView`**:
- List system + user templates filterable by workout type
- Builder: name + workout type picker + ordered exercise list with defaults
- Clone system template → editable copy

**`ScheduleEditorView`**:
- 7-day grid (Mon–Sun)
- Each day: list of assigned templates (can add multiple)
- Tap "+" on a day → `ExercisePickerView`-style template picker
- Swipe to remove an assignment

### App Theme (`AppTheme.swift`)

```swift
extension Color {
    // Mirrors mm's iOS color tokens
    static let gymboBlue = Color(red: 0.04, green: 0.52, blue: 1.0)
    static let gymboGreen = Color(red: 0.19, green: 0.82, blue: 0.35)
    static let gymboRed = Color(red: 1.0, green: 0.23, blue: 0.37)
    static let gymboOrange = Color(red: 1.0, green: 0.62, blue: 0.04)
    static let gymboPurple = Color(red: 0.75, green: 0.35, blue: 0.95)
}

// Workout type → Color mapping
static func color(for slug: String) -> Color {
    switch slug {
    case "lifting":    return .gymboBlue
    case "running":    return .gymboGreen
    case "pilates":    return .gymboPurple
    case "mobility":   return Color(red: 1.0, green: 0.84, blue: 0.04)
    case "plyometric": return .gymboOrange
    case "hyrox":      return .gymboRed
    default:           return Color(red: 0.39, green: 0.82, blue: 1.0)
    }
}
```

---

## 4. Implementation Order

### Phase 1 — Backend Foundation
1. Create `gymbo/backend/` directory tree
2. `pyproject.toml` + `uv sync`, `database.py`, `auth.py`, `config.py` (adapt from mm)
3. `models.py` (9 models)
4. Alembic setup + `0001_initial_schema.py`
5. `app/main.py` with FastAPI factory, CORS, startup seed, scheduler, SPA serving

### Phase 2 — Backend Routers
6. `auth.py`, `health.py` (identical to mm)
7. `workout_types.py`, `exercises.py` (CRUD + system query)
8. `templates.py` (CRUD + exercise management + reorder + clone)
9. `schedule.py` (multi-entry-per-day)
10. `services/sessions.py` (progressive overload logic)
11. `sessions.py` router (full lifecycle + set CRUD)

### Phase 3 — Backend Sync + Backup + Metrics
12. `notifications.py`, `conflict_resolver.py`, `security.py`
13. `sync.py` router (WebSocket + batch)
14. `backup.py` service + router
15. `metrics.py` service + router (streak, volume, 1RM Epley, PR detection on session completion)

### Phase 4 — Seed Data
16. `services/seed.py` + hook into startup

### Phase 5 — Web Frontend (Stateless)
17. `frontend/` directory, `package.json` (add recharts), `vite.config.js`
18. `AuthContext.tsx`, `api.ts`, `AppShell.tsx`, `Sidebar.tsx`
19. All pages (stateless: fetch on mount, no context caching)

### Phase 6 — iOS App Bootstrap
20. `mobile/project.yml`, `Config/App.xcconfig`, `generate-env-xcconfig.sh`
21. `GymboApp.swift`, `AppConfiguration.swift`, `AppTheme.swift`
22. `AuthManager.swift`, `AppLogging.swift`, `BiometricAuthManager.swift` (from mm)
23. `DatabaseManager.swift` with all GRDB tables + migrations
24. `WorkoutModels.swift`, `MetricsModels.swift` (Codable structs)

### Phase 7 — iOS Services
25. `NetworkService.swift` (all gymbo endpoints)
26. `WorkoutRepository.swift` (sync + progressive overload)
27. `SyncManager.swift` (pending ops retry, from mm)
28. `WebSocketManager.swift` (from mm, event names updated)

### Phase 8 — iOS Views
29. `LoginView.swift`, `RootTabHostView.swift`
30. `DashboardView.swift`, `LogWorkoutView.swift`
31. `ActiveSessionView.swift` + `ExerciseSection`, `SetRowView`, `WeightInputView`
32. `HistoryView.swift` (calendar heatmap CSS grid equivalent in SwiftUI)
33. `MetricsView.swift` (Swift Charts)
34. `TemplatesListView.swift`, `TemplateBuilderView.swift`
35. `ExercisesListView.swift`, `ExercisePickerView.swift`
36. `ScheduleEditorView.swift`
37. `AccountView.swift` (unit pref, barbell weight, backup, biometrics)

---

## 5. Metrics Implementation Notes

- **Streak**: consecutive days (ending today or yesterday) with ≥1 completed session; calculated both locally in iOS and on backend
- **Volume**: `weight × reps × sets` for weighted exercises; raw `distance` or `duration_secs` for others
- **1RM estimate**: Epley formula — `weight × (1 + reps / 30.0)`, shown on exercise progress chart
- **PR detection**: runs on `POST /api/sessions/{id}/complete`; compares each completed set to all-time max weight for that exercise at that rep count; stored as a flag in the response for iOS to surface as a notification

---

## 6. Critical Reference Files (mm → gymbo adaptation)

| mm file | gymbo adaptation |
|---|---|
| `mm/backend/models.py` | UUID PKs, Float timestamps, cascade, CheckConstraints pattern |
| `mm/backend/app/main.py` | FastAPI factory, `ensure_additive_schema()`, scheduler, SPA catch-all |
| `mm/backend/app/api/routers/sync.py` | WebSocket, `_collect_changes()`, batch dispatch |
| `mm/backend/app/services/backup.py` | Versioned export/import |
| `mm/frontend/src/services/api.ts` | Singleton APIClient pattern |
| `mm/frontend/src/contexts/AuthContext.tsx` | JWT context (simplify — no sync needed) |
| `mm/mobile/Sources/Services/DatabaseManager.swift` | GRDB migrations + CRUD pattern |
| `mm/mobile/Sources/Services/MovieRepository.swift` | Repository sync pattern |
| `mm/mobile/Sources/Services/SyncManager.swift` | Pending operations retry |
| `mm/mobile/Sources/Services/WebSocketManager.swift` | WebSocket lifecycle |
| `mm/mobile/Sources/Services/NetworkService.swift` | REST client pattern |
| `mm/mobile/Sources/Services/AuthManager.swift` | Keychain token storage |
| `mm/mobile/project.yml` | XcodeGen config structure |

---

## 7. Verification / Testing Checklist

**Backend:**
- [ ] `uv run alembic upgrade head` succeeds
- [ ] Server starts on port 8002, seeds system data, health endpoint responds
- [ ] Auth: create user, login returns JWT, `PUT /auth/me` updates unit_preference + barbell_weight
- [ ] Create exercise, template, schedule entry via API
- [ ] `POST /sessions` returns pre-populated sets from prior session data
- [ ] `POST /sessions/{id}/complete` triggers PR detection
- [ ] WebSocket: second client receives `sessionUpdated` event on set save
- [ ] Backup export → valid JSON; import restores all data

**Web frontend:**
- [ ] `npm run dev` → auth screen → all routes load fresh data on each visit
- [ ] MetricsPage renders Recharts charts with real data
- [ ] Unit label shows "kg" or "lbs" based on user preference

**iOS:**
- [ ] `xcodegen generate` succeeds; app builds and runs on simulator
- [ ] Login → token stored in Keychain → data syncs into GRDB
- [ ] Airplane mode: can start session, log sets, complete session (pending ops queued)
- [ ] Back online: pending ops flush, server reflects changes
- [ ] WeightInputView: plates mode shows correct total with configurable barbell weight
- [ ] Swift Charts: exercise progress chart animates with real data
- [ ] Backup export → share sheet → import restores data
- [ ] Biometric lock works on app background
