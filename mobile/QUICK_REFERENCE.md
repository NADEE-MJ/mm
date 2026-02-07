# Quick Reference Card

## 🚀 Get Started in 3 Steps

### 1. Configure API URL

Edit `/home/nadeem/Documents/mm/mobile/src/services/api/client.ts`:

```typescript
const API_BASE_URL = 'http://YOUR_IP:3000/api';  // e.g., 'http://192.168.1.100:3000/api'
```

Find your IP: `ip addr show | grep inet`

### 2. Start Backend

```bash
cd /home/nadeem/Documents/mm/backend
# Start your backend server on port 3000
```

### 3. Launch Mobile App

```bash
cd /home/nadeem/Documents/mm/mobile
npx expo start

# Then:
# - Press 'a' for Android emulator
# - Scan QR code with iPhone Expo Go app
# - Press 'w' for web browser
```

---

## 📂 Project Structure

```
mobile/
├── app/                    # Screens (Expo Router)
│   ├── (auth)/            # Login, Register
│   ├── (tabs)/            # Movies, People, Lists, Account
│   └── movie/             # Add, Detail
├── src/
│   ├── services/          # Database, API, Sync, Storage
│   ├── stores/            # Zustand state (auth, movies, sync, people, lists)
│   ├── components/        # Reusable UI
│   ├── types/             # TypeScript interfaces
│   └── utils/             # Constants, helpers
└── docs/                  # Documentation
```

---

## 🎯 Key Features

### Movies
- **Add**: FAB → Search TMDB → Select → Add person → Save
- **View**: List with filters (All, To Watch, Watched)
- **Detail**: Tap card → See info, rate, vote, manage
- **Search**: Search bar at top of Movies tab
- **Sync**: Auto-syncs when online, manual in Account tab

### People
- **Add**: FAB → Enter name → Add
- **Stats**: Shows recommendations, upvotes, downvotes, watched
- **Delete**: Trash icon (keeps their recommendations)

### Lists
- **Create**: FAB → Enter name → Create
- **Delete**: Trash icon (moves movies to "To Watch")
- **Use**: Assign movies to lists from movie detail

### Account
- **Biometric**: Toggle Face ID/Touch ID unlock
- **Sync**: View status, trigger manual sync
- **Logout**: Clears all local data

---

## 🔄 Sync System

### How It Works
1. **Offline**: Actions saved locally, queued for sync
2. **Online**: Auto-syncs every 30s or on network change
3. **Conflicts**: Last-modified timestamp wins
4. **Status**: Check Account tab for sync status

### Manual Sync
Account tab → "Sync Now" button

---

## 🗄️ Database

### Location
- Android: `/data/data/com.moviemanager.mobile/databases/moviemanager.db`
- iOS: App sandbox

### Tables
- `movies` - Movie data with TMDB/OMDB
- `recommendations` - Upvotes/downvotes from people
- `watch_history` - Watch dates and ratings
- `movie_status` - Movie status (toWatch, watched, etc.)
- `people` - Recommenders
- `custom_lists` - User lists
- `sync_queue` - Offline actions
- `metadata` - App settings

---

## 🧪 Testing Flow

### 1. Create Account
Login screen → "Sign up" → Enter details → Submit

### 2. Add Your First Movie
Movies tab → FAB (+) → Search "Inception" → Select → Enter friend's name → Add

### 3. Rate the Movie
Tap movie card → "Mark as Watched" → Enter rating (1-10) → Submit

### 4. Test Offline Sync
1. Enable airplane mode
2. Add another movie
3. Disable airplane mode
4. Account tab → Check sync status
5. Should see "Syncing..." then "All changes synced"

### 5. Add People & Lists
- People tab → Add your friends
- Lists tab → Create "Favorites", "Action", etc.

---

## 🐛 Troubleshooting

### "Network Error" on login
- Check API URL in `client.ts`
- Use local IP, not `localhost`
- Ensure backend is running
- Check CORS settings in backend

### Database errors
- Logout → Login again (recreates DB)
- Check console for specific errors

### Biometric not working
- Android emulator: Settings → Security → Add fingerprint
- iPhone simulator: Face ID works automatically

### App crashes on launch
```bash
# Clear cache
npx expo start -c

# Or rebuild
npx expo run:android --clear
```

### Sync not working
- Check Account tab for errors
- Ensure online (check WiFi)
- Check backend /api/sync endpoint
- View sync_queue table for pending items

---

## 📱 Device Setup

### Android Emulator

```bash
# Create AVD (if needed)
avdmanager create avd -n Pixel_6_API_34 \
  -k "system-images;android-34;google_apis;x86_64" \
  -d "pixel_6"

# Start emulator
emulator -avd Pixel_6_API_34
```

### iPhone with Expo Go

1. Download Expo Go from App Store
2. Connect to same WiFi as dev machine
3. Scan QR code

---

## ⌨️ Common Commands

```bash
# Start dev server
npx expo start

# Clear cache
npx expo start -c

# Run on Android
npx expo run:android

# Run on iOS (macOS only)
npx expo run:ios

# Type check
npx tsc --noEmit

# Build unsigned iOS IPA via GitHub Actions
# Push to main or run workflow manually:
# .github/workflows/build-ios-simple.yml
```

---

## 📊 File Counts

- **62** total files created
- **11** services
- **5** stores (state management)
- **10** screens
- **1** reusable component
- **4** documentation files

---

## 🔗 Important Files

### Configuration
- `app.json` - Expo config
- `package.json` - Dependencies
- `src/services/api/client.ts` - API URL

### Core Logic
- `src/stores/*.ts` - State management
- `src/services/sync/processor.ts` - Sync logic
- `src/services/database/schema.ts` - DB schema

### Screens
- `app/(tabs)/index.tsx` - Movies list
- `app/movie/add.tsx` - Add movie
- `app/movie/[imdbId].tsx` - Movie detail

---

## 💡 Tips

1. **Always test offline first** - It's the hardest part
2. **Check sync queue** - Use Account tab to verify sync
3. **Use pull-to-refresh** - Manually refresh movie list
4. **Watch console logs** - Helpful for debugging
5. **Test biometric early** - Setup on device/emulator first

---

## 🎯 Next Features to Add (Optional)

- [ ] Background sync (expo-task-manager)
- [ ] Push notifications (expo-notifications)
- [ ] Movie filters (by genre, year, rating)
- [ ] Person avatars with photos
- [ ] List color customization
- [ ] Export/import data
- [ ] Analytics/insights
- [ ] Social sharing

---

## 📞 Need Help?

1. Check `README.md` for detailed setup
2. Check `QUICKSTART.md` for testing guide
3. Check `COMPLETE_STATUS.md` for feature list
4. Check app console for errors
5. Verify backend is running and accessible

---

**Pro Tip**: Start with a clean slate by logging out and logging back in. This ensures the database is properly initialized and synced.
