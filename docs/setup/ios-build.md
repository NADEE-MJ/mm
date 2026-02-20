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

## Pipeline Configuration

Set in repository Actions settings:

| Name | Type | Required | Example |
|---|---|---|---|
| `MOBILE_API_BASE_URL` | Secret | Yes | `https://api.example.com/api` |
| `MOBILE_FILE_LOGGING_ENABLED` | Variable or Secret | No | `NO` |

Validation rules in workflow:
- Must be set
- Must use HTTPS
- Must be a base host URL or end in `/api`
- `MOBILE_FILE_LOGGING_ENABLED` must be `YES` or `NO` (case-insensitive); defaults to `NO` when omitted.

## Build Pipeline Summary

1. Generate `Config/Env.generated.xcconfig` from `MOBILE_API_BASE_URL` and optional `MOBILE_FILE_LOGGING_ENABLED`
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
