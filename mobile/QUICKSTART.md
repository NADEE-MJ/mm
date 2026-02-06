# Quick Start Guide

## Test the Mobile App Now

### Option 1: Android Emulator (Recommended for Linux)

```bash
# 1. Start Android emulator
emulator -avd Pixel_6_API_34 &

# 2. Start Expo dev server
cd /home/nadeem/Documents/mm/mobile
npx expo start

# 3. Press 'a' in terminal to launch on Android
```

### Option 2: iPhone with Expo Go

```bash
# 1. Start Expo dev server
cd /home/nadeem/Documents/mm/mobile
npx expo start

# 2. Scan QR code with iPhone camera
# 3. App opens in Expo Go automatically
```

### Option 3: Web Browser (Quick Test)

```bash
cd /home/nadeem/Documents/mm/mobile
npx expo start --web
```

---

## What to Test

### 1. Registration Flow

1. Launch app → Should show login screen
2. Tap "Don't have an account? Sign up"
3. Fill in email, username, password (min 6 chars)
4. Tap "Sign Up"
5. **Expected**: Account created, navigates to Movies tab

### 2. Login Flow

1. Launch app → Should show login screen
2. Enter username and password
3. Tap "Sign In"
4. **Expected**: Logged in, navigates to Movies tab

### 3. Biometric Setup

1. Login to app
2. Navigate to Account tab (bottom right)
3. Toggle "Biometric Unlock" on
4. **Expected**: Biometric prompt appears (if device supports it)

### 4. Biometric Unlock

1. Close app completely
2. Relaunch app
3. **Expected**: Biometric prompt appears (Face ID/Touch ID/Fingerprint)
4. Authenticate successfully
5. **Expected**: Navigate directly to Movies tab

### 5. Logout

1. Navigate to Account tab
2. Tap "Logout" button
3. Confirm logout
4. **Expected**: All data cleared, return to login screen

---

## Backend Configuration

### Update API URL

Edit `/home/nadeem/Documents/mm/mobile/src/services/api/client.ts`:

```typescript
const API_BASE_URL = __DEV__
  ? 'http://YOUR_LOCAL_IP:3000/api'  // e.g., 'http://192.168.1.100:3000/api'
  : 'https://api.moviemanager.com/api';
```

**Important**: For Android emulator or iPhone, `localhost` won't work. Use your computer's local IP address.

### Find Your Local IP

```bash
# Linux
ip addr show | grep inet

# macOS
ifconfig | grep inet

# Look for something like: 192.168.1.XXX
```

### Start Backend

```bash
cd /home/nadeem/Documents/mm/backend
# Start your backend server
# Ensure it's accessible on your local network
```

---

## Debugging

### View Logs

```bash
# Metro bundler shows logs by default
# Or use React Native Debugger

# Android device logs
adb logcat | grep -i "moviemanager"
```

### Common Issues

**1. "Network Error" on login**
- Check API_BASE_URL in client.ts
- Ensure backend is running
- Use local IP, not localhost
- Check CORS settings in backend

**2. "Database not initialized"**
- This should auto-initialize on first launch
- If error persists, logout and login again

**3. Biometric not working**
- Ensure device/emulator supports biometric
- Android emulator: Set up fingerprint in Settings > Security
- iPhone simulator: Face ID automatically works

**4. App crashes on launch**
- Clear cache: `npx expo start -c`
- Check console for errors
- Ensure all dependencies installed

### Reset Everything

```bash
# Clear Metro bundler cache
npx expo start -c

# Or completely rebuild
rm -rf node_modules
npm install
npx expo run:android --clear
```

---

## Explore the Code

### Key Files to Understand

1. **Authentication Flow**
   - `app/_layout.tsx` - Root layout, checks auth on launch
   - `src/stores/authStore.ts` - Auth state management
   - `src/services/auth/` - JWT storage, biometric

2. **Database**
   - `src/services/database/schema.ts` - SQLite schema
   - `src/services/database/init.ts` - DB initialization

3. **API Client**
   - `src/services/api/client.ts` - Axios configuration
   - `src/services/api/auth.ts` - Auth endpoints

4. **UI Screens**
   - `app/(auth)/login.tsx` - Login screen
   - `app/(tabs)/account.tsx` - Account settings

---

## Next: Implement Movies

Ready to continue? Next steps:

1. Create movie storage service
2. Build movie list UI
3. Add TMDB search
4. Implement sync system

See `IMPLEMENTATION_STATUS.md` for detailed roadmap.
