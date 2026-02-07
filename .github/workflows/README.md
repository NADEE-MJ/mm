# iOS Build GitHub Action

This workflow builds an unsigned iOS IPA file for the React Native (Expo) mobile app locally on GitHub's macOS runner.

## How to Trigger the Build

**Security Note**: Only repository maintainers or trusted contributors should trigger this action, as it checks out and builds code from the PR branch.

1. Go to any Pull Request in this repository
2. Add a comment with the text: **`build ios`**
3. The workflow will automatically start and add a 🚀 reaction to your comment
4. Wait for the build to complete (typically 10-15 minutes)
5. Once complete, the workflow will comment with a link to download the IPA

## Downloading the IPA

After the build completes successfully:

1. Click the workflow link in the comment
2. Scroll down to the **Artifacts** section at the bottom of the workflow run page
3. Download the `ios-app-unsigned` artifact (zip file)
4. Extract the zip file to get the `app.ipa` file

## Signing the IPA

The IPA is unsigned, so you'll need to sign it yourself before installing on a device:

### Option 1: Using Xcode

1. Open the IPA in Xcode
2. Select your signing certificate and provisioning profile
3. Archive and export with your signing credentials

### Option 2: Using fastlane

```bash
fastlane sigh resign app.ipa --signing_identity "Your Certificate" --provisioning_profile "path/to/profile.mobileprovision"
```

### Option 3: Using iOS App Signer

Download [iOS App Signer](https://github.com/DanTheMan827/ios-app-signer) and follow the GUI to sign the IPA.

## Prerequisites

**No tokens or secrets required!** This workflow builds the app locally on GitHub's macOS runner using:
- `expo prebuild` to generate the native iOS project
- `xcodebuild` to compile the app without code signing
- Standard Xcode command-line tools (pre-installed on macOS runners)

The Expo app configuration (app.json) already contains all necessary build settings.

## How It Works

1. **Expo Prebuild**: Generates the native iOS project from your Expo app
2. **CocoaPods**: Installs native iOS dependencies
3. **Xcodebuild**: Compiles the app with code signing disabled
4. **Archive**: Creates an unsigned .xcarchive
5. **IPA Creation**: Packages the app bundle into an IPA file
6. **Upload**: Makes the IPA available as a GitHub Actions artifact

## Troubleshooting

### Build fails during prebuild

Check that your `app.json` has valid iOS configuration (bundle identifier, permissions, etc.).

### Build fails during pod install

This usually means there's an issue with native dependencies. Check the workflow logs for specific errors.

### Build times out

Local builds typically take 10-15 minutes. If builds consistently timeout, check for issues in the native dependencies or Xcode configuration.

### Download link doesn't work

GitHub artifacts are only available for 30 days. After that, you'll need to trigger a new build.

### Can't install IPA on device

The IPA is unsigned. You must sign it with your own certificate before installing. See the "Signing the IPA" section above.

## Technical Details

- **Runner**: macOS-latest (GitHub-hosted)
- **Build System**: Expo Prebuild + Xcodebuild (local build, no cloud services)
- **Build Type**: Release configuration, unsigned
- **Artifact Retention**: 30 days
- **No tokens required**: Builds entirely on GitHub's infrastructure

## Customization

### Restrict to maintainers only (Recommended)

For additional security, you can restrict the workflow to only run when triggered by repository owners or members. 

Edit `.github/workflows/build-ios.yml` and change line 11:

```yaml
if: github.event.issue.pull_request && contains(github.event.comment.body, 'build ios') && (github.event.comment.author_association == 'OWNER' || github.event.comment.author_association == 'MEMBER')
```

This ensures only repository owners and members can trigger builds.

### Change the trigger phrase

Edit `.github/workflows/build-ios.yml` and change line 11:

```yaml
if: github.event.issue.pull_request && contains(github.event.comment.body, 'build ios')
```

Replace `'build ios'` with your desired trigger phrase.

### Change artifact retention

Edit the `retention-days` in the workflow file (default: 30 days).

### Customize build configuration

Edit `mobile/app.json` to change iOS-specific settings like:
- Bundle identifier
- App name
- Icons and splash screens
- Permissions (Info.plist)
- Plugins and native modules

## Advantages of Local Build vs EAS Build

**Local Build (This Workflow)**:
- ✅ No tokens or external services required
- ✅ Free (uses GitHub Actions minutes)
- ✅ Faster (10-15 minutes vs 20-40 minutes)
- ✅ Full control over build process
- ✅ Works offline/on-premise

**EAS Build** (Previous Approach):
- ❌ Requires EXPO_TOKEN
- ❌ Requires Expo account
- ❌ Limited free builds per month
- ❌ Depends on external service availability
- ✅ Handles complex native dependencies automatically
- ✅ Provides cloud build logs and management

## Cost Considerations

- **GitHub Actions**: macOS runners consume minutes faster than Linux runners (10x multiplier on free tier)
- **No EAS costs**: Since we're not using EAS Build, there are no Expo subscription costs

## Additional Resources

- [Expo Prebuild Documentation](https://docs.expo.dev/workflow/prebuild/)
- [Xcodebuild Documentation](https://developer.apple.com/library/archive/technotes/tn2339/_index.html)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
