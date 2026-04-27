# CopyParty Setup

CopyParty is used by the Mentat backend to generate time-limited download links for IPA files. It runs as a launchd agent on the Mac Mini.

## Prerequisites

```bash
brew install copyparty
sudo mkdir -p /opt/ipa-builds
sudo chown nadeem /opt/ipa-builds
```

## Launch Agent

Create `~/Library/LaunchAgents/com.nadeem.copyparty.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.nadeem.copyparty</string>
    <key>ProgramArguments</key>
    <array>
        <string>/opt/homebrew/bin/copyparty</string>
        <string>/opt/ipa-builds</string>
        <string>--port</string>
        <string>3923</string>
        <string>--host</string>
        <string>127.0.0.1</string>
        <string>-a</string>
        <string>admin:Test1234!</string>
        <string>-v</string>
        <string>/opt/ipa-builds:ipa-builds:c,g:pw=Test1234!</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/tmp/copyparty.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/copyparty.err</string>
</dict>
</plist>
```

### Explanation of flags

| Flag | Meaning |
|---|---|
| `/opt/ipa-builds` | Root directory to serve |
| `--port 3923` | Port CopyParty listens on |
| `--host 127.0.0.1` | Bind to localhost only (Mentat backend is the only consumer) |
| `-a admin:Test1234!` | Admin account for creating shares |
| `-v /opt/ipa-builds:ipa-builds:c,g:pw=Test1234!` | Virtual volume: path, name, permissions (`c`=create, `g`=download), password |

### Load / unload

```bash
# Load (start now and on login)
launchctl load ~/Library/LaunchAgents/com.nadeem.copyparty.plist

# Unload (stop and disable)
launchctl unload ~/Library/LaunchAgents/com.nadeem.copyparty.plist

# Check it's running
curl http://127.0.0.1:3923/
```

## Mentat Backend `.env`

Add these to `backend/.env` in the Mentat repo:

```env
COPYPARTY_URL=http://127.0.0.1:3923
COPYPARTY_PATH=/ipa-builds
COPYPARTY_PASSWORD=Test1234!
COPYPARTY_SHR_PREFIX=/s
```

## How shares work

When the Mentat iOS app taps "Download" for an IPA:

1. The Mentat backend POSTs to CopyParty's share API, creating a 5-minute time-limited link.
2. CopyParty responds with a direct download URL (e.g. `http://127.0.0.1:3923/s/<key>/mentat.ipa`).
3. The Mentat backend returns this URL to the iOS app, which opens it in Safari/browser via the SSH tunnel.

## Adding more apps

To serve additional IPAs, drop them into `/opt/ipa-builds/` and add a corresponding entry to `backend/config/servers.json` in the Mentat repo:

```json
{
    "id": "my-app",
    "displayName": "My App",
    "buildCommand": "cd /path/to/repo && bash scripts/build.sh",
    "ipaPath": "/opt/ipa-builds/my-app.ipa",
    "copypartyVirtualPath": "/ipa-builds/my-app.ipa"
}
```
