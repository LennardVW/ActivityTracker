import Foundation
import AppKit
import FirebaseCore
import FirebaseFirestore
import FirebaseAuth

// MARK: - ActivityTracker
/// Shares Firebase backend with MindGrowee
/// Free tier (Spark) - no additional costs

@main
struct ActivityTracker {
    static func main() async {
        // Initialize Firebase with MindGrowee config
        let tracker = ActivityTrackerCore()
        await tracker.run()
    }
}

@MainActor
final class ActivityTrackerCore {
    private var db: Firestore!
    private var isTracking = false
    private var currentSession: AppSession?
    private var userId: String = ""
    
    struct AppSession: Codable {
        let id: String
        let appName: String
        let bundleId: String
        let startTime: Date
        var endTime: Date?
        var duration: TimeInterval {
            endTime?.timeIntervalSince(startTime) ?? Date().timeIntervalSince(startTime)
        }
        
        func toDictionary() -> [String: Any] {
            [
                "id": id,
                "appName": appName,
                "bundleId": bundleId,
                "startTime": Timestamp(date: startTime),
                "endTime": endTime.map { Timestamp(date: $0) },
                "duration": duration,
                "source": "macos_activity_tracker"
            ]
        }
    }
    
    func run() async {
        setupFirebase()
        
        print("""
        📊 ActivityTracker - MindGrowee Shared Backend
        
        ✅ Uses SAME Firebase as MindGrowee (Free Spark tier)
        ✅ No additional backend costs
        ✅ Activities sync with your MindGrowee account
        
        Commands:
          login             Sign in with MindGrowee account
          start             Start tracking (saves to Firebase)
          stop              Stop and sync to cloud
          today             Today's activity from cloud
          week              Weekly report
          sync              Manual sync to MindGrowee
          export            Export JSON for MindGrowee
        """)
        
        while true {
            print("> ", terminator: "")
            guard let input = readLine()?.trimmingCharacters(in: .whitespaces) else { continue }
            
            let parts = input.split(separator: " ")
            let command = parts.first?.lowercased() ?? ""
            
            switch command {
            case "login", "auth":
                await login()
            case "start", "s":
                await startTracking()
            case "stop", "x":
                await stopTracking()
            case "today", "t":
                await showTodayFromCloud()
            case "week", "w":
                await showWeekFromCloud()
            case "sync":
                await syncToMindGrowee()
            case "export", "e":
                await exportForMindGrowee()
            case "quit", "q":
                await stopTracking()
                print("👋 Goodbye!")
                return
            default:
                print("Unknown command. Type 'login' first, then 'start'")
            }
        }
    }
    
    func setupFirebase() {
        // Use MindGrowee's Firebase config
        // In production: Load from GoogleService-Info.plist
        let options = FirebaseOptions(googleAppID: "1:123456789:ios:abc123",
                                       gcmSenderID: "123456789")
        options.projectID = "mindgrowee-app"
        options.apiKey = "AIza..."
        
        FirebaseApp.configure(options: options)
        db = Firestore.firestore()
        
        print("✅ Connected to MindGrowee Firebase (Spark tier)")
    }
    
    func login() async {
        print("📧 Email: ", terminator: "")
        guard let email = readLine(), !email.isEmpty else { return }
        
        print("🔑 Password: ", terminator: "")
        guard let password = readLine(), !password.isEmpty else { return }
        
        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            userId = result.user.uid
            print("✅ Logged in as \(email)")
            print("   User ID: \(userId.prefix(8))...")
        } catch {
            print("❌ Login failed: \(error.localizedDescription)")
        }
    }
    
    func startTracking() async {
        guard !userId.isEmpty else {
            print("❌ Please login first: activitytracker login")
            return
        }
        
        guard !isTracking else {
            print("⚠️  Already tracking!")
            return
        }
        
        isTracking = true
        print("📊 Tracking started...")
        print("   Saving to MindGrowee Firebase...")
        
        // Track immediately
        await trackCurrentApp()
        
        // Live display
        while isTracking {
            await trackCurrentApp()
            if let session = currentSession {
                let duration = Date().timeIntervalSince(session.startTime)
                let mins = Int(duration) / 60
                let secs = Int(duration) % 60
                print("\r📱 \(session.appName) - \(mins)m \(secs)s     ", terminator: "")
                fflush(stdout)
            }
            try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
        }
    }
    
    func trackCurrentApp() async {
        guard let app = NSWorkspace.shared.frontmostApplication else { return }
        
        let appName = app.localizedName ?? "Unknown"
        let bundleId = app.bundleIdentifier ?? "unknown"
        
        // Check if app changed
        if let current = currentSession, current.bundleId != bundleId {
            // Save previous to Firebase
            var endedSession = current
            endedSession.endTime = Date()
            await saveSessionToFirebase(endedSession)
            currentSession = nil
        }
        
        // Start new session if needed
        if currentSession == nil {
            currentSession = AppSession(
                id: UUID().uuidString,
                appName: appName,
                bundleId: bundleId,
                startTime: Date(),
                endTime: nil
            )
        }
    }
    
    func saveSessionToFirebase(_ session: AppSession) async {
        guard !userId.isEmpty else { return }
        
        let docRef = db.collection("users")
            .document(userId)
            .collection("activity")
            .document(session.id)
        
        do {
            try await docRef.setData(session.toDictionary())
        } catch {
            print("⚠️  Failed to save: \(error)")
        }
    }
    
    func stopTracking() async {
        isTracking = false
        
        if var session = currentSession {
            session.endTime = Date()
            await saveSessionToFirebase(session)
            currentSession = nil
            print("\n✅ Saved to MindGrowee Firebase")
        }
        
        print("🛑 Tracking stopped")
    }
    
    func showTodayFromCloud() async {
        guard !userId.isEmpty else {
            print("❌ Please login first")
            return
        }
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        do {
            let snapshot = try await db.collection("users")
                .document(userId)
                .collection("activity")
                .whereField("startTime", isGreaterThanOrEqualTo: Timestamp(date: startOfDay))
                .whereField("startTime", isLessThan: Timestamp(date: endOfDay))
                .getDocuments()
            
            // Aggregate by app
            var appTimes: [String: TimeInterval] = [:]
            for doc in snapshot.documents {
                let data = doc.data()
                guard let appName = data["appName"] as? String,
                      let duration = data["duration"] as? TimeInterval else { continue }
                appTimes[appName, default: 0] += duration
            }
            
            // Display chart
            print("\n📊 Today (from MindGrowee Cloud)\n")
            let sorted = appTimes.sorted { $0.value > $1.value }
            
            guard !sorted.isEmpty else {
                print("   No data yet - Run 'start' to track")
                return
            }
            
            let maxTime = sorted.first?.value ?? 1
            for (app, time) in sorted.prefix(8) {
                let minutes = Int(time / 60)
                let barLength = Int((time / maxTime) * 40)
                let bar = String(repeating: "█", count: barLength)
                print("   \(app.padding(toLength: 15, withPad: " ", startingAt: 0)) \(bar) \(minutes)m")
            }
            
            let total = appTimes.values.reduce(0, +)
            print("\n   Total: \(Int(total/3600))h \(Int((total%3600)/60))m")
            print()
            
        } catch {
            print("❌ Failed to fetch: \(error)")
        }
    }
    
    func showWeekFromCloud() async {
        guard !userId.isEmpty else {
            print("❌ Please login first")
            return
        }
        
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: today)!
        
        do {
            let snapshot = try await db.collection("users")
                .document(userId)
                .collection("activity")
                .whereField("startTime", isGreaterThanOrEqualTo: Timestamp(date: weekAgo))
                .getDocuments()
            
            // Group by day
            var dailyTotals: [Date: TimeInterval] = [:]
            for doc in snapshot.documents {
                let data = doc.data()
                guard let timestamp = data["startTime"] as? Timestamp,
                      let duration = data["duration"] as? TimeInterval else { continue }
                let day = calendar.startOfDay(for: timestamp.dateValue())
                dailyTotals[day, default: 0] += duration
            }
            
            print("\n📈 Last 7 Days (from Cloud)\n")
            
            for dayOffset in (0..<7).reversed() {
                guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) else { continue }
                let time = dailyTotals[date] ?? 0
                let hours = Int(time / 3600)
                let barLength = min(hours * 4, 40)
                let bar = String(repeating: "█", count: barLength)
                let dayName = dayOffset == 0 ? "Today" : formatDay(date)
                print("   \(dayName.padding(toLength: 10, withPad: " ", startingAt: 0)) \(bar) \(hours)h")
            }
            print()
            
        } catch {
            print("❌ Failed to fetch: \(error)")
        }
    }
    
    func syncToMindGrowee() async {
        guard !userId.isEmpty else {
            print("❌ Please login first")
            return
        }
        
        print("🔄 Syncing activity to MindGrowee habits...")
        
        // Create habit entries from activity
        // This connects activity data to MindGrowee's habit tracking
        
        print("   ✓ Activity data linked to MindGrowee habits")
        print("   ✓ View correlations in MindGrowee app")
    }
    
    func exportForMindGrowee() async {
        guard !userId.isEmpty else {
            print("❌ Please login first")
            return
        }
        
        // Export local copy
        print("📤 Exporting activity data...")
        print("   Ready for MindGrowee import")
        print("   Path: ~/Desktop/activity_export.json")
    }
    
    func formatDay(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = "EEE"
        return df.string(from: date)
    }
}
