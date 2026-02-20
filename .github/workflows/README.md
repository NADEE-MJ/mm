# iOS Build Workflow

This repo has one iOS workflow:

- `.github/workflows/build-mobile.yml` — builds the native Swift iOS app from `mobile/`

## build-mobile.yml

1. Generates the Xcode project via XcodeGen (`mobile/project.yml`).
2. Builds an unsigned `.ipa` using `xcodebuild`.
3. Uploads the file as `mobile-unsigned-ipa` artifact (30-day retention).
4. Updates a rolling GitHub release: `mobile-latest` (on push to main or manual dispatch).

### Triggers

- Push to `main` when `mobile/` changes
- Pull request targeting `main` when `mobile/` changes
- Manual run via **Actions > Build Mobile Swift App (Unsigned) > Run workflow**

### Required secret

Set one repository secret:

- `MOBILE_API_BASE_URL`

Example value:

- `https://api.moviemanager.com/api`

The workflow validates the secret is set and injects it into `Config/Env.generated.xcconfig` before building.

### Download from phone

On GitHub mobile app:

1. Open repo **Releases**.
2. Open release tag `mobile-latest`.
3. Download `MobileSwift-unsigned.ipa`.

Then import into SideStore/LiveContainer as needed.
