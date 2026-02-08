# iOS Build Guide

This project uses two workflows to create unsigned iOS IPAs:

- `.github/workflows/build-ios-simple.yml`
- `.github/workflows/build-ios-swift-test.yml`

## Pipeline

1. Expo prebuild generates iOS native project.
2. `xcodebuild` compiles Release app with signing disabled.
3. Workflow packages `.app` into `.ipa`.
4. IPA is published to:
   - Actions artifact: `ios-unsigned-ipa`
   - Rolling release tag: `ios-latest`

## Swift Test App Pipeline

1. XcodeGen generates an Xcode project from `ios-test-swift/project.yml`.
2. `xcodebuild` compiles the native SwiftUI test app with signing disabled.
3. Workflow packages `.app` into `.ipa`.
4. IPA is published to:
   - Actions artifact: `ios-swift-test-unsigned-ipa`
   - Rolling release tag: `ios-swift-test-latest` (when run from `main` with `publish_release=true`)

## Required GitHub setting

Set repository variable or secret:

- `EXPO_PUBLIC_API_URL`

Example:

- `https://api.moviemanager.com/api`

CI writes this value into `mobile/.env` before bundling JavaScript.

## Trigger build

- Push to `main`, or
- Run workflow manually from Actions tab.

For the Swift test app workflow, run it manually from the Actions tab.
Optional manual inputs for Swift test workflow:
- `runner_image` to choose runner (`macos-latest` default, `macos-15` fallback, `macos-26` if available).
- `deployment_target` to override iOS deployment target used at build time (default `17.0`).
- `publish_release` (default `true`) to control whether `ios-swift-test-latest` is updated.
- `artifact_suffix` to append a custom suffix to the IPA filename.

## Download from phone

1. Open GitHub app.
2. Go to repository Releases.
3. Open `ios-latest` for Expo app builds, or `ios-swift-test-latest` for the native Swift test app.
4. Download `MovieManager-unsigned.ipa` or `SwiftTestApp-unsigned.ipa`.

## Install strategy

- Import IPA into SideStore or LiveContainer.
- For multiple app entries, use LiveContainer + iOS Shortcuts with custom icons.

## Troubleshooting

### Build fails with missing env

`EXPO_PUBLIC_API_URL` is not configured in repo variables/secrets.

### Build succeeds but app points to wrong backend

Update repo `EXPO_PUBLIC_API_URL` and rebuild; value is baked into bundle at build time.

### No IPA in release

Check workflow run logs in `Publish latest IPA release` step.
