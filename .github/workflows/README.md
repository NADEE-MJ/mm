# iOS Build Workflow

This repo uses iOS workflows:

- `.github/workflows/build-mobile-swift.yml` (main Mobile Swift app)
- `.github/workflows/build-ios-simple.yml` (Expo app)

## Expo workflow

1. Builds the Expo app on GitHub macOS runners.
2. Produces an unsigned `.ipa`.
3. Uploads the file as `ios-unsigned-ipa` artifact.
4. Updates a rolling GitHub release: `ios-latest`.

Trigger:

- Push to `main`
- Manual run via **Actions > Build iOS (Unsigned for Sideloading) > Run workflow**

Required repo setting:

Set one repository variable or secret:

- `EXPO_PUBLIC_API_URL`

Example value:

- `https://api.moviemanager.com/api`

The workflow writes this into `mobile/.env` during CI so the bundled app points at the correct backend.

Download from phone:

On GitHub mobile app:

1. Open repo **Releases**.
2. Open release tag `ios-latest`.
3. Download `MovieManager-unsigned.ipa`.

Then import into SideStore/LiveContainer as needed.
