# 🚀 Quick Start: iOS Unsigned Builds

## TL;DR

Your iOS build setup has been **completely simplified**! No more Apple credentials, keychain headaches, or complex signing. Just build, download, and sideload.

---

## 📦 What Changed

### ❌ OLD: Signed Build (Complex)
- Required `APPLE_ID`, `APPLE_APP_PASSWORD`, `APPLE_TEAM_ID` secrets
- Complex keychain management
- Fragile authentication
- ~300 lines of workflow code

### ✅ NEW: Unsigned Build (Simple)
- **Zero secrets required**
- No keychain management
- No authentication
- ~350 lines (but simpler logic!)

---

## 🎯 How to Build Now

### Method 1: Push to Main (Automatic)
```bash
git push origin main
# Workflow triggers automatically
```

### Method 2: Manual Trigger
1. **Actions** tab → **Build iOS (Unsigned for Sideloading)**
2. Click **Run workflow**
3. Wait ~10-15 minutes

### Method 3: Comment on PR
Comment `build ios` on any pull request

---

## 📥 How to Install

1. **Download** the `ios-unsigned-ipa` artifact from Actions
2. **Extract** the `.ipa` file
3. **Transfer** to your iOS device (AirDrop, iCloud, etc.)
4. **Open** in SideStore or AltStore
5. **Install** (it auto-re-signs with your free Apple ID)
6. **Trust** the certificate in Settings
7. **Launch** the app! 🎉

---

## 🔧 Quick Troubleshooting

### Build Fails?
- Check Xcode version in workflow (may need to change `XCODE_VERSION`)
- View full logs in GitHub Actions
- See `docs/IOS_BUILD_GUIDE.md` for detailed troubleshooting

### Can't Install?
- Make sure you're using SideStore or AltStore
- The `.ipa` must be unsigned (which it is!)
- Check device compatibility (iOS 13+)

### App Won't Launch?
- Go to **Settings → General → VPN & Device Management**
- Trust the developer certificate
- Try again

---

## 📚 Documentation

| File | Purpose |
|------|---------|
| `docs/IOS_BUILD_GUIDE.md` | Complete guide to the unsigned build system |
| `docs/MIGRATION_CHECKLIST.md` | Step-by-step migration from old setup |
| `docs/QUICK_START.md` | This file - quick reference |

---

## ⏰ Remember

- Apps signed with free Apple ID **expire after 7 days**
- Just re-download and re-sign the `.ipa` when expired
- Or trigger a fresh build

---

## 🎊 What You Get

- ✅ **Free** - No paid Apple Developer account needed
- ✅ **Simple** - No credentials to manage
- ✅ **Reliable** - No authentication failures
- ✅ **Fast** - Builds complete in ~10-15 minutes
- ✅ **Perfect** - Designed for SideStore/AltStore

---

## 🚦 Next Steps

1. **Test the workflow**: Push a commit or trigger manually
2. **Download the artifact**: Get the `.ipa` from Actions
3. **Install on device**: Use SideStore or AltStore
4. **Verify it works**: Launch the app and test
5. **Clean up secrets** (optional): Remove old Apple credentials from GitHub

---

## 💡 Pro Tips

- **Bookmark** the Actions page for easy access to builds
- **Set up SideStore** WiFi refresh to auto-renew the app
- **Create a release** workflow to tag important builds
- **Share .ipa files** with team members (they can re-sign too!)

---

## ❓ Questions?

Check the detailed guides:
- **Full documentation**: `docs/IOS_BUILD_GUIDE.md`
- **Migration guide**: `docs/MIGRATION_CHECKLIST.md`

---

**That's it!** Your iOS builds are now **simple, free, and reliable**. 🎉
