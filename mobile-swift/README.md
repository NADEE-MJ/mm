# Mobile Swift - Movie Manager iOS App

Native iOS app built with Swift and SwiftUI for managing movie recommendations.

## Features

- **Native iOS 26**: Built with latest SwiftUI and iOS 26 APIs
- **Biometric Authentication**: Face ID / Touch ID / Optic ID unlock
- **Movie Management**: Browse, search, and manage your movie list
- **People Tracking**: Manage recommenders and trust status
- **Offline Support**: Local database with GRDB.swift
- **Real-time Sync**: WebSocket support for live updates
- **Modern Design**: Dark mode UI matching the test app aesthetic

## Architecture

- **SwiftUI**: Modern declarative UI framework
- **iOS 26 Target**: Latest iOS version support
- **GRDB.swift**: Type-safe SQLite database
- **Nuke**: Advanced image loading and caching
- **XcodeGen**: Project generation from YAML config

## Project Structure

```
mobile-swift/
├── project.yml              # XcodeGen configuration
├── Sources/
│   ├── MobileSwiftApp.swift # App entry point
│   ├── Models/              # Data models
│   ├── Services/            # Network, database, WebSocket
│   ├── Views/               # SwiftUI views
│   │   ├── Tabs/           # Tab views (Home, Lists, People, etc.)
│   │   └── Components/      # Reusable components
│   ├── Theme/              # App theming
│   └── Info.plist          # App configuration
```

## Development

### Prerequisites

- Xcode 16+ (for iOS 26 support)
- macOS 15+ (Sequoia or later)
- XcodeGen: `brew install xcodegen`

### Local Setup

1. Generate Xcode project:
   ```bash
   cd mobile-swift
   xcodegen generate
   ```

2. Open project:
   ```bash
   open MobileSwift.xcodeproj
   ```

3. Build and run in Xcode (select iOS Simulator)

### Configuration

The app connects to the Movie Manager backend API. The API base URL is configured via build settings and expanded into Info.plist at build time.

**Security Note:** The app enforces HTTPS-only connections per Apple's App Transport Security (ATS) policy. All API URLs must use HTTPS.

**How it works:**
- `Config/App.xcconfig` is loaded for Debug/Release and optionally includes `Config/Env.generated.xcconfig`
- The app uses `Sources/Info.plist` (`GENERATE_INFOPLIST_FILE = NO`)
- `Sources/Info.plist` contains `<string>$(API_BASE_URL)</string>` and build settings expansion writes the final URL
- The generator script escapes `/` safely for xcconfig so `https://...` is preserved

**For local development:**
- Create `mobile-swift/.env` with one of:
  - `API_BASE_URL=https://your-api.example.com/api`
  - `MOBILE_SWIFT_API_BASE_URL=https://your-api.example.com/api`
- Generate xcconfig before building:
  ```bash
  cd mobile-swift
  ./scripts/generate-env-xcconfig.sh
  ```
- `Config/Env.generated.xcconfig` is generated and ignored by git
- Ensure your backend server supports HTTPS

**For CI/CD builds:**
- **REQUIRED**: Set repository secret `MOBILE_SWIFT_API_BASE_URL` in GitHub
- Must use HTTPS URL. You can set either:
  - `https://your-api.example.com` (the build/runtime appends `/api`)
  - `https://your-api.example.com/api`
- The workflow validates this is set and **fails early** if missing/invalid (no fallback)
- The workflow generates `Config/Env.generated.xcconfig` from this secret
- The build verifies the compiled app Info.plist contains the normalized API URL (always ending in `/api`)

Then regenerate the Xcode project:
```bash
xcodegen generate
```

## Debug Logging

- Uses `os.Logger` for device console logs.
- Developer Labs includes a Logs tab for:
  - Verbose logging toggle (Debug builds)
  - Test log entry
  - Export logs (`app-debug.log`) via share sheet
  - Clear log file
- Log file is stored in app Documents and file sharing is enabled (`UIFileSharingEnabled`).

On Arch Linux, view live device logs:
```bash
idevicesyslog | grep -i "com.moviemanager.mobileswift"
```

## CI/CD Pipeline

Workflow: `.github/workflows/build-mobile-swift.yml`

### Triggers

- **Manual**: `workflow_dispatch` with options for runner, deployment target, and release publishing
- **Pull Request**: Automatically builds when `mobile-swift/` changes
- **Push to main**: Automatically builds and publishes release when `mobile-swift/` changes

### Output

- **Artifact**: `mobile-swift-unsigned-ipa` (30 day retention)
- **Release**: `mobile-swift-latest` tag with latest IPA

## Installation

### From GitHub Releases

1. Open GitHub mobile app → Releases
2. Find `mobile-swift-latest` release
3. Download `MobileSwift-unsigned.ipa`
4. Import into SideStore or LiveContainer
5. Install and run

### Development Build

1. Build in Xcode
2. Deploy to connected iPhone
3. Trust developer certificate in Settings → General → VPN & Device Management

## Tabs Overview

- **Home**: Browse movies by status (To Watch, Watched, Questionable)
- **Lists**: View organized movie lists
- **People**: Manage recommenders and trust status
- **Account**: Settings and app information
- **Explore**: Search and add new movies from TMDB

## Comparison with Other Apps

| Feature | mobile-swift | mobile (React Native) |
|---------|-------------|----------------------|
| Platform | iOS 26 Swift | Cross-platform (Expo) |
| UI Framework | SwiftUI | React Native |
| Purpose | Movie Manager | Movie Manager |
| Backend | Movie Manager API | Movie Manager API |
| Look & Feel | Modern iOS 26 | Material-inspired |

## Notes

- IPA is unsigned by design for sideloading
- Requires backend API to be running for full functionality
- Offline mode works with cached data
- BiometricAuthManager handles Face ID / Touch ID authentication
- GRDB provides type-safe SQLite access
- WebSocket manager ready for real-time sync (backend support needed)
