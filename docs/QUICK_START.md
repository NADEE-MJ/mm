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

## 3. Download on iPhone

In GitHub app:

1. Repo → Releases
2. Open `ios-latest`
3. Download `MovieManager-unsigned.ipa`

## 4. Install

- Import into SideStore or LiveContainer.
- Optional: create Shortcuts + custom icon per LiveContainer app entry.
