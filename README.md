# ActivityTracker

📊 Native macOS SwiftUI app for activity tracking. Lives in your menu bar, tracks app usage, and syncs with MindGrowee Firebase (free tier).

## Features

🍏 **Native macOS App**
- SwiftUI interface
- Menu Bar presence (always accessible)
- Beautiful native design

📱 **Live Activity Tracking**
- See current app in real-time
- Tracks automatically every 5 seconds
- Start/stop from menu bar

📊 **Visual Dashboard**
- Today's total time
- Top apps with progress bars
- Clean SwiftUI charts

🔥 **MindGrowee Integration**
- Shares Firebase backend (free Spark tier)
- Login with MindGrowee account
- Data syncs to same database
- View in MindGrowee app

## Installation

```bash
git clone https://github.com/LennardVW/ActivityTracker.git
cd ActivityTracker
swift build -c release
# Copy to Applications or run directly
```

## Usage

1. **Launch App** - Icon appears in menu bar (📊)
2. **Login** - Use your MindGrowee account
3. **Click Play** - Start tracking
4. **View Stats** - See today's activity

## How It Works

```
┌─────────────────┐     ┌──────────────┐     ┌─────────────────┐
│  ActivityTracker │────▶│   Firebase   │────▶│    MindGrowee   │
│   (macOS Menu Bar)│     │   (Spark)    │     │   (iOS/Android) │
└─────────────────┘     └──────────────┘     └─────────────────┘
```

- Tracks which app is frontmost
- Saves to Firestore every app switch
- Reads data from same Firebase as MindGrowee
- No additional backend costs

## Firebase Costs

**Shared with MindGrowee:**
- Spark Plan: Free
- 50k reads/day, 20k writes/day
- Activity tracking: ~100 writes/day
- Well within free limits

## Tech Stack

- Swift 6 + SwiftUI
- Firebase Auth + Firestore
- Menu Bar (NSStatusBar)
- macOS 15+ (Tahoe)

## Build

```bash
swift build                    # Debug
swift build -c release         # Release
swift run                      # Run debug version
```

## License

MIT
