# Movie Manager Mobile

React Native app built with Expo.

## Development flow

1. Develop on Linux using Expo + hot refresh.
2. Test on iPhone in Expo Go.
3. Push to `main`.
4. GitHub Actions builds unsigned `.ipa`.
5. Install through SideStore / LiveContainer.

## Local setup

### Prerequisites

- Node.js 22+
- iPhone with Expo Go

### Install

```bash
cd mobile
npm install
cp .env.example .env
```

Set `mobile/.env`:

```env
EXPO_PUBLIC_API_URL=http://YOUR_LOCAL_IP:8000/api
```

Start dev server:

```bash
npx expo start
```

Open in Expo Go by scanning the QR code.

## CI iOS build (unsigned IPA)

Workflow: `.github/workflows/build-ios-simple.yml`

### Required GitHub repo setting

Set one repository variable or secret:

- `EXPO_PUBLIC_API_URL` (production API URL)

### Output

- Artifact: `ios-unsigned-ipa`
- Rolling release: `ios-latest` with `MovieManager-unsigned.ipa`

## Install on phone

1. In GitHub mobile app, open repo Releases.
2. Open `ios-latest`.
3. Download `MovieManager-unsigned.ipa`.
4. Import into SideStore or LiveContainer.
5. Optional: create iOS Shortcuts with custom icons to launch each LiveContainer app entry.

## Notes

- The IPA is unsigned by design.
- SideStore/LiveContainer re-signs before install.
- If API URL is wrong in CI builds, update repo `EXPO_PUBLIC_API_URL` and rebuild.
- A separate native Swift test app pipeline exists at `.github/workflows/build-ios-swift-test.yml`.
