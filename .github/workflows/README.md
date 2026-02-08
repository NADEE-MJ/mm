# iOS Build Workflow

This repo uses two iOS workflows:

- `.github/workflows/build-ios-simple.yml` (Expo app)
- `.github/workflows/build-ios-swift-test.yml` (standalone Swift test app)

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

## Swift test workflow

1. Generates an Xcode project from `ios-test-swift/project.yml`.
2. Builds a native SwiftUI test app with signing disabled.
3. Uploads `ios-swift-test-unsigned-ipa` artifact.
4. Updates rolling release tag `ios-swift-test-latest` when run from `main` and `publish_release=true`.

Trigger:

- Manual run via **Actions > Build iOS Swift Test App (Unsigned) > Run workflow**
- Optional input `publish_release` to skip rolling release updates for a specific run.
- Optional input `artifact_suffix` to customize the IPA filename.

Download from phone:

1. Open repo **Releases**.
2. Open release tag `ios-swift-test-latest`.
3. Download `SwiftTestApp-unsigned.ipa` (or suffixed variant if set via workflow input).
