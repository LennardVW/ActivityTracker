import Foundation
import AppKit

// MARK: - ActivityTracker
/// Beautiful activity tracking for macOS
/// Tracks app usage with visualizations
/// Ready for MindGrowee integration

@main
struct ActivityTracker {
    static func main() async {
        let tracker = ActivityTrackerCore()
        await tracker.run()
    }
}

@MainActor
final class ActivityTrackerCore {
    private var isTracking = false
    private var currentSession: AppSession?
    private var sessions: [AppSession] = []
    private let dataPath = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".activitytracker/data.json")
    private var timer: Timer?
    
    struct AppSession: Codable {
        let id: UUID
        let appName: String
        let bundleId: String
        let startTime: Date
        var endTime: Date?
        var duration: TimeInterval {
            endTime?.timeIntervalSince(startTime) ?? Date().timeIntervalSince(startTime)
        }
    }
    
    struct DailyStats: Codable {
        let date: Date
        let appUsage: [String: TimeInterval]
        let totalActiveTime: TimeInterval
    }
    
    func run() async {
        loadData()
        
        print("""
        📊 ActivityTracker - Beautiful Activity Tracking
        
        Commands:
          start           Start tracking
          stop            Stop tracking
          status          Current activity
          today           Today's summary with chart
          week            Weekly report with chart
        
        MindGrowee Integration:
          export          Export data for MindGrowee
          sync            Sync with MindGrowee API
        
        Press 'start' to begin tracking your activity
        """)
        
        while true {
            print("> ", terminator: "")
            guard let input = readLine()?.trimmingCharacters(in: .whitespaces) else { continue }
            
            let parts = input.split(separator: " ")
            let command = parts.first?.lowercased() ?? ""
            
            switch command {
            case "start", "s":
                startTracking()
            case "stop", "x":
                stopTracking()
            case "status", "st":
                showStatus()
            case "today", "t":
                showTodayChart()
            case "week", "w":
                showWeekChart()
            case "export", "e":
                exportForMindGrowee()
            case "sync":
                syncWithMindGrowee()
            case "quit", "q":
                stopTracking()
                print("👋 Goodbye!")
                return
            default:
                print("Unknown command. Type 'start' to begin tracking.")
            }
        }
    }
    
    func startTracking() {
        guard !isTracking else {
            print("⚠️  Already tracking!")
            return
        }
        
        isTracking = true
        print("📊 Tracking started...")
        print("   Switch between apps to track usage")
        
        // Track current app immediately
        trackCurrentApp()
        
        // Start timer to check every 5 seconds
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            Task { @MainActor in
                self.trackCurrentApp()
            }
        }
        
        // Start live display
        Task {
            await showLiveActivity()
        }
    }
    
    func stopTracking() {
        isTracking = false
        timer?.invalidate()
        timer = nil
        
        // Close current session
        if var session = currentSession {
            session.endTime = Date()
            sessions.append(session)
            currentSession = nil
            saveData()
        }
        
        print("🛑 Tracking stopped")
        print("   Data saved to ~/.activitytracker/")
    }
    
    func trackCurrentApp() {
        guard let app = NSWorkspace.shared.frontmostApplication else { return }
        
        let appName = app.localizedName ?? "Unknown"
        let bundleId = app.bundleIdentifier ?? "unknown"
        
        // Check if app changed
        if let current = currentSession, current.bundleId != bundleId {
            // Save previous session
            var endedSession = current
            endedSession.endTime = Date()
            sessions.append(endedSession)
            currentSession = nil
            saveData()
        }
        
        // Start new session if needed
        if currentSession == nil {
            currentSession = AppSession(
                id: UUID(),
                appName: appName,
                bundleId: bundleId,
                startTime: Date(),
                endTime: nil
            )
        }
    }
    
    func showLiveActivity() async {
        while isTracking {
            guard let session = currentSession else {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                continue
            }
            
            let duration = Date().timeIntervalSince(session.startTime)
            let mins = Int(duration) / 60
            let secs = Int(duration) % 60
            
            print("\r📱 \(session.appName) - \(mins)m \(secs)s     ", terminator: "")
            fflush(stdout)
            
            try? await Task.sleep(nanoseconds: 1_000_000_000)
        }
    }
    
    func showStatus() {
        if isTracking, let session = currentSession {
            let duration = Date().timeIntervalSince(session.startTime)
            print("📊 Tracking: \(session.appName) for \(Int(duration/60))m")
        } else {
            print("😴 Not tracking - Run 'start' to begin")
        }
    }
    
    func showTodayChart() {
        let today = Calendar.current.startOfDay(for: Date())
        let todaySessions = sessions.filter {
            Calendar.current.isDate($0.startTime, inSameDayAs: today)
        }
        
        // Aggregate by app
        var appTimes: [String: TimeInterval] = [:]
        for session in todaySessions {
            appTimes[session.appName, default: 0] += session.duration
        }
        
        // Sort by time
        let sorted = appTimes.sorted { $0.value > $1.value }
        
        print("\n📊 Today Activity (Top Apps)\n")
        
        guard !sorted.isEmpty else {
            print("   No data for today yet")
            print("   Run 'start' to begin tracking\n")
            return
        }
        
        let maxTime = sorted.first?.value ?? 1
        
        for (app, time) in sorted.prefix(8) {
            let minutes = Int(time / 60)
            let barLength = Int((time / maxTime) * 40)
            let bar = String(repeating: "█", count: barLength)
            print("   \(app.padding(toLength: 15, withPad: " ", startingAt: 0)) \(bar) \(minutes)m")
        }
        
        let total = todaySessions.reduce(0) { $0 + $1.duration }
        print("\n   Total tracked: \(Int(total/3600))h \(Int((total%3600)/60))m")
        print()
    }
    
    func showWeekChart() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        print("\n📈 Last 7 Days\n")
        
        for dayOffset in (0..<7).reversed() {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) else { continue }
            
            let daySessions = sessions.filter {
                calendar.isDate($0.startTime, inSameDayAs: date)
            }
            
            let totalTime = daySessions.reduce(0) { $0 + $1.duration }
            let hours = Int(totalTime / 3600)
            let barLength = min(hours * 4, 40)
            let bar = String(repeating: "█", count: barLength)
            
            let dayName = dayOffset == 0 ? "Today" : dateFormatter.string(from: date)
            print("   \(dayName.padding(toLength: 10, withPad: " ", startingAt: 0)) \(bar) \(hours)h")
        }
        print()
    }
    
    func exportForMindGrowee() {
        // Export in MindGrowee-compatible format
        let today = Calendar.current.startOfDay(for: Date())
        let todaySessions = sessions.filter {
            Calendar.current.isDate($0.startTime, inSameDayAs: today)
        }
        
        var appTimes: [String: TimeInterval] = [:]
        for session in todaySessions {
            appTimes[session.appName, default: 0] += session.duration
        }
        
        let export = MindGroweeExport(
            date: today,
            activities: appTimes.map { (app, time) in
                ActivityExport(appName: app, minutes: Int(time / 60), category: categoryFor(app))
            }
        )
        
        let desktop = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Desktop/activity_export.json")
        
        if let data = try? JSONEncoder().encode(export) {
            try? data.write(to: desktop)
            print("✅ Exported to Desktop/activity_export.json")
            print("   Ready for MindGrowee import")
        }
    }
    
    func syncWithMindGrowee() {
        print("🔄 Syncing with MindGrowee...")
        print("   (Feature: API integration)")
        print("   Export JSON created - import in MindGrowee settings")
    }
    
    func categoryFor(_ app: String) -> String {
        let productivityApps = ["Xcode", "VS Code", "Cursor", "IntelliJ", "Terminal"]
        let communicationApps = ["Slack", "Discord", "Teams", "Zoom"]
        let socialApps = ["Safari", "Chrome", "Firefox"]
        
        if productivityApps.contains(app) { return "productivity" }
        if communicationApps.contains(app) { return "communication" }
        if socialApps.contains(app) { return "browsing" }
        return "other"
    }
    
    struct MindGroweeExport: Codable {
        let date: Date
        let activities: [ActivityExport]
    }
    
    struct ActivityExport: Codable {
        let appName: String
        let minutes: Int
        let category: String
    }
    
    let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "EEE"
        return df
    }()
    
    func loadData() {
        guard let data = try? Data(contentsOf: dataPath),
              let saved = try? JSONDecoder().decode([AppSession].self, from: data) else {
            return
        }
        sessions = saved
    }
    
    func saveData() {
        try? FileManager.default.createDirectory(at: dataPath.deletingLastPathComponent(), withIntermediateDirectories: true)
        guard let data = try? JSONEncoder().encode(sessions) else { return }
        try? data.write(to: dataPath)
    }
}
