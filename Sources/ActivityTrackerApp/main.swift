import SwiftUI
import CoreData

// MARK: - ActivityTracker App
/// Uses LOCAL CoreData - NO Firebase costs
/// iCloud sync optional (free tier)

@main
struct ActivityTrackerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var popover: NSPopover?
    var viewModel = ActivityViewModel()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
    }
    
    func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        guard let button = statusItem?.button else { return }
        button.image = NSImage(systemSymbolName: "chart.bar.fill", accessibilityDescription: "Activity")
        button.action = #selector(togglePopover)
        button.target = self
        
        let popover = NSPopover()
        popover.contentSize = NSSize(width: 380, height: 500)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: ActivityTrackerView(viewModel: viewModel))
        self.popover = popover
    }
    
    @objc func togglePopover() {
        guard let button = statusItem?.button, let popover = popover else { return }
        
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }
}

// MARK: - CoreData Model
class Activity: NSObject {
    var id: UUID
    var appName: String
    var bundleId: String
    var startTime: Date
    var endTime: Date?
    
    init(id: UUID = UUID(), appName: String, bundleId: String, startTime: Date, endTime: Date? = nil) {
        self.id = id
        self.appName = appName
        self.bundleId = bundleId
        self.startTime = startTime
        self.endTime = endTime
    }
    
    var duration: TimeInterval {
        endTime?.timeIntervalSince(startTime) ?? Date().timeIntervalSince(startTime)
    }
    
    func toDictionary() -> [String: Any] {
        [
            "id": id.uuidString,
            "appName": appName,
            "bundleId": bundleId,
            "startTime": startTime.timeIntervalSince1970,
            "endTime": endTime?.timeIntervalSince1970 as Any
        ]
    }
}

// MARK: - ViewModel
@MainActor
class ActivityViewModel: ObservableObject {
    @Published var isTracking = false
    @Published var currentApp = ""
    @Published var todayActivities: [Activity] = []
    
    private var trackingTimer: Timer?
    private var currentActivity: Activity?
    private let dataPath: URL
    
    init() {
        dataPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("activity_data.json")
        loadActivities()
    }
    
    func toggleTracking() {
        if isTracking {
            stopTracking()
        } else {
            startTracking()
        }
    }
    
    func startTracking() {
        isTracking = true
        
        trackingTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            Task { @MainActor in
                self.trackCurrentApp()
            }
        }
        
        trackCurrentApp()
    }
    
    func stopTracking() {
        isTracking = false
        trackingTimer?.invalidate()
        trackingTimer = nil
        
        if let activity = currentActivity {
            activity.endTime = Date()
            saveActivity(activity)
            currentActivity = nil
        }
    }
    
    func trackCurrentApp() {
        guard let app = NSWorkspace.shared.frontmostApplication else { return }
        
        let appName = app.localizedName ?? "Unknown"
        let bundleId = app.bundleIdentifier ?? "unknown"
        
        if let current = currentActivity, current.bundleId != bundleId {
            current.endTime = Date()
            saveActivity(current)
            currentActivity = nil
        }
        
        if currentActivity == nil {
            currentActivity = Activity(
                appName: appName,
                bundleId: bundleId,
                startTime: Date()
            )
        }
        
        currentApp = appName
    }
    
    func saveActivity(_ activity: Activity) {
        todayActivities.append(activity)
        persistActivities()
    }
    
    func persistActivities() {
        let allData = todayActivities.map { $0.toDictionary() }
        if let data = try? JSONSerialization.data(withJSONObject: allData) {
            try? data.write(to: dataPath)
        }
    }
    
    func loadActivities() {
        guard let data = try? Data(contentsOf: dataPath),
              let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return
        }
        
        todayActivities = json.compactMap { dict in
            guard let id = dict["id"] as? String,
                  let appName = dict["appName"] as? String,
                  let bundleId = dict["bundleId"] as? String,
                  let startTime = dict["startTime"] as? TimeInterval else { return nil }
            
            let endTime = dict["endTime"] as? TimeInterval
            
            return Activity(
                id: UUID(uuidString: id) ?? UUID(),
                appName: appName,
                bundleId: bundleId,
                startTime: Date(timeIntervalSince1970: startTime),
                endTime: endTime.map { Date(timeIntervalSince1970: $0) }
            )
        }
    }
    
    var aggregatedByApp: [(String, TimeInterval)] {
        var totals: [String: TimeInterval] = [:]
        for activity in todayActivities {
            totals[activity.appName, default: 0] += activity.duration
        }
        return totals.sorted { $0.value > $1.value }
    }
    
    var totalTimeToday: TimeInterval {
        todayActivities.reduce(0) { $0 + $1.duration }
    }
    
    func exportForMindGrowee() {
        // Export JSON for MindGrowee import
        let exportData: [String: Any] = [
            "date": Date().timeIntervalSince1970,
            "activities": todayActivities.map { [
                "appName": $0.appName,
                "minutes": Int($0.duration / 60)
            ] }
        ]
        
        let desktop = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Desktop/activity_export.json")
        
        if let data = try? JSONSerialization.data(withJSONObject: exportData, options: .prettyPrinted) {
            try? data.write(to: desktop)
        }
    }
}

// MARK: - SwiftUI View
struct ActivityTrackerView: View {
    @ObservedObject var viewModel: ActivityViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            headerView
            
            Divider()
            
            ScrollView {
                VStack(spacing: 16) {
                    // Current Activity
                    if viewModel.isTracking {
                        currentActivityView
                    }
                    
                    // Total Time
                    totalTimeView
                    
                    // App List
                    Text("Top Apps")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    ForEach(viewModel.aggregatedByApp.prefix(6), id: \.0) { app, duration in
                        AppRowView(app: app, duration: duration, maxDuration: viewModel.aggregatedByApp.first?.value ?? 1)
                    }
                    
                    // Export Button
                    Button("Export for MindGrowee") {
                        viewModel.exportForMindGrowee()
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
            }
        }
        .frame(width: 380, height: 500)
    }
    
    var headerView: some View {
        HStack {
            Image(systemName: "chart.bar.fill")
                .font(.title2)
                .foregroundStyle(.blue)
            
            VStack(alignment: .leading) {
                Text("Activity Tracker")
                    .font(.headline)
                Text("Local Storage • Free")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Button(action: { viewModel.toggleTracking() }) {
                Image(systemName: viewModel.isTracking ? "stop.circle.fill" : "play.circle.fill")
                    .font(.title2)
                    .foregroundStyle(viewModel.isTracking ? .red : .green)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(.ultraThinMaterial)
    }
    
    var currentActivityView: some View {
        HStack {
            Image(systemName: "macwindow")
                .foregroundStyle(.blue)
            Text(viewModel.currentApp)
                .font(.headline)
            Spacer()
            Circle()
                .fill(.red)
                .frame(width: 8, height: 8)
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }
    
    var totalTimeView: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Today")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(formatDuration(viewModel.totalTimeToday))
                    .font(.title)
                    .fontWeight(.bold)
            }
            Spacer()
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }
    
    func formatDuration(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        return "\(hours)h \(minutes)m"
    }
}

struct AppRowView: View {
    let app: String
    let duration: TimeInterval
    let maxDuration: TimeInterval
    
    var body: some View {
        HStack {
            Text(app)
                .font(.system(size: 13))
            Spacer()
            Text(formatDuration(duration))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            GeometryReader { geo in
                RoundedRectangle(cornerRadius: 6)
                    .fill(.blue.opacity(0.2))
                    .frame(width: max(4, geo.size.width * CGFloat(duration / maxDuration)))
            }
        )
        .background(.ultraThinMaterial)
        .cornerRadius(6)
    }
    
    func formatDuration(_ interval: TimeInterval) -> String {
        let mins = Int(interval) / 60
        if mins < 60 {
            return "\(mins)m"
        } else {
            return "\(mins / 60)h \(mins % 60)m"
        }
    }
}

import AppKit
