# iOS Build Workflow

This repo has one iOS workflow:

- `.github/workflows/build-mobile.yml` — builds the native Swift iOS app from `mobile/`

## build-mobile.yml

1. Generates the Xcode project via XcodeGen (`mobile/project.yml`).
2. Builds an unsigned `.ipa` using `xcodebuild`.
3. Uploads the file as `mobile-unsigned-ipa` artifact (30-day retention).
4. Publishes a versioned GitHub release: `mobile-v{MARKETING_VERSION}` (on push to main or manual dispatch). The version is read from `mobile/project.yml`. If the tag already exists (same version), the release is updated in place and the IPA is replaced.

### Triggers

- Push to `main` when `mobile/` changes
- Pull request targeting `main` when `mobile/` changes
- Manual run via **Actions > Build iOS App > Run workflow**

### Required secret

Set one repository secret:

- `MOBILE_API_BASE_URL`

Example value:

- `https://api.moviemanager.com/api`

The workflow validates the secret is set and injects it into `Config/Env.generated.xcconfig` before building.

### Optional logging flag

Set either a repository variable or secret to control file-log export in the iOS build:

- `MOBILE_FILE_LOGGING_ENABLED` (optional)

Accepted values:

- `YES`/`NO` (case-insensitive)

If omitted, it defaults to `NO`.

### Download from phone

On GitHub mobile app:

1. Open repo **Releases**.
2. Open the latest `mobile-v*` release.
3. Download `mm-v*.ipa`.

Then import into SideStore/LiveContainer as needed.
