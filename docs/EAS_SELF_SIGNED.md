# EAS Build with Self-Signed Credentials

## 🎯 The Solution

Since **EAS Build requires code signing credentials** for device builds, we create **self-signed placeholder credentials** that EAS accepts. These credentials are then **completely replaced** by SideStore/AltStore when you install the app.

## 🔧 How It Works

### Step 1: Generate Self-Signed Certificate
```bash
openssl req -x509 -newkey rsa:2048 -keyout key.pem -out cert.pem \
  -days 365 -nodes -subj "/CN=CI Build"
```
Creates a self-signed X.509 certificate (not from Apple)

### Step 2: Convert to P12 Format
```bash
openssl pkcs12 -export -out dist_cert.p12 \
  -inkey key.pem -in cert.pem \
  -passout pass:buildpass
```
Converts to the format Xcode/EAS expects

### Step 3: Create Minimal Provisioning Profile
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "...">
<plist version="1.0">
<dict>
    <key>TeamIdentifier</key>
    <array><string>XXXXXXXXXX</string></array>
    <key>UUID</key>
    <string>00000000-0000-0000-0000-000000000000</string>
    <!-- Minimal required fields -->
</dict>
</plist>
```

### Step 4: Sign Provisioning Profile
```bash
openssl smime -sign -in profile.plist -out profile.mobileprovision \
  -signer cert.pem -inkey key.pem -certfile cert.pem \
  -outform der -nodetach
```
Creates a `.mobileprovision` file (signed plist)

### Step 5: Create credentials.json
```json
{
  "ios": {
    "distributionCertificate": {
      "path": "dist_cert.p12",
      "password": "buildpass"
    },
    "provisioningProfilePath": "profile.mobileprovision"
  }
}
```
Tells EAS where to find the credentials

### Step 6: Build with EAS
```bash
eas build --local --platform ios --profile preview
```
EAS uses the self-signed credentials to build the .ipa

### Step 7: SideStore Re-Signs
When you install with SideStore/AltStore:
1. **Strips** the self-signed certificate
2. **Strips** the placeholder provisioning profile
3. **Re-signs** with your free Apple ID
4. **Creates** a new provisioning profile
5. **Installs** on your device

## ✅ Why This Works

**EAS Build** only checks that:
- ✅ A `.p12` certificate exists
- ✅ A `.mobileprovision` profile exists
- ✅ The files are validly formatted

**It doesn't verify** that they're from Apple!

**SideStore/AltStore** only cares about:
- ✅ The .ipa has an .app bundle inside
- ✅ The binary is arm64 (device architecture)

**It doesn't care** what signature (if any) is on the .ipa - it strips everything and re-signs.

## 🆚 Comparison

| Approach | Pros | Cons |
|----------|------|------|
| **EAS + Self-Signed** | ✅ Uses official Expo tools<br>✅ Handles Expo quirks automatically<br>✅ Simpler workflow | ⚠️ Requires Expo account<br>⚠️ Workaround (not official) |
| **Raw xcodebuild** | ✅ No external dependencies<br>✅ True unsigned build<br>✅ Full control | ⚠️ Manual fixes needed<br>⚠️ Expo build cycles |

## 📋 Setup Steps

### 1. Create Expo Account (Free)
- Go to [expo.dev](https://expo.dev)
- Sign up (takes 2 minutes)

### 2. Get Access Token
- Visit [expo.dev/settings/access-tokens](https://expo.dev/settings/access-tokens)
- Create token: "GitHub Actions"
- Copy it

### 3. Add Secret to GitHub
1. **Settings → Secrets → Actions**
2. Name: `EXPO_TOKEN`
3. Value: Paste token
4. Save

### 4. Push and Build
```bash
git add .github/workflows/build-ios-eas.yml mobile/eas.json
git commit -m "Add EAS Build with self-signed credentials"
git push origin main
```

The workflow automatically:
1. ✅ Generates self-signed credentials
2. ✅ Builds with EAS
3. ✅ Uploads unsigned .ipa

## 🎯 eas.json Configuration

```json
{
  "build": {
    "preview": {
      "distribution": "internal",
      "ios": {
        "simulator": false,           // Build for device (not simulator)
        "buildConfiguration": "Release",  // Optimized build
        "credentialsSource": "local"  // Use local credentials.json
      }
    }
  }
}
```

**Key setting**: `"credentialsSource": "local"` tells EAS to use the `credentials.json` file we create in the workflow, instead of fetching from Expo's servers.

## 🔒 Security Considerations

### Is This Safe?

**Yes!** The self-signed certificate:
- ✅ Only exists during the build (deleted after)
- ✅ Is never distributed (stays in CI)
- ✅ Is replaced by SideStore/AltStore before installation
- ✅ Can't be used to distribute malware (iOS won't trust it)

### What Could Go Wrong?

**Nothing!** The worst case:
- The .ipa is built with a self-signed cert
- You try to install it directly (not via SideStore)
- iOS rejects it (untrusted certificate)
- You use SideStore/AltStore instead
- It works! ✅

## 🧪 Testing

After the workflow completes:

```bash
# Download the artifact
unzip ios-ipa-eas.zip

# Check the signature (will show self-signed)
codesign -dv app.ipa
# Expected: "Signature=adhoc" or similar

# Check the architecture (should be arm64)
lipo -info app.ipa
# Expected: arm64

# Install with SideStore
# SideStore strips the signature and re-signs
```

## 📊 Build Flow

```
GitHub Actions Runner
    ↓
1. Generate self-signed cert + profile
    ↓
2. Create credentials.json
    ↓
3. EAS Build (local)
   - Uses credentials.json
   - Builds .app with self-signed cert
   - Packages into .ipa
    ↓
4. Upload .ipa artifact
    ↓
Your Device
    ↓
5. Download .ipa
    ↓
6. Import to SideStore
    ↓
7. SideStore re-signs with your Apple ID
    ↓
8. Install and run! ✅
```

## 🎓 Technical Details

### Why Not Just Build Unsigned?

**EAS Build's architecture** requires credentials because:
1. It calls `xcodebuild archive` (requires signing)
2. It validates the .ipa structure (checks signature)
3. It's designed for App Store/TestFlight (needs real certs)

### Why Does Self-Signed Work?

**EAS validates format, not authenticity:**
- Checks `.p12` has a private key ✅
- Checks `.mobileprovision` is valid XML ✅
- **Doesn't** check if they're from Apple ❌

### Why Don't We Use This Everywhere?

**It's a workaround!** For normal use cases:
- **App Store**: Use real Apple certificates
- **TestFlight**: Use real Apple certificates
- **Sideloading**: This workaround OR raw xcodebuild

## 🚀 Advantages Over Raw xcodebuild

1. ✅ **No build cycle issues** - EAS handles Expo quirks
2. ✅ **Official Expo support** - Uses Expo's tooling
3. ✅ **Simpler workflow** - Less manual patching
4. ✅ **Better error messages** - EAS provides helpful diagnostics

## ⚠️ Limitations

1. **Requires Expo account** - Need EXPO_TOKEN
2. **Workaround, not official** - Expo doesn't officially support this
3. **May break with EAS updates** - Depends on EAS internals

## 📝 Summary

| Aspect | Details |
|--------|---------|
| **Method** | EAS Build with self-signed credentials |
| **Prerequisites** | Expo account (free) + EXPO_TOKEN |
| **Complexity** | Medium (credential generation) |
| **Reliability** | High (uses official Expo tools) |
| **Output** | Unsigned .ipa ready for sideloading |
| **Maintenance** | Low (EAS handles Expo updates) |

---

**This is a clever workaround that combines the best of both worlds**: Expo's official build tooling + ability to sideload without paid Apple Developer account! 🎉
