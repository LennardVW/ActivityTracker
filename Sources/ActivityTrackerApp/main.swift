import SwiftUI
import FirebaseCore
import FirebaseFirestore
import FirebaseAuth

// MARK: - ActivityTracker App
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
        // Setup Firebase
        FirebaseApp.configure()
        
        // Setup Menu Bar
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

// MARK: - ViewModel
@MainActor
class ActivityViewModel: ObservableObject {
    @Published var isTracking = false
    @Published var currentApp = ""
    @Published var todaySessions: [ActivitySession] = []
    @Published var isLoggedIn = false
    @Published var userEmail = ""
    
    private var db = Firestore.firestore()
    private var trackingTimer: Timer?
    private var currentSession: ActivitySession?
    
    struct ActivitySession: Identifiable, Codable {
        let id: String
        let appName: String
        let bundleId: String
        let startTime: Date
        var endTime: Date?
        
        var duration: TimeInterval {
            endTime?.timeIntervalSince(startTime) ?? Date().timeIntervalSince(startTime)
        }
        
        var formattedDuration: String {
            let mins = Int(duration) / 60
            if mins < 60 {
                return "\(mins)m"
            } else {
                let hours = mins / 60
                let remainingMins = mins % 60
                return "\(hours)h \(remainingMins)m"
            }
        }
    }
    
    func login(email: String, password: String) async {
        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            isLoggedIn = true
            userEmail = email
            await loadTodaySessions()
        } catch {
            print("Login failed: \(error)")
        }
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
        
        if let session = currentSession {
            saveSession(session)
            currentSession = nil
        }
    }
    
    func trackCurrentApp() {
        guard let app = NSWorkspace.shared.frontmostApplication else { return }
        
        let appName = app.localizedName ?? "Unknown"
        let bundleId = app.bundleIdentifier ?? "unknown"
        
        if let current = currentSession, current.bundleId != bundleId {
            var ended = current
            ended.endTime = Date()
            saveSession(ended)
            currentSession = nil
        }
        
        if currentSession == nil {
            currentSession = ActivitySession(
                id: UUID().uuidString,
                appName: appName,
                bundleId: bundleId,
                startTime: Date(),
                endTime: nil
            )
        }
        
        currentApp = appName
    }
    
    func saveSession(_ session: ActivitySession) {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        let data: [String: Any] = [
            "id": session.id,
            "appName": session.appName,
            "bundleId": session.bundleId,
            "startTime": Timestamp(date: session.startTime),
            "endTime": session.endTime.map { Timestamp(date: $0) } ?? NSNull(),
            "duration": session.duration
        ]
        
        db.collection("users").document(userId).collection("activity")
            .document(session.id).setData(data)
        
        // Update local
        todaySessions.append(session)
    }
    
    func loadTodaySessions() async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        
        do {
            let snapshot = try await db.collection("users")
                .document(userId)
                .collection("activity")
                .whereField("startTime", isGreaterThanOrEqualTo: Timestamp(date: startOfDay))
                .getDocuments()
            
            todaySessions = snapshot.documents.compactMap { doc in
                let data = doc.data()
                guard let appName = data["appName"] as? String,
                      let startTimestamp = data["startTime"] as? Timestamp else { return nil }
                
                return ActivitySession(
                    id: doc.documentID,
                    appName: appName,
                    bundleId: data["bundleId"] as? String ?? "",
                    startTime: startTimestamp.dateValue(),
                    endTime: (data["endTime"] as? Timestamp)?.dateValue()
                )
            }
        } catch {
            print("Failed to load: \(error)")
        }
    }
    
    var aggregatedByApp: [(String, TimeInterval)] {
        var totals: [String: TimeInterval] = [:]
        for session in todaySessions {
            totals[session.appName, default: 0] += session.duration
        }
        return totals.sorted { $0.value > $1.value }
    }
    
    var totalTimeToday: TimeInterval {
        todaySessions.reduce(0) { $0 + $1.duration }
    }
}

// MARK: - SwiftUI View
struct ActivityTrackerView: View {
    @ObservedObject var viewModel: ActivityViewModel
    @State private var email = ""
    @State private var password = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            Divider()
            
            if !viewModel.isLoggedIn {
                loginView
            } else {
                trackingView
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
                if viewModel.isLoggedIn {
                    Text(viewModel.userEmail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            if viewModel.isLoggedIn {
                Button(action: { viewModel.toggleTracking() }) {
                    Image(systemName: viewModel.isTracking ? "stop.circle.fill" : "play.circle.fill")
                        .font(.title2)
                        .foregroundStyle(viewModel.isTracking ? .red : .green)
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
    }
    
    var loginView: some View {
        VStack(spacing: 20) {
            Text("Sign in with MindGrowee")
                .font(.headline)
            
            TextField("Email", text: $email)
                .textFieldStyle(.roundedBorder)
            
            SecureField("Password", text: $password)
                .textFieldStyle(.roundedBorder)
            
            Button("Sign In") {
                Task {
                    await viewModel.login(email: email, password: password)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(email.isEmpty || password.isEmpty)
            
            Spacer()
        }
        .padding()
    }
    
    var trackingView: some View {
        VStack(spacing: 16) {
            // Current Activity
            if viewModel.isTracking {
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
            
            // Total Time
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
            
            // App List
            Text("Top Apps")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(viewModel.aggregatedByApp.prefix(6), id: \.0) { app, duration in
                        AppRowView(app: app, duration: duration, maxDuration: viewModel.aggregatedByApp.first?.value ?? 1)
                    }
                }
            }
            
            Spacer()
        }
        .padding()
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
