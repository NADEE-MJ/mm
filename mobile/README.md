# Movie Manager Mobile App

React Native/Expo mobile application for Movie Manager with offline-first capabilities.

## Tech Stack

- **Expo SDK 52** - Managed workflow with file-based routing
- **Expo Router v3** - Type-safe navigation
- **TypeScript** - Type safety
- **expo-sqlite** - Local SQLite database
- **expo-secure-store** - Encrypted token storage
- **expo-local-authentication** - Biometric authentication
- **Zustand** - State management
- **React Native Paper** - UI components
- **Axios** - HTTP client

## Project Structure

```
mobile/
├── app/                          # Expo Router (file-based routing)
│   ├── (auth)/                   # Auth screens (login, register)
│   ├── (tabs)/                   # Main app tabs
│   └── _layout.tsx               # Root layout
├── src/
│   ├── components/               # Reusable UI components
│   ├── services/                 # Core services
│   │   ├── database/             # SQLite schema & operations
│   │   ├── sync/                 # Offline sync queue
│   │   ├── api/                  # API client & endpoints
│   │   ├── auth/                 # Authentication & biometric
│   │   └── storage/              # Data CRUD operations
│   ├── stores/                   # Zustand state stores
│   ├── types/                    # TypeScript interfaces
│   └── utils/                    # Constants & helpers
└── assets/                       # Images, fonts, etc.
```

## Getting Started

### Prerequisites

- Node.js 18+
- npm or yarn
- Expo CLI
- Android Studio (for Android development)
- Xcode (for iOS development, macOS only)

### Installation

```bash
# Install dependencies
npm install

# Start development server
npx expo start

# Run on Android emulator
npx expo run:android

# Run on iOS simulator (macOS only)
npx expo run:ios
```

### Running on Physical Device

1. Install **Expo Go** app from App Store or Google Play
2. Start dev server: `npx expo start`
3. Scan QR code with Expo Go app

## Android Emulator Setup (Linux)

### Install Android Studio

```bash
# Download from https://developer.android.com/studio
# Install required SDK packages via Android Studio:
#   - Android 14.0 (API 34)
#   - Android SDK Build-Tools
#   - Android Emulator

# Add to ~/.bashrc
export ANDROID_HOME=$HOME/Android/Sdk
export PATH=$PATH:$ANDROID_HOME/emulator
export PATH=$PATH:$ANDROID_HOME/platform-tools
```

### Create Android Virtual Device

```bash
# Via Android Studio UI
# Tools > Device Manager > Create Device > Pixel 6

# Or via command line
avdmanager create avd -n Pixel_6_API_34 \
  -k "system-images;android-34;google_apis;x86_64" \
  -d "pixel_6"

# Start emulator
emulator -avd Pixel_6_API_34
```

## Features Implemented

### Phase 1: Foundation ✅

- [x] Expo project with TypeScript
- [x] Expo Router file-based routing
- [x] SQLite schema and initialization
- [x] Database service layer
- [x] Tab navigation UI
- [x] Zustand stores (auth)

### Phase 2: Authentication ✅

- [x] Login/register screens
- [x] SecureStore for JWT
- [x] Auth API client with Axios
- [x] Biometric authentication
- [x] Token expiration handling
- [x] Logout with data cleanup

### Phase 3: Movies Core (In Progress)

- [ ] Movie list screen
- [ ] Movie card component
- [ ] Movie detail modal
- [ ] Add movie flow (TMDB search)
- [ ] Rating/watch history UI
- [ ] Recommendation UI
- [ ] Movie CRUD in SQLite

### Phase 4: Sync System (Planned)

- [ ] Sync queue implementation
- [ ] Queue processor with retry logic
- [ ] Conflict resolution
- [ ] Server sync (GET /api/sync)
- [ ] WebSocket support
- [ ] Sync indicator UI

### Phase 5-9: See Implementation Plan

## Environment Variables

Create a `.env` file in the root directory:

```env
API_BASE_URL=http://localhost:3000/api
```

For production, update `src/services/api/client.ts` with your production API URL.

## Database Schema

The SQLite schema mirrors the backend PostgreSQL schema:

- `users` - User data (single user per device)
- `movies` - Movie metadata (TMDB + OMDB data)
- `recommendations` - Vote data (upvotes/downvotes)
- `watch_history` - Watch dates and ratings
- `movie_status` - Movie status (toWatch, watched, etc.)
- `people` - Recommenders/people
- `custom_lists` - User-created lists
- `sync_queue` - Offline action queue
- `metadata` - App metadata (last sync, settings)

## Offline-First Architecture

1. **User Action** → Optimistic update to SQLite
2. **Queue Action** → Add to `sync_queue` table
3. **Process Queue** → Send to server when online
4. **Conflict Resolution** → Last-modified timestamp wins
5. **Pull Sync** → Fetch server changes periodically

## Testing

```bash
# Type check
npx tsc --noEmit

# Lint
npx expo lint

# Test export (check if app builds)
npx expo export --platform android --dev
```

## Deployment

### Build with EAS

```bash
# Install EAS CLI
npm install -g eas-cli

# Configure EAS
eas build:configure

# Build for iOS
eas build --platform ios

# Build for Android
eas build --platform android
```

## Troubleshooting

### Emulator not starting

```bash
# Check KVM (Linux)
kvm-ok

# Enable KVM
sudo apt install qemu-kvm
sudo adduser $USER kvm
```

### ADB not detecting device

```bash
adb kill-server
adb start-server
adb devices
```

### Clear cache

```bash
npx expo start -c
```

## Next Steps

1. Implement movie CRUD operations
2. Build sync system
3. Add background sync
4. Test on physical devices
5. Deploy to TestFlight and Google Play

## License

Private - All rights reserved
