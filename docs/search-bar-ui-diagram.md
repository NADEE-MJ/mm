## Search Bar UI - Before and After

### BEFORE
```
┌─────────────────────────────────┐
│  🔍 Search movies...            │  ← Navigation bar search
├─────────────────────────────────┤
│                                 │
│    [Movie Grid/List]            │
│                                 │
│                                 │
│                                 │
│                                 │
│                                 │
└─────────────────────────────────┘
│  🏠  👥  📋  ⚙️        ➕     │  ← Tab bar
└─────────────────────────────────┘
```

### AFTER
```
┌─────────────────────────────────┐
│  Movies                         │  ← Clean navigation (no search)
├─────────────────────────────────┤
│                                 │
│    [Movie Grid/List]            │
│                                 │
│                                 │
│                                 │
│                                 │
│                                 │
└─────────────────────────────────┘
│  🏠  👥  📋  ⚙️    🔍  ➕     │  ← Tab bar with search icon
└─────────────────────────────────┘
```

### AFTER (Search Expanded)
```
┌─────────────────────────────────┐
│  Movies                         │
├─────────────────────────────────┤
│                                 │
│    [Filtered Movie Results]     │
│                                 │
│                                 │
│                                 │
│                                 │
│                                 │
└─────────────────────────────────┘
│ 🔍 Search movies... ✕           │  ← Expanded search bar
├─────────────────────────────────┤
│  🏠  👥  📋  ⚙️    ✕  ➕     │  ← Search icon becomes X
└─────────────────────────────────┘
```

## Interaction Flow

1. **Default State**
   - Magnifying glass icon (🔍) in bottom tab bar
   - No search bar visible
   - Full movie list shown

2. **User taps magnifying glass**
   - Search bar slides in from left above tab bar
   - Magnifying glass icon transforms to X
   - Keyboard appears automatically
   - Text field is focused

3. **User types search query**
   - Movies filter in real-time
   - Results update as user types
   - Clear button (✕) appears in search field

4. **User taps X icon or dismisses keyboard**
   - Search bar slides out
   - Search text clears
   - Icon transforms back to magnifying glass
   - Full movie list returns

5. **User switches tabs**
   - Search state automatically resets
   - Search bar collapses if expanded
   - Clean state for next visit to Home tab

## Key Features

✅ **Space Efficient** - Search hidden when not needed
✅ **Thumb-Friendly** - Search button in easy reach at bottom
✅ **Smooth Animations** - Spring curves for natural motion
✅ **Auto-Focus** - Keyboard appears automatically
✅ **Smart Reset** - Clears on tab switch
✅ **Glass Effect** - Consistent with app design language
✅ **Responsive** - Adapts to minimized tab bar state
