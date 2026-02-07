# iOS Build Setup Instructions

This guide will help you set up GitHub Secrets to build iOS apps signed with your free Apple Developer account.

## Prerequisites

1. **Free Apple Developer Account**
   - Sign up at https://developer.apple.com (free)
   - No $99/year payment needed for development builds

## Required GitHub Secrets

You need to add 3 secrets to your GitHub repository:

### 1. APPLE_ID

This is your Apple ID email address (e.g., `yourname@example.com`).

**How to add:**
1. Go to GitHub: `Settings` → `Secrets and variables` → `Actions`
2. Click `New repository secret`
3. Name: `APPLE_ID`
4. Value: Your Apple ID email
5. Click `Add secret`

### 2. APPLE_APP_PASSWORD

This is an app-specific password (NOT your regular Apple ID password).

**How to create:**
1. Go to https://appleid.apple.com
2. Sign in with your Apple ID
3. Under "Sign-In and Security", click "App-Specific Passwords"
4. Click the "+" button or "Generate an app-specific password"
5. Enter a label like "GitHub Actions iOS Build"
6. Copy the generated password (format: `xxxx-xxxx-xxxx-xxxx`)

**How to add to GitHub:**
1. Go to GitHub: `Settings` → `Secrets and variables` → `Actions`
2. Click `New repository secret`
3. Name: `APPLE_APP_PASSWORD`
4. Value: Paste the app-specific password
5. Click `Add secret`

### 3. APPLE_TEAM_ID

This is your Apple Developer Team ID.

**How to find:**

**Option A - Via Apple Developer Website:**
1. Go to https://developer.apple.com/account
2. Sign in with your Apple ID
3. Look for "Team ID" in the "Membership Details" section
4. It's a 10-character code (e.g., `A1B2C3D4E5`)

**Option B - Quick Method:**
1. I'll help you find it during the first build attempt
2. The build will fail but show you your Team ID in the error message
3. Then you can add it as a secret and re-run

**How to add to GitHub:**
1. Go to GitHub: `Settings` → `Secrets and variables` → `Actions`
2. Click `New repository secret`
3. Name: `APPLE_TEAM_ID`
4. Value: Your 10-character Team ID
5. Click `Add secret`

## Summary

Once all 3 secrets are added, your secrets page should show:
- ✅ APPLE_ID
- ✅ APPLE_APP_PASSWORD
- ✅ APPLE_TEAM_ID

## Testing the Build

After adding the secrets:
1. Commit and push any change to trigger the build
2. Or manually trigger: Go to `Actions` → `Build iOS App` → `Run workflow`
3. The build will take ~10-15 minutes
4. Download the IPA from the workflow artifacts

## Installing the IPA on Your Device

**Option 1: Using Xcode (if you have access to a Mac)**
```bash
# Connect your iPhone/iPad via USB, then:
xcrun devicectl device install app --device <device-id> path/to/app.ipa
```

**Option 2: Using Apple Configurator 2 (Mac)**
1. Download from Mac App Store
2. Connect your device
3. Drag and drop the IPA onto your device

**Option 3: Using AltStore (iOS app)**
1. Install AltStore on your device
2. Use it to sideload the IPA

**Option 4: Using Xcode Devices Window**
1. Connect your device to a Mac
2. Open Xcode → Window → Devices and Simulators
3. Drag the IPA onto your device

## Important Notes

- ⏰ **Apps expire after 7 days** with a free Apple ID
- 🔄 **Rebuild weekly** to keep the app working
- 📱 **Device registration** may be required (Xcode or Apple Configurator can do this)
- 🚫 **TestFlight not available** with free account (need $99/year for that)

## Troubleshooting

### "No profiles for 'com.moviemanager.mobile' were found"
- Fastlane will automatically create the provisioning profile
- Make sure your Team ID is correct

### "Your session has expired"
- The app-specific password may be incorrect
- Try generating a new one at appleid.apple.com

### "This action could not be completed"
- Check that all 3 secrets are added correctly
- Verify your Apple ID has developer access (free signup at developer.apple.com)

## Need Help?

If you get stuck, check the workflow logs:
- Go to `Actions` → Click on the failed run → Click on `build-ios` job
- Look for error messages in the "Setup signing with Apple ID" step
