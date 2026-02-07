# Critical Fixes Applied to iOS Build Workflow

## 🚨 Issues Fixed

### Issue #1: Wrong Scheme Selected

**Problem**:
The auto-detection logic picked `EXConstants` (an Expo dependency) instead of `MovieManager` (your actual app).

```
❌ Selected scheme: EXConstants
```

**Root Cause**:
The filter only excluded schemes starting with `Pods-`, but many React Native/Expo dependencies (like EXConstants, RCTAnimation, etc.) create their own schemes that don't follow that naming pattern.

**Fix Applied**:
1. **Match workspace name first** - If workspace is `moviemanager.xcworkspace`, prefer scheme `moviemanager` or `MovieManager`
2. **Enhanced filtering** - Exclude known dependency prefixes: `EX*`, `RCT*`, `React*`, `Pods-*`
3. **Manual override option** - You can now set `APP_SCHEME: "MovieManager"` if auto-detection fails

**New Logic**:
```bash
# 1. Check if manually specified
if APP_SCHEME is set → use it

# 2. Try to match workspace name
SCHEME = grep -i "^${WORKSPACE_NAME}$" from all schemes

# 3. Filter out known dependencies
SCHEME = exclude ^Pods-, ^EX, ^RCT, ^React, Tests$

# 4. Take first remaining scheme
```

---

### Issue #2: Xcode Version Not Available

**Problem**:
```
⚠️  Xcode 26.0 not found
```

The runner doesn't have Xcode 26.0 installed (it's a beta version).

**Fix Applied**:
The workflow now has **automatic fallback**:

```bash
if [ -d "/Applications/Xcode_26.0.app" ]; then
  # Use specified version
else
  # Find latest stable Xcode (non-beta)
  # Falls back to default Xcode.app if needed
fi
```

**Result**: The workflow will use the best available Xcode version automatically.

---

### Issue #3: iOS SDK Platform Availability

**Problem**:
```
platform iOS, id 00000000-0000000000000000, OS 26.0, name Generic iOS Device: The platform is not currently installed.
```

This error appeared because:
1. The selected scheme (EXConstants) is a static library, not an app
2. Static libraries have different destination requirements

**Fix Applied**:
1. **SDK detection** - Check what iOS SDKs are actually available
2. **Scheme fix** - Building the correct scheme (MovieManager) will resolve this
3. **Diagnostic step** - Shows available SDKs and platforms for debugging

---

## ✅ What's New in the Workflow

### 1. Manual Scheme Override

You can now manually specify the scheme if auto-detection fails:

```yaml
env:
  APP_SCHEME: "MovieManager"  # Set your scheme name here
```

Or leave it empty for auto-detection:

```yaml
env:
  APP_SCHEME: ""  # Auto-detect (default)
```

### 2. Xcode Version Fallback

The workflow automatically finds the best available Xcode:

```yaml
env:
  XCODE_VERSION: "26.0"  # Preferred version
  # Falls back to latest stable if not available
```

### 3. Enhanced Debugging

New diagnostic steps:
- **Xcode version listing** - Shows all available Xcode versions
- **SDK verification** - Lists available iOS SDKs
- **Platform check** - Verifies iOS platform is installed
- **Scheme listing** - Shows all schemes with clear annotations

### 4. Improved Scheme Detection

Smarter algorithm that:
- ✅ Matches workspace name first
- ✅ Filters out dependency schemes
- ✅ Supports manual override
- ✅ Clear error messages if detection fails

---

## 🔧 Recommended Configuration

Based on your project, here's the recommended setup:

```yaml
env:
  APP_CONFIGURATION: "Release"
  EXPO_PROJECT_DIR: "mobile"
  XCODE_VERSION: "26.0"           # Will fall back if not available
  APP_SCHEME: "moviemanager"      # Explicitly set to avoid detection issues
```

**Why set `APP_SCHEME` explicitly?**
- Faster builds (skips auto-detection)
- More reliable (no guessing)
- Clearer logs (you know exactly what's being built)

---

## 🧪 Testing the Fixes

### Step 1: Set the Scheme (Recommended)

Edit `.github/workflows/build-ios.yml`:

```yaml
env:
  # ... other settings ...
  APP_SCHEME: "moviemanager"  # ← Add this line
```

**Finding your scheme name**:
1. Run `npx expo prebuild --platform ios --clean` locally
2. Open `ios/` directory
3. Look at the `.xcworkspace` name - it's usually lowercase version of your app name
4. The scheme matches the workspace name

Or check the GitHub Actions logs from the "Debug workspace and schemes" step.

### Step 2: Push and Test

```bash
git add .github/workflows/build-ios.yml
git commit -m "Fix iOS build: set correct scheme and add fallbacks"
git push origin main
```

### Step 3: Verify the Build

Watch for these in the logs:

```
✅ Selected scheme: moviemanager    # Should be your app name, not EXConstants!
✅ Found iOS SDK: iphoneos15.5      # Any iOS SDK is fine
✅ Found .app bundle: build/Build/Products/Release-iphoneos/moviemanager.app
```

---

## 🐛 If Build Still Fails

### Check 1: Scheme Name

Look at the "Debug workspace and schemes" step output:

```
Schemes in moviemanager.xcworkspace:
    Schemes:
        moviemanager        ← This is your app scheme!
        EXConstants
        RCTAnimation
        Pods-moviemanager
```

Set `APP_SCHEME` to match exactly (case-sensitive).

### Check 2: Xcode Version

Look at the "Select Xcode" step:

```
✅ Selected Xcode:
Xcode 15.4
Build version 15F31d
```

If it's an older version without iOS 18+ support and your app.json specifies `deploymentTarget: "26.0"`, you need to either:
- Lower the deployment target in `app.json`
- Or use a newer Xcode (if available on the runner)

### Check 3: iOS SDK

Look at the "Verify iOS SDK" step:

```
-sdk iphoneos15.5    ← Should see at least one iOS SDK
```

If no iOS SDKs are listed, the runner's Xcode installation might be corrupted. Try:
- Using a different Xcode version
- Or using `macos-14` runner instead of `macos-15`

---

## 📊 Expected Build Flow

With the fixes applied, here's what you should see:

```
1. Select Xcode
   ✅ Found: Xcode 15.4

2. Verify iOS SDK
   ✅ iOS SDK is available: iphoneos15.5

3. Expo prebuild
   ✅ Native iOS project generated

4. Debug workspace and schemes
   ✅ Found scheme: moviemanager

5. Disable code signing
   ✅ Code signing disabled for all targets

6. Install CocoaPods
   ✅ Pod installation complete!

7. Build unsigned .app
   ✅ Selected scheme: moviemanager
   ✅ BUILD SUCCEEDED
   ✅ Found .app bundle: build/Build/Products/Release-iphoneos/moviemanager.app

8. Package .app into .ipa
   ✅ Created: moviemanager-unsigned.ipa (89.5M)

9. Upload artifact
   ✅ Artifact uploaded: ios-unsigned-ipa
```

---

## 🎯 Quick Fix Checklist

- [ ] Update `APP_SCHEME: "moviemanager"` in workflow (or your actual scheme name)
- [ ] Commit and push changes
- [ ] Trigger a build (push to main or manual workflow)
- [ ] Check "Debug workspace and schemes" step for correct scheme
- [ ] Verify "Build unsigned .app" builds the correct target
- [ ] Download and test the artifact

---

## 📝 Summary

### What Was Wrong

1. ❌ Auto-detection picked wrong scheme (EXConstants instead of MovieManager)
2. ❌ Xcode 26.0 not available on runner
3. ❌ No fallback mechanism

### What's Fixed

1. ✅ Smart scheme detection with manual override option
2. ✅ Automatic Xcode version fallback
3. ✅ Enhanced debugging and error messages
4. ✅ Better filtering of dependency schemes

### Recommended Action

**Set the scheme explicitly** to avoid any auto-detection issues:

```yaml
APP_SCHEME: "moviemanager"  # Use your actual app's scheme name
```

This is the most reliable approach and ensures consistent builds.

---

**Next**: See `docs/IOS_BUILD_GUIDE.md` for complete usage instructions once the build is working.
