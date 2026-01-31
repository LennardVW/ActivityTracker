# ActivityTracker

📊 Beautiful activity tracking for macOS. Track your app usage with gorgeous visualizations and integrate with MindGrowee.

## Features

- 📱 **Real-time Tracking** - See which app you're using live
- 📊 **Beautiful Charts** - ASCII charts in terminal (SwiftUI widgets coming)
- 📈 **Daily/Weekly Reports** - Track your productivity over time
- 🔄 **MindGrowee Integration** - Export data to correlate with habits
- 💾 **Local Storage** - All data stays on your Mac
- 🎯 **Productivity Insights** - See where your time goes

## Installation

```bash
git clone https://github.com/LennardVW/ActivityTracker.git
cd ActivityTracker
swift build -c release
cp .build/release/activitytracker /usr/local/bin/
```

## Usage

```bash
# Start tracking
activitytracker start

# See today's activity chart
activitytracker today

# Weekly report
activitytracker week

# Export for MindGrowee
activitytracker export
```

## Commands

- `start` - Begin tracking app usage
- `stop` - Stop tracking
- `today` - Today's activity with bar chart
- `week` - Last 7 days overview
- `export` - Export JSON for MindGrowee
- `sync` - Sync with MindGrowee API

## MindGrowee Integration

Export your activity data and import into MindGrowee to:
- Correlate app usage with mood
- Track productivity habits
- See which apps make you happy

## Widgets

Coming soon:
- Menu Bar widget
- Today View widget
- Desktop widget

## Requirements

- macOS 15.0+ (Tahoe)
- Swift 6.0+

## License

MIT
