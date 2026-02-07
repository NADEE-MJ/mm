# iOS Build Guide - Unsigned Builds for Sideloading

## Overview

This project now uses a **simplified unsigned build approach** for iOS that **does not require a paid Apple Developer account**. The GitHub Actions workflow builds an unsigned `.ipa` file that can be re-signed and installed on your device using **SideStore** or **AltStore**.

## 🎯 Why This Approach?

### Before (Old Approach)
- ❌ Required Apple ID, app-specific password, and Team ID
- ❌ Complex keychain management in CI
- ❌ 7-day expiry on free Apple ID signatures
- ❌ Fragile authentication with 2FA in CI
- ❌ The signature gets stripped and replaced by SideStore anyway

### Now (New Approach)
- ✅ **No Apple credentials needed in GitHub Actions**
- ✅ **No code signing complexity**
- ✅ **No keychain management**
- ✅ **Simpler, more reliable builds**
- ✅ **Perfect for SideStore/AltStore** (they re-sign from scratch anyway)

## 🚀 How It Works

```
┌─────────────────────────────────────────────────┐
│  GitHub Actions (macOS runner)                  │
│                                                 │
│  1. expo prebuild --platform ios                │
│  2. Patch Xcode project (disable signing)       │
│  3. xcodebuild build (CODE_SIGNING_ALLOWED=NO)  │
│  4. Package .app → Payload/ → .ipa              │
│  5. Upload .ipa as artifact                     │
└──────────────────┬──────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────┐
│  Your iOS Device                                │
│                                                 │
│  1. Download .ipa from GitHub Actions           │
│  2. Import into SideStore / AltStore            │
│  3. Tool re-signs with your free Apple ID       │
│  4. Install and run on device                   │
└─────────────────────────────────────────────────┘
```

### Key Insight

**SideStore and AltStore completely replace the code signature** on any `.ipa` file. They don't care whether the input was signed, unsigned, or signed by someone else — they strip everything and re-sign from scratch with your free Apple ID.

This means building unsigned is **optimal**: no credentials to manage, no complexity, no fragility.

## 📋 How to Use

### 1. Trigger a Build

You can trigger a build in three ways:

**A. Automatic on Push to `main`**
```bash
git push origin main
```

**B. Manual Trigger**
1. Go to **Actions** tab in GitHub
2. Click **Build iOS (Unsigned for Sideloading)**
3. Click **Run workflow**

**C. Comment on a Pull Request**
Comment `build ios` on any PR, and the workflow will build that PR's code.

### 2. Download the .ipa

1. Go to the **Actions** tab
2. Click on the workflow run
3. Scroll to **Artifacts**
4. Download `ios-unsigned-ipa`
5. Extract the `.ipa` file from the zip

### 3. Install on Your Device

#### Using SideStore (Recommended)
1. Install [SideStore](https://sidestore.io/) on your device
2. Transfer the `.ipa` to your device (AirDrop, iCloud, etc.)
3. Open the `.ipa` in SideStore
4. SideStore will re-sign with your free Apple ID and install

#### Using AltStore
1. Install [AltStore](https://altstore.io/) on your device
2. Connect your device to your computer
3. Open AltStore on your device
4. Tap the **+** button and select the `.ipa`
5. AltStore will re-sign and install

### 4. Trust the Certificate
1. Go to **Settings → General → VPN & Device Management**
2. Trust the developer certificate
3. Launch the app!

## ⏰ Important Notes

- **7-Day Expiry**: Apps signed with a free Apple ID expire after 7 days
- **Re-signing**: After 7 days, re-download the `.ipa` and re-sign it with SideStore/AltStore
- **Or**: Trigger a new build and install the fresh `.ipa`

## 🔧 Technical Details

### Auto-Detection of Scheme Name

The workflow **automatically detects** your app's scheme name during the build process:

1. After `expo prebuild` generates the iOS project, the workflow scans for the `.xcworkspace`
2. It lists all available schemes using `xcodebuild -workspace -list`
3. It filters out Pods-related schemes (which start with `Pods-`)
4. It selects the first non-Pods scheme (your app's scheme)

**No manual configuration needed!** The scheme name is dynamically detected for every build.

Example output:
```
Available schemes:
    moviemanager
    Pods-moviemanager

Selected scheme: moviemanager
```

### Xcode Build Settings Used

These flags disable code signing entirely:

```bash
CODE_SIGNING_ALLOWED=NO           # Master switch: don't attempt any signing
CODE_SIGNING_REQUIRED=NO          # Don't require a valid signature
CODE_SIGN_IDENTITY=""             # No signing identity
CODE_SIGN_ENTITLEMENTS=""         # No entitlements file
PROVISIONING_PROFILE_SPECIFIER="" # No provisioning profile
DEVELOPMENT_TEAM=""               # No team ID
AD_HOC_CODE_SIGNING_ALLOWED=YES   # Allow .app without proper signing
```

### .ipa File Structure

An `.ipa` is simply a zip archive:

```
MovieManager-unsigned.ipa (zip)
└── Payload/
    └── moviemanager.app/
        ├── Info.plist
        ├── moviemanager (binary)
        ├── Assets.car
        ├── Base.lproj/
        └── Frameworks/
            └── ...
```

### Build Process

1. **Expo Prebuild**: Generates the native iOS project from your Expo config
2. **Patch Project**: Ruby script modifies `.xcodeproj` to disable signing
3. **Build**: `xcodebuild build` creates the `.app` without signing
4. **Package**: Copy `.app` into `Payload/` and zip as `.ipa`
5. **Upload**: Artifact available for download

## 🆚 Comparison with Other Approaches

| Approach | CI Complexity | Credentials Needed | Re-signing Compatible | Recommendation |
|----------|---------------|-------------------|---------------------|----------------|
| **Unsigned build** | ✅ Low | ✅ None | ✅ Perfect | **← Current** |
| Free Apple ID in CI | ❌ High | ❌ Apple ID + 2FA | ✅ Yes (redundant) | Not recommended |
| Fake credentials | ⚠️ Medium | ⚠️ Self-signed cert | ✅ Yes (redundant) | Not recommended |

## 🐛 Troubleshooting

### Build fails with "Signing requires a development team"

The signing patch didn't apply. Check that:
- Expo prebuild completed successfully
- The Ruby script ran without errors
- You're using the correct Xcode version

### "No .app found after build"

- Verify the scheme name matches (check build logs)
- Ensure `expo prebuild` generated the iOS project
- Look at the build log for xcodebuild errors

### SideStore/AltStore won't install the .ipa

- Ensure the build was for `generic/platform=iOS` (arm64), not simulator
- Check that `Info.plist` has a valid `CFBundleIdentifier`
- Verify you're using the latest version of SideStore/AltStore

### GitHub Actions runner doesn't have Xcode 26

- Check [runner images documentation](https://github.com/actions/runner-images)
- Update `XCODE_VERSION` in the workflow to match available versions
- Or use `macos-latest` if Xcode 26 is now standard

## 🔒 Security Considerations

- **Unsigned .ipa files contain your compiled app code** without identity verification
- Don't distribute unsigned `.ipa` files publicly if they contain secrets
- Environment variables/API keys baked into the build will be in the binary
- Use runtime configuration or secure storage for sensitive values
- This approach is **perfect for personal use** and testing

## 📚 Additional Resources

- [SideStore Documentation](https://sidestore.io/docs)
- [AltStore Documentation](https://faq.altstore.io/)
- [Apple's Code Signing Guide](https://developer.apple.com/library/archive/documentation/Security/Conceptual/CodeSigningGuide/Introduction/Introduction.html)
- [Expo Prebuild](https://docs.expo.dev/workflow/prebuild/)

## 🎓 What Changed from Previous Setup

### Removed
- ❌ `APPLE_ID` secret
- ❌ `APPLE_APP_PASSWORD` secret
- ❌ `APPLE_TEAM_ID` secret
- ❌ Keychain creation and management
- ❌ Fastlane installation and configuration
- ❌ `xcodebuild archive` + `exportArchive` steps
- ❌ ExportOptions.plist
- ❌ Complex authentication handling

### Added
- ✅ Ruby script to patch `.xcodeproj` (disable signing)
- ✅ Direct `xcodebuild build` (no archive step)
- ✅ Manual `.ipa` packaging from `.app`
- ✅ Clearer documentation and user guidance

### Result
- 📉 **~150 lines removed** from workflow
- 📈 **More reliable builds**
- 💰 **No paid Apple account needed**
- 🎯 **Perfect for sideloading use case**

## ❓ FAQ

**Q: Can I still use a paid Apple Developer account if I have one?**
A: This unsigned approach is specifically for users without paid accounts. If you have a paid account, consider using proper App Store or TestFlight distribution.

**Q: Will this work for App Store distribution?**
A: No, this creates unsigned builds for sideloading only. App Store requires proper signing with a paid developer account.

**Q: Can I automate the re-signing process?**
A: Yes! SideStore can auto-refresh apps in the background when connected to your WiFi network. Check SideStore documentation for setup.

**Q: Why not use EAS Build?**
A: EAS Build is great for production, but requires paid services. This approach is completely free and perfect for development/testing.

**Q: Is this approach secure?**
A: For personal development use, yes. The app code is the same as any other build. Just don't distribute unsigned IPAs publicly.

---

## 🎉 Summary

You now have a **simple, reliable, free** iOS build pipeline that:
- ✅ Requires **no paid Apple Developer account**
- ✅ Requires **no credentials in GitHub Actions**
- ✅ Produces **unsigned .ipa files** perfect for SideStore/AltStore
- ✅ **Just works** without complex signing setup

Happy building! 🚀
