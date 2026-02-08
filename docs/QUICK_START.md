# Quick Start (Mobile + iOS Build)

## 1. Local development (Linux + iPhone)

```bash
cd mobile
npm install
cp .env.example .env
```

Set:

```env
EXPO_PUBLIC_API_URL=http://YOUR_LOCAL_IP:8000/api
```

Run:

```bash
npx expo start
```

Open in Expo Go.

## 2. CI unsigned iOS build

Set GitHub repository variable or secret:

- `EXPO_PUBLIC_API_URL=https://api.moviemanager.com/api`

Then push to `main`.

For the standalone native Swift test app pipeline, run:

- **Actions > Build iOS Swift Test App (Unsigned) > Run workflow**
- Optional: choose `runner_image=macos-latest` (or `macos-15` fallback, `macos-26` if available).
- Optional: set `deployment_target` (default `26.0`).
- Optional: set `publish_release=false` to skip updating `ios-swift-test-latest`.
- Optional: set `artifact_suffix` to customize the IPA filename.

## 3. Download on iPhone

In GitHub app:

1. Repo → Releases
2. Open `ios-latest` (Expo app) or `ios-swift-test-latest` (Swift test app)
3. Download `MovieManager-unsigned.ipa` or `SwiftTestApp-unsigned.ipa`

## 4. Install

- Import into SideStore or LiveContainer.
- Optional: create Shortcuts + custom icon per LiveContainer app entry.
