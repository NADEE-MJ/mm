# iOS Build Guide

This guide covers the workflow to create unsigned iOS IPAs:

- `.github/workflows/build-ios-simple.yml`

## Pipeline

1. Expo prebuild generates iOS native project.
2. `xcodebuild` compiles Release app with signing disabled.
3. Workflow packages `.app` into `.ipa`.
4. IPA is published to:
   - Actions artifact: `ios-unsigned-ipa`
   - Rolling release tag: `ios-latest`

## Required GitHub setting

Set repository variable or secret:

- `EXPO_PUBLIC_API_URL`

Example:

- `https://api.moviemanager.com/api`

CI writes this value into `mobile/.env` before bundling JavaScript.

## Trigger build

- Push to `main`, or
- Run workflow manually from Actions tab.

## Download from phone

1. Open GitHub app.
2. Go to repository Releases.
3. Open `ios-latest` for Expo app builds.
4. Download `MovieManager-unsigned.ipa`.

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
