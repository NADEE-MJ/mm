# iOS Build GitHub Action

This workflow builds an unsigned iOS IPA file for the React Native (Expo) mobile app.

## How to Trigger the Build

1. Go to any Pull Request in this repository
2. Add a comment with the text: **`build ios`**
3. The workflow will automatically start and add a 🚀 reaction to your comment
4. Wait for the build to complete (typically 20-30 minutes)
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

For this workflow to work, you need to set up the following:

### Required Secret

Add `EXPO_TOKEN` to your GitHub repository secrets:

1. Generate an Expo access token:
   - Go to https://expo.dev/accounts/[your-account]/settings/access-tokens
   - Click "Create token"
   - Give it a name (e.g., "GitHub Actions")
   - Copy the token

2. Add the token to GitHub:
   - Go to your repository's Settings → Secrets and variables → Actions
   - Click "New repository secret"
   - Name: `EXPO_TOKEN`
   - Value: Paste your Expo token
   - Click "Add secret"

### EAS Build Configuration

The workflow automatically creates an `eas.json` file if it doesn't exist. However, you can customize the build configuration by creating your own `eas.json` in the `mobile/` directory:

```json
{
  "cli": {
    "version": ">= 5.9.0"
  },
  "build": {
    "unsigned": {
      "ios": {
        "simulator": false,
        "buildType": "archive",
        "distribution": "internal",
        "autoIncrement": true
      }
    }
  }
}
```

## Troubleshooting

### Build fails with "EXPO_TOKEN not found"

Make sure you've added the `EXPO_TOKEN` secret to your repository settings (see Prerequisites above).

### Build times out

EAS builds can take 20-40 minutes depending on server load. The workflow has a 30-minute timeout. If builds consistently timeout, you may need to increase the `TIMEOUT` value in the workflow file.

### Download link doesn't work

GitHub artifacts are only available for 30 days. After that, you'll need to trigger a new build.

### Can't install IPA on device

The IPA is unsigned. You must sign it with your own certificate before installing. See the "Signing the IPA" section above.

## Technical Details

- **Runner**: macOS-latest (GitHub-hosted)
- **Build System**: EAS Build (Expo Application Services)
- **Build Profile**: `unsigned` (defined in workflow)
- **Distribution**: Internal (unsigned)
- **Artifact Retention**: 30 days
- **Build Timeout**: 30 minutes

## Customization

### Change the trigger phrase

Edit `.github/workflows/build-ios.yml` and change line 11:

```yaml
if: github.event.issue.pull_request && contains(github.event.comment.body, 'build ios')
```

Replace `'build ios'` with your desired trigger phrase.

### Change build configuration

Create or modify `mobile/eas.json` with your desired build settings. See [EAS Build documentation](https://docs.expo.dev/build/introduction/) for available options.

### Change artifact retention

Edit the `retention-days` in the workflow file (default: 30 days).

## Cost Considerations

- **GitHub Actions**: macOS runners consume minutes faster than Linux runners (10x multiplier on free tier)
- **EAS Build**: Free tier includes limited builds per month. See [Expo pricing](https://expo.dev/pricing) for details.

## Additional Resources

- [EAS Build Documentation](https://docs.expo.dev/build/introduction/)
- [Expo Application Services](https://expo.dev/eas)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
