# iOS Build & Distribution

The iOS app is built as an **unsigned IPA** via GitHub Actions and distributed by sideloading onto your iPhone using SideStore or LiveContainer. No Apple Developer account is required.

---

## GitHub Actions Workflow

**File**: `.github/workflows/build-mobile.yml`

### Triggers

| Trigger | Condition |
|---|---|
| Push to `main` | Only when files in `mobile/**` change |
| Pull request | Only when files in `mobile/**` change |
| Manual dispatch | Actions tab → "Build Mobile Swift App (Unsigned)" → Run workflow |

Manual dispatch options:
- **Runner**: macOS runner version
- **Deployment target**: iOS version minimum
- **Publish release**: whether to update the `mobile-latest` release tag

### Build Steps

1. Install XcodeGen
2. Generate `Config/Env.generated.xcconfig` from the `MOBILE_API_BASE_URL` secret
3. Run `xcodegen generate` to produce `MovieManager.xcodeproj`
4. Resolve Swift Package Manager dependencies
5. `xcodebuild archive` with code signing disabled
6. Package `.app` into `.ipa`
7. Upload artifact: `mobile-unsigned-ipa` (30-day retention)
8. Update rolling release tag `mobile-latest` (push to main / manual only)

### Required Secret

Set in **Repository Settings → Secrets and variables → Actions → Secrets**:

| Secret | Example value | Notes |
|---|---|---|
| `MOBILE_API_BASE_URL` | `https://api.example.com/api` | Must be HTTPS. Must end in `/api` or the app appends it. |

The workflow validates this is set and **fails immediately** with a clear message if it is missing or doesn't start with `https://`.

---

## Downloading the IPA

### From GitHub Mobile App (Easiest)

1. Open the GitHub app on your iPhone
2. Navigate to this repository
3. Tap **Releases**
4. Open the `mobile-latest` release
5. Download `MovieManager-unsigned.ipa`

### From GitHub Web

1. Go to the repository on github.com
2. Click **Releases** in the sidebar
3. Open `mobile-latest`
4. Download `MovieManager-unsigned.ipa`

### From Actions Artifacts

1. Go to **Actions** tab
2. Open the latest successful `build-mobile` run
3. Download `mobile-unsigned-ipa` artifact (ZIP containing the IPA)

---

## Installing via SideStore

[SideStore](https://sidestore.io) is a self-managed iOS app sideloader that requires pairing your device once.

1. Install SideStore on your iPhone (follow sidestore.io instructions)
2. In SideStore, tap **+** and select "Import IPA from Files"
3. Select the downloaded IPA
4. Tap Install
5. On first launch: go to **Settings → General → VPN & Device Management** and trust the developer certificate

---

## Installing via LiveContainer

[LiveContainer](https://github.com/LiveContainer/LiveContainer) runs multiple sideloaded apps as containers inside one signed app, saving sideloading slots.

1. Install LiveContainer (follow its README)
2. Import the IPA into LiveContainer
3. Create an app entry and optionally assign a custom icon
4. Use iOS Shortcuts to create a home screen shortcut for each app entry

---

## Linux: AltServer Setup (for SideStore pairing)

If you are on Linux and need to pair your device with AltServer for SideStore:

### 1. Enable required user services

```bash
systemctl --user enable --now netmuxd.service
systemctl --user enable --now altserver.service
```

### 2. Add your user to the docker group

```bash
sudo usermod -aG docker $USER
# Log out and back in for this to take effect
```

### 3. Start the Anisette server

```bash
docker run -d \
  --restart always \
  --name anisette-v3 \
  -p 6969:6969 \
  --volume anisette-v3_data:/home/Alcoholic/.config/anisette-v3/lib/ \
  dadoum/anisette-v3-server
```

### 4. Verify services are running

```bash
systemctl --user status netmuxd.service altserver.service
```

### 5. Pair your device

Follow the official AltServer/SideStore README for the pairing step.

---

## Troubleshooting

### Build fails: "MOBILE_API_BASE_URL is not set"

The repository secret is missing. Go to **Repository Settings → Secrets and variables → Actions** and add `MOBILE_API_BASE_URL` with a valid HTTPS URL.

### Build succeeds but app points to the wrong backend

The API URL is baked into the app at build time via Info.plist. Update `MOBILE_API_BASE_URL` in the repository secrets and trigger a new build.

### "Untrusted Developer" on first launch

Go to **Settings → General → VPN & Device Management**, find the developer certificate, and tap **Trust**.

### App installed but crashes immediately

Check that the backend is running and reachable at the URL baked into the app. The app's Info.plist API URL must be accessible from the device's network.

### IPA not showing in the `mobile-latest` release

Check the `Publish latest IPA release` step in the workflow run logs under the **Actions** tab.

---

## Related Docs

- [Mobile Architecture](../architecture/mobile.md)
- [Local Development](local-development.md)
- [Environment Variables](../reference/environment-variables.md)
