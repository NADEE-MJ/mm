# Plan: Quick Recommender System Upgrade (`quick_key`)

## Context

Quick recommenders (YouTube, Oscar, Random Person, Google) are currently defined as a hardcoded `DEFAULT_RECOMMENDERS` constant in the frontend. The frontend merges these client-side with the user's actual DB-backed people on every render, and `usePeople.ts` auto-creates them in the DB when missing. The backend has no concept of "quick" — it treats them as ordinary Person rows.

Problems:
- Quick recommenders are not in the mobile app at all
- The frontend's client-side merge/deduplication logic is fragile and duplicates concern
- No stable identity: if a user renames one, it loses its "quick" status
- No delete protection (users can accidentally delete them)

**Solution**: Add a `quick_key` nullable string column to the `people` table. The 4 canonical quick recommenders have a stable key (`"youtube"`, `"oscar"`, `"random_person"`, `"google"`) regardless of what the user renames them. They're seeded on account creation, undeletable via the API, and the frontend/mobile simply check `quick_key != null` to identify them.

---

## Quick Recommender Keys & Defaults

```python
QUICK_RECOMMENDERS = [
    {"key": "youtube",       "name": "Random YouTube Video", "color": "#bf5af2", "emoji": "📺"},
    {"key": "oscar",         "name": "Oscar Winner/Nominee", "color": "#ffd60a", "emoji": "🏆"},
    {"key": "random_person", "name": "Random Person",        "color": "#30d158", "emoji": "🤝"},
    {"key": "google",        "name": "Google Search",        "color": "#64d2ff", "emoji": "🔎"},
]
```

---

## Step 1 — Backend: Model

**File:** `backend/models.py`

Add `quick_key` column to `Person` after `emoji` (line 163):
```python
quick_key = Column(String, nullable=True)  # e.g. "youtube", "oscar", "random_person", "google"
```

---

## Step 2 — Backend: Alembic Migration

**New file:** `backend/alembic/versions/<new_rev>_add_quick_key_to_people.py`

Down revision: `b7f5a11f9c2e`.

Migration steps (follow SQLite table-copy pattern from existing migration):
1. Create `people_new` with `quick_key VARCHAR` column added
2. Copy all existing rows with `quick_key = NULL`
3. Backfill: for each of the 4 quick names, `UPDATE people_new SET quick_key = '<key>' WHERE name = '<name>'` (scoped per-user is fine since name+user_id is unique)
4. Drop old table, rename new one, recreate indexes/constraints
5. Downgrade: same table-copy pattern removing the `quick_key` column

---

## Step 3 — Backend: Schemas

**File:** `backend/app/schemas/people.py`

Add `quick_key: Optional[str] = None` to all four schemas:
- `PersonCreate` (line 18) — allow client to pass it, but in practice only seeding uses it
- `PersonResponse` (line 27) — returned to all clients
- `PersonUpdate` (line 37) — allow updating? No — `quick_key` is **immutable after creation**, so do NOT add to PersonUpdate
- `PersonStatsResponse` (line 51) — add it

---

## Step 4 — Backend: People Router

**File:** `backend/app/api/routers/people.py`

1. **GET /people** (lines 42–51): Add `"quick_key": person.quick_key` to the response dict.

2. **POST /people** (lines 74–80): Add `quick_key=person.quick_key` to `Person(...)` constructor. Only used if client explicitly passes it (rare; mostly for admin/migration).

3. **DELETE /people/{name}** (lines 119–136): Add guard at the start:
   ```python
   if db_person.quick_key is not None:
       raise HTTPException(status_code=400, detail="Quick recommenders cannot be deleted")
   ```

4. **GET /people/{name}/stats** (lines 139–194): Ensure `quick_key` is included in `PersonStatsResponse` (handled via schema).

---

## Step 5 — Backend: Account Creation Seeding

**File:** `backend/auth.py`

In `create_user()`, after `db.refresh(db_user)` (line 152), add a call to a new helper:

```python
def seed_quick_recommenders(db: Session, user_id: str) -> None:
    for rec in QUICK_RECOMMENDERS:
        db.add(Person(
            name=rec["name"],
            user_id=user_id,
            is_trusted=False,
            color=rec["color"],
            emoji=rec["emoji"],
            quick_key=rec["key"],
        ))
    db.commit()
```

Define `QUICK_RECOMMENDERS` list at the top of `auth.py`. Call `seed_quick_recommenders(db, db_user.id)` inside `create_user()`.

---

## Step 6 — Backend: Sync Router

**File:** `backend/app/api/routers/sync.py`

1. **`_person_payload()`** (lines 58–67): Add `"quick_key": person.quick_key`.

2. **`addPerson` action** (lines 550–558): Add `quick_key=data.get("quick_key")` to `Person(...)` constructor.

3. **`updatePerson` action** (lines 573–578): Do **not** allow changing `quick_key` via sync. Only `name`, `color`, `emoji`, `is_trusted` are updatable.

---

## Step 7 — Frontend: Remove Hardcoded Defaults

### `frontend/src/utils/constants.ts`
Remove the `DEFAULT_RECOMMENDERS` export entirely.

### `frontend/src/hooks/usePeople.ts`
- Remove `DEFAULT_RECOMMENDERS` import (line 8)
- Remove `mergeWithDefaults()` function (lines 10–25)
- Remove missing-defaults auto-creation logic (lines 37–51)
- Simplify `loadPeople()` to just `setPeople(serverPeople)` after fetching
- Remove `isDefault` param from `addPerson()`

### `frontend/src/components/features/AddMovie/AddMovieContainer.tsx`
- Remove `DEFAULT_RECOMMENDERS` import (line 10)
- Simplify `allRecommenders` memo (lines 37–66): remove the DEFAULT_RECOMMENDERS loop; just register `userPeople` directly, mapping `isDefault: !!person.quick_key`

### `frontend/src/components/features/People/PeopleManagerContainer.tsx`
- Remove `DEFAULT_RECOMMENDERS` import (line 19)
- Remove the computed `isDefault` line (line 58); replace with `isDefault: !!person.quick_key`
- Filter logic (lines 75–76) and search (line 87) already use `isDefault` — no changes needed there

### `frontend/src/components/features/AddMovie/RecommenderStep.tsx`
No changes needed — already uses `option.isDefault`.

### `frontend/src/services/api.ts`
No changes needed for core calls. Optionally: remove `isDefault` from `addPerson()` body since the backend now ignores it for normal users.

---

## Step 8 — Mobile: Data Model

### `mobile/Sources/Services/MovieRepository.swift`

Update `Person` struct (lines 234–268):
```swift
struct Person: Identifiable, Hashable, Codable {
    let personId: Int?
    let name: String
    let isTrusted: Bool
    let movieCount: Int
    let color: String?      // add
    let emoji: String?      // add
    let quickKey: String?   // add

    enum CodingKeys: String, CodingKey {
        case personId = "id"
        case name
        case isTrusted = "is_trusted"
        case movieCount = "movie_count"
        case color
        case emoji
        case quickKey = "quick_key"
    }
}

extension Person {
    var isQuick: Bool { quickKey != nil }
}
```

### `mobile/Sources/Services/DatabaseManager.swift`

Update `CachedPerson` struct (lines 193–220):
```swift
let quickKey: String?   // add
let color: String?      // add (also missing currently)
let emoji: String?      // add (also missing currently)

// CodingKeys: add case quickKey = "quick_key", color, emoji
// toPerson(): pass through quickKey, color, emoji
```

Add new migration (after existing v2):
```swift
migrator.registerMigration("v3_people_quick_key_color_emoji") { db in
    let cols = try db.columns(in: "people").map(\.name)
    if !cols.contains("quick_key") {
        try db.alter(table: "people") { t in t.add(column: "quick_key", .text) }
    }
    if !cols.contains("color") {
        try db.alter(table: "people") { t in t.add(column: "color", .text) }
    }
    if !cols.contains("emoji") {
        try db.alter(table: "people") { t in t.add(column: "emoji", .text) }
    }
}
```

---

## Step 9 — Mobile: People Page

### `mobile/Sources/Views/Tabs/PeoplePageView.swift`

1. **`TrustedFilter` enum** (lines 8–11): Add `.quick` case.

2. **`filteredPeople`** (lines 29–42): Add case:
   ```swift
   case .quick: return people.filter { $0.isQuick }
   ```

3. **`PeopleFilterSortSheet`** (lines 212–266): Add "Quick" picker option with count (similar to Trusted).

4. **`PersonRow`** (lines 270–298): Add quick badge alongside trusted badge:
   ```swift
   if person.isQuick {
       Image(systemName: "bolt.fill")
           .foregroundColor(.purple)
           .font(.caption)
   }
   ```

---

## Step 10 — Mobile: Add Movie Recommender Picker

### `mobile/Sources/Views/AddMoviePageView.swift`

In the `AddMovieSheet` recommender list (lines 1603–1623):

1. Split `people` into two sections: `quickPeople = people.filter { $0.isQuick }` and `regularPeople = people.filter { !$0.isQuick }`.

2. Render "Quick" section first with a section header, then "People" section.

3. Quick recommender rows show a purple bolt badge (similar to web's purple "Quick" pill).

The selection logic (toggle Set<String>) is unchanged.

---

## Critical Files Summary

| File                                                                 | Change                                     |
| -------------------------------------------------------------------- | ------------------------------------------ |
| `backend/models.py`                                                  | Add `quick_key` column                     |
| `backend/alembic/versions/<new>.py`                                  | Migration + backfill                       |
| `backend/app/schemas/people.py`                                      | Add `quick_key` to response/create schemas |
| `backend/app/api/routers/people.py`                                  | Pass through quick_key, guard DELETE       |
| `backend/auth.py`                                                    | Add seeding helper, call on create_user    |
| `backend/app/api/routers/sync.py`                                    | Add quick_key to payload/actions           |
| `frontend/src/utils/constants.ts`                                    | Remove DEFAULT_RECOMMENDERS                |
| `frontend/src/hooks/usePeople.ts`                                    | Remove merge/auto-create logic             |
| `frontend/src/components/features/AddMovie/AddMovieContainer.tsx`    | Remove defaults merge                      |
| `frontend/src/components/features/People/PeopleManagerContainer.tsx` | Use quick_key not name-match               |
| `mobile/.../MovieRepository.swift`                             | Add quickKey/color/emoji to Person struct  |
| `mobile/.../DatabaseManager.swift`                             | Add v3 migration + fields to CachedPerson  |
| `mobile/.../PeoplePageView.swift`                              | Add Quick filter tab + badge               |
| `mobile/.../AddMoviePageView.swift`                            | Add Quick section + badges in picker       |

---

## Verification

1. **Create a new user** → verify 4 Person rows exist with correct quick_keys via `GET /api/people`
2. **GET /people response** → confirm `quick_key` field appears on 4 records, `null` on others
3. **Attempt DELETE on a quick recommender** → confirm 400 error
4. **Rename a quick recommender** (PUT /people/{name} with new name) → confirm quick_key preserved
5. **Frontend**: open People tab → "Quick Recommends" filter shows 4 items, no duplicates
6. **Frontend**: open Add Movie → recommender step shows 4 items with purple "Quick" badge
7. **Mobile**: People tab → Quick filter shows 4 with bolt icon
8. **Mobile**: Add Movie → recommender picker shows Quick section at top
9. **Sync**: verify quick_key flows through offline ops correctly
10. **Existing users**: run migration → confirm backfill set quick_key on pre-existing matching rows
