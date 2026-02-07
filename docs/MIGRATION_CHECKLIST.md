# Migration Checklist: Unsigned iOS Builds

## ✅ What's Been Done

- [x] Replaced `.github/workflows/build-ios.yml` with new unsigned build workflow
- [x] Created comprehensive documentation in `docs/IOS_BUILD_GUIDE.md`

## 📋 What You Need to Do

### 1. Remove GitHub Secrets (Optional but Recommended)

Since the new workflow doesn't use Apple credentials, you can remove these secrets:

1. Go to **Settings → Secrets and variables → Actions**
2. Delete the following secrets (if they exist):
   - `APPLE_ID`
   - `APPLE_APP_PASSWORD`
   - `APPLE_TEAM_ID`

> **Note**: These secrets won't be used anymore, but leaving them doesn't hurt either.

### 2. Test the New Workflow

**Option A: Push to main**
```bash
git add .
git commit -m "Switch to unsigned iOS build workflow"
git push origin main
```

**Option B: Manual trigger**
1. Go to **Actions** tab
2. Select **Build iOS (Unsigned for Sideloading)**
3. Click **Run workflow**
4. Watch it build! 🎉

### 3. Verify the Build

Once the workflow completes:

1. Check that it succeeded ✅
2. Download the `ios-unsigned-ipa` artifact
3. Verify the `.ipa` file is present (should be ~50-150MB depending on app size)

### 4. Test Installation

1. Transfer the `.ipa` to your iOS device
2. Open in **SideStore** or **AltStore**
3. Let it re-sign and install
4. Launch the app and verify it works!

### 5. Update Team Documentation

If you have team members, let them know:
- No more Apple credentials needed in CI
- New installation process using SideStore/AltStore
- Link them to `docs/IOS_BUILD_GUIDE.md`

## 🔍 Expected Behavior Changes

| Aspect | Old Workflow | New Workflow |
|--------|-------------|--------------|
| **Credentials needed** | Apple ID + password + Team ID | None! |
| **Build type** | Signed (development) | Unsigned |
| **IPA artifact name** | `ios-app-development` | `ios-unsigned-ipa` |
| **Installation method** | Direct install (7-day expiry) | SideStore/AltStore (re-signs on device) |
| **Build time** | ~15-20 min | ~10-15 min (faster!) |
| **Success rate** | Fragile (auth issues) | More reliable |

## 🚨 Troubleshooting First Run

### If the build fails:

**1. Check Xcode version compatibility**
```yaml
# In .github/workflows/build-ios.yml, you may need to adjust:
XCODE_VERSION: "26.0"  # Change to available version
```

To see available versions, the workflow lists them. You can also check:
- https://github.com/actions/runner-images/blob/main/images/macos/macos-15-Readme.md

**2. Check the build logs**
- Go to the failed workflow run
- Expand the **Build unsigned .app** step
- Look for errors related to:
  - Missing dependencies
  - Scheme not found
  - CocoaPods issues

**3. Verify Expo configuration**
Make sure `mobile/app.json` has:
```json
{
  "expo": {
    "ios": {
      "bundleIdentifier": "com.moviemanager.mobile",
      "supportsTablet": true
    }
  }
}
```

### Common Issues and Fixes

**"No scheme found in workspace!"**
- The Expo prebuild may have failed
- Check that `npx expo prebuild` runs successfully locally
- Verify `mobile/app.json` is valid JSON

**"No .app found after build"**
- xcodebuild failed but didn't exit with error code
- Check the full build log for signing-related errors
- Ensure the Ruby script ran successfully

**"Pod install failed"**
- CocoaPods version mismatch
- Try updating the CocoaPods installation step in the workflow
- Or specify a different version: `pod install --repo-update --verbose`

## 📊 Monitoring the New Setup

For the first few builds, monitor:

1. **Build duration**: Should be ~10-15 minutes
2. **Artifact size**: Should be reasonable (50-150MB for most React Native apps)
3. **Success rate**: Should be much higher than before (no auth issues!)

## 🎓 Understanding the Changes

### What was removed:
- Keychain creation and management (not needed without signing)
- Fastlane installation (not needed for unsigned builds)
- Apple credential authentication (no credentials = no auth!)
- `xcodebuild archive` + `exportArchive` (replaced with simple `build`)
- ExportOptions.plist (not needed for unsigned builds)

### What was added:
- Ruby script to patch Xcode project (disables signing)
- Direct `xcodebuild build` command
- Manual `.ipa` packaging from `.app`
- Better error handling and logging

### Why it's better:
- **Simpler**: Fewer steps, less complexity
- **More reliable**: No authentication, no keychain, no provisioning
- **Faster**: No archive step, no export step
- **Free**: No paid Apple Developer account needed
- **Perfect for sideloading**: SideStore/AltStore re-signs anyway

## ✨ Next Steps After Migration

1. **Update your README** to reflect the new build process
2. **Archive old documentation** about the signed build process
3. **Celebrate** 🎉 - you just simplified your iOS CI/CD!

## 🆘 Need Help?

If you run into issues:

1. Check `docs/IOS_BUILD_GUIDE.md` for detailed troubleshooting
2. Review the workflow logs in GitHub Actions
3. Compare your `app.json` with the expected format
4. Verify Expo prebuild works locally: `cd mobile && npx expo prebuild --platform ios --clean`

## 📝 Rollback Plan (Just in Case)

If you need to revert to the old setup:

```bash
# View the old workflow
git show HEAD~1:.github/workflows/build-ios.yml

# Restore it
git checkout HEAD~1 -- .github/workflows/build-ios.yml

# Commit and push
git add .github/workflows/build-ios.yml
git commit -m "Revert to signed build workflow"
git push origin main
```

## ✅ Final Checklist

Before considering the migration complete:

- [ ] New workflow runs successfully
- [ ] .ipa artifact downloads correctly
- [ ] .ipa installs on device via SideStore/AltStore
- [ ] App launches and works as expected
- [ ] Team members informed of changes (if applicable)
- [ ] Old secrets removed from GitHub (optional)
- [ ] Documentation updated (if you have project docs)

---

## 🎯 Success Criteria

The migration is successful when:

1. ✅ Workflow builds without errors
2. ✅ Artifact contains a valid `.ipa` file
3. ✅ SideStore/AltStore can re-sign and install the app
4. ✅ App runs on device as expected
5. ✅ No Apple credentials required in GitHub Actions

**Happy building!** 🚀
