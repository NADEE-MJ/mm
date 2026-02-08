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

The app connects to the Movie Manager backend API. The API base URL is configured via build settings with Info.plist preprocessing enabled.

**Security Note:** The app enforces HTTPS-only connections per Apple's App Transport Security (ATS) policy. All API URLs must use HTTPS.

**How it works:**
- Info.plist preprocessing (`INFOPLIST_PREPROCESS: YES`) expands `$(API_BASE_URL)` at build time
- The build setting value gets injected into the compiled app's Info.plist

**For local development:**
- Default value is `https://localhost:8000/api` (set in `project.yml`)
- Ensure your local backend server supports HTTPS
- This works for Xcode builds without any changes

**For CI/CD builds:**
- **REQUIRED**: Set repository variable or secret `MOBILE_SWIFT_API_BASE_URL` in GitHub
- Must use HTTPS URL (e.g., `https://your-api.example.com/api`)
- The workflow validates this is set and **fails early** if missing (no fallback)
- The workflow automatically injects this value during build
- The preprocessor expands `$(API_BASE_URL)` to the actual URL

**To change for local builds:**
Edit `project.yml` and update the `API_BASE_URL` setting:
```yaml
settings:
  base:
    API_BASE_URL: "https://your-api-url:8000/api"
```

Then regenerate the Xcode project:
```bash
xcodegen generate
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

| Feature | mobile-swift | mobile (React Native) | ios-test-swift |
|---------|-------------|----------------------|----------------|
| Platform | iOS 26 Swift | Cross-platform (Expo) | iOS 26 Swift |
| UI Framework | SwiftUI | React Native | SwiftUI |
| Purpose | Movie Manager | Movie Manager | UI Demo |
| Backend | Movie Manager API | Movie Manager API | GitHub API (demo) |
| Look & Feel | Modern iOS 26 | Material-inspired | Modern iOS 26 |

## Notes

- IPA is unsigned by design for sideloading
- Requires backend API to be running for full functionality
- Offline mode works with cached data
- BiometricAuthManager handles Face ID / Touch ID authentication
- GRDB provides type-safe SQLite access
- WebSocket manager ready for real-time sync (backend support needed)
