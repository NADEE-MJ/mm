# iOS Build and Distribution

The native iOS app is built as an unsigned IPA via GitHub Actions.

## Workflow

- File: `.github/workflows/build-mobile.yml`
- Workflow name in Actions UI: `Build iOS App`

### Triggers

| Trigger | Condition |
|---|---|
| Push to `main` | when `mobile/**` or workflow file changes |
| Pull request to `main` | when `mobile/**` or workflow file changes |
| Manual dispatch | Run from Actions UI |

### Manual dispatch inputs

- `runner_image` (macOS image)
- `deployment_target` (iOS deployment target)
- `publish_release` (`true`/`false`)
- `artifact_suffix` (optional IPA filename suffix)

## Build Outputs

- Artifact: `mobile-unsigned-ipa` (30-day retention)
- Release tag (main/manual publish): `mobile-v{MARKETING_VERSION}`
- IPA filename:
  - PR builds: `mm-vX_Y-pr<PR_NUMBER>.ipa`
  - Main/manual builds: `mm-vX_Y.ipa` or `mm-vX_Y-<suffix>.ipa`

## Required Secret

Set in repository Actions secrets:

| Secret | Required | Example |
|---|---|---|
| `MOBILE_API_BASE_URL` | Yes | `https://api.example.com/api` |

Validation rules in workflow:
- Must be set
- Must use HTTPS
- Must be a base host URL or end in `/api`

## Build Pipeline Summary

1. Generate `Config/Env.generated.xcconfig` from `MOBILE_API_BASE_URL`
2. Run `xcodegen generate`
3. Resolve SPM packages
4. Build unsigned app with `xcodebuild` (no signing)
5. Package IPA
6. Upload artifact
7. Publish/update `mobile-v{MARKETING_VERSION}` release (when enabled)

## Downloading IPA

### Releases

1. Open repository Releases
2. Open latest `mobile-v*` tag
3. Download `mm-v*.ipa`

### Actions artifact

1. Open a successful `Build iOS App` run
2. Download `mobile-unsigned-ipa`

## Install Options

- SideStore
- LiveContainer

Use your normal sideload workflow for unsigned IPAs.

## Troubleshooting

### `MOBILE_API_BASE_URL is not set`

Add the secret under repository Actions secrets.

### Release was not published

Check:
- branch is `main`
- trigger is push or manual dispatch with `publish_release=true`

### IPA missing from release

Open the workflow run and inspect the `Publish versioned IPA release` step.

## Related Docs

- [Mobile Architecture](../architecture/mobile.md)
- [Local Development](local-development.md)
- [Environment Variables](../reference/environment-variables.md)
