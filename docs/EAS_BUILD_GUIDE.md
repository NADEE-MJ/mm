# EAS Build Guide - Simpler Alternative to Raw xcodebuild

## 🎯 Why Use EAS Build?

**EAS Build** (Expo Application Services) is Expo's official build service. It handles all the complexity of iOS builds automatically:

| Feature | Raw xcodebuild | EAS Build |
|---------|---------------|-----------|
| **Setup complexity** | High (manual patching) | ✅ Low (automatic) |
| **Build cycles** | ❌ Manual fixes needed | ✅ Handled automatically |
| **Code signing** | ❌ Manual configuration | ✅ Managed by EAS |
| **Maintenance** | High | ✅ Low |
| **Reliability** | Medium | ✅ High |
| **Expo integration** | Manual | ✅ Native |

---

## 📋 Setup Instructions

### 1. Create an Expo Account

1. Go to [expo.dev](https://expo.dev)
2. Sign up for a free account
3. Verify your email

### 2. Get an Access Token

1. Go to [expo.dev/accounts/[username]/settings/access-tokens](https://expo.dev/settings/access-tokens)
2. Click **Create Token**
3. Name it: `GitHub Actions`
4. Copy the token (you'll only see it once!)

### 3. Add Token to GitHub Secrets

1. Go to your repo: **Settings → Secrets and variables → Actions**
2. Click **New repository secret**
3. Name: `EXPO_TOKEN`
4. Value: Paste your access token
5. Click **Add secret**

### 4. Configure EAS Project

The `eas.json` file is already configured with a `preview` profile:

```json
{
  "build": {
    "preview": {
      "distribution": "internal",
      "ios": {
        "simulator": false,
        "buildConfiguration": "Release",
        "credentialsSource": "local"
      }
    }
  }
}
```

**What this means:**
- `distribution: "internal"` - For internal testing (not App Store)
- `simulator: false` - Build for real iOS devices
- `credentialsSource: "local"` - Don't use code signing (unsigned build)

---

## 🚀 How to Use

### Option 1: Push to Main (Automatic)

```bash
git push origin main
# Workflow triggers automatically
```

### Option 2: Manual Trigger

1. Go to **Actions** tab
2. Select **Build iOS (EAS Local)**
3. Click **Run workflow**

### Option 3: PR Comment

Comment `build ios` on any pull request.

---

## 📥 Installing the IPA

1. **Download** the `ios-ipa-eas` artifact from the workflow run
2. **Extract** the `app.ipa` file
3. **Transfer** to your iOS device
4. **Open** in SideStore or AltStore
5. **Install** (auto-signs with your free Apple ID)

---

## 🆚 Comparison with Raw xcodebuild Workflow

### EAS Build Workflow (`.github/workflows/build-ios-eas.yml`)

**Pros:**
- ✅ **Simple** - No manual patching needed
- ✅ **Reliable** - Expo handles all edge cases
- ✅ **Maintained** - Expo team maintains the build process
- ✅ **Fast setup** - Just add EXPO_TOKEN secret
- ✅ **Official** - Recommended by Expo

**Cons:**
- ⚠️ Requires Expo account (free)
- ⚠️ Requires EXPO_TOKEN secret
- ⚠️ Less control over build process

### Raw xcodebuild Workflow (`.github/workflows/build-ios.yml`)

**Pros:**
- ✅ **No external dependencies** - Pure GitHub Actions
- ✅ **Full control** - Can customize every step
- ✅ **Learning** - Understand iOS build process

**Cons:**
- ❌ **Complex** - Manual patching for build cycles
- ❌ **Fragile** - Breaks with Expo/Xcode updates
- ❌ **High maintenance** - Need to fix issues manually

---

## 💡 Recommendation

### Use EAS Build if:
- ✅ You want simplicity and reliability
- ✅ You're okay creating an Expo account
- ✅ You trust Expo's build infrastructure
- ✅ You want Expo's official build process

### Use Raw xcodebuild if:
- ✅ You can't use external services
- ✅ You want complete control
- ✅ You enjoy troubleshooting build issues
- ✅ You have specific customization needs

**For most users**: **Use EAS Build** - it's simpler, more reliable, and officially supported.

---

## 🔧 How EAS Build Works

### Local Build Process

```
GitHub Actions Runner
    ↓
1. Install EAS CLI
    ↓
2. Authenticate with EXPO_TOKEN
    ↓
3. Run `eas build --local`
    ↓
4. EAS automatically:
   - Runs expo prebuild
   - Configures Xcode project
   - Fixes build cycles
   - Builds with xcodebuild
   - Packages .ipa
    ↓
5. Upload .ipa as artifact
```

### What `--local` Means

- **Local**: Build runs on your GitHub Actions runner (not Expo's servers)
- **Free**: No build credits needed (Expo's cloud builds require paid plan)
- **Fast**: No queue time waiting for Expo's servers
- **Private**: Your code never leaves your GitHub runner

---

## 📊 Build Profiles Explained

### Development
```json
"development": {
  "developmentClient": true,
  "distribution": "internal"
}
```
- For development with Expo Go
- Includes dev client
- Not suitable for sideloading

### Preview (Used by workflow)
```json
"preview": {
  "distribution": "internal",
  "ios": {
    "simulator": false,
    "buildConfiguration": "Release",
    "credentialsSource": "local"
  }
}
```
- ✅ **Perfect for sideloading**
- Release build (optimized)
- No code signing (unsigned)
- Real device (.ipa, not simulator)

### Production
```json
"production": {
  "autoIncrement": true
}
```
- For App Store submission
- Requires paid Apple Developer account
- Proper code signing

---

## 🐛 Troubleshooting

### Error: "EXPO_TOKEN is not set"

**Solution**: Add the secret in GitHub Settings → Secrets → Actions

### Error: "You need to log in to use EAS Build"

**Solution**: Make sure EXPO_TOKEN is valid. Get a new one from [expo.dev/settings/access-tokens](https://expo.dev/settings/access-tokens)

### Error: "Build failed during native build"

**Solution**: Check the workflow logs. EAS provides detailed error messages.

### Build succeeds but .ipa is missing

**Solution**: Check the `--output` path in the workflow. Make sure it's `../app.ipa` (relative to mobile/)

---

## 🔄 Switching Between Workflows

### To use EAS Build workflow:

```bash
# Commit the EAS workflow
git add .github/workflows/build-ios-eas.yml mobile/eas.json
git commit -m "Add EAS Build workflow"
git push origin main
```

### To use raw xcodebuild workflow:

The original workflow (`.github/workflows/build-ios.yml`) will still be there. Both can coexist!

### To disable one:

Rename the file to disable it:
```bash
# Disable EAS workflow
mv .github/workflows/build-ios-eas.yml .github/workflows/build-ios-eas.yml.disabled

# Or disable raw xcodebuild workflow
mv .github/workflows/build-ios.yml .github/workflows/build-ios.yml.disabled
```

---

## 📝 Summary

| Aspect | EAS Build | Raw xcodebuild |
|--------|-----------|----------------|
| **Setup** | 5 minutes | 30+ minutes |
| **Complexity** | Low | High |
| **Reliability** | Very High | Medium |
| **Maintenance** | Low | High |
| **Prerequisites** | Expo account | None |
| **Learning curve** | Low | High |
| **Build time** | ~10-15 min | ~10-15 min |

**Bottom line**: If you're using Expo, EAS Build is the recommended approach! 🎯

---

## 🎓 Additional Resources

- [EAS Build Documentation](https://docs.expo.dev/build/introduction/)
- [EAS Build with GitHub Actions](https://docs.expo.dev/build/building-on-ci/)
- [eas.json Configuration](https://docs.expo.dev/build/eas-json/)
- [Access Tokens](https://docs.expo.dev/accounts/programmatic-access/)

---

**Ready to try it?** Just add your `EXPO_TOKEN` secret and push! 🚀
