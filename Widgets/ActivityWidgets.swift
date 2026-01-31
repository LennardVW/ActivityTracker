import SwiftUI

// MARK: - Activity Widgets
/// Widgets for ActivityTracker
/// Can be used in Menu Bar or Today View

public struct ActivityWidgetView: View {
    public let appName: String
    public let duration: TimeInterval
    
    public init(appName: String, duration: TimeInterval) {
        self.appName = appName
        self.duration = duration
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "macwindow")
                    .foregroundStyle(.blue)
                Text(appName)
                    .font(.headline)
            }
            
            Text(formatDuration(duration))
                .font(.title2)
                .fontWeight(.bold)
            
            ProgressView(value: min(duration / 3600, 1.0))
                .progressViewStyle(.linear)
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }
    
    func formatDuration(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

public struct DailySummaryWidget: View {
    public let totalTime: TimeInterval
    public let topApps: [(String, TimeInterval)]
    
    public init(totalTime: TimeInterval, topApps: [(String, TimeInterval)]) {
        self.totalTime = totalTime
        self.topApps = topApps
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.pie.fill")
                    .foregroundStyle(.green)
                Text("Today")
                    .font(.headline)
                Spacer()
                Text(formatDuration(totalTime))
                    .font(.title3)
                    .fontWeight(.bold)
            }
            
            Divider()
            
            ForEach(topApps.prefix(3), id: \.0) { app, time in
                HStack {
                    Text(app)
                        .font(.caption)
                    Spacer()
                    Text(formatDuration(time))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
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

#Preview {
    VStack {
        ActivityWidgetView(appName: "Xcode", duration: 7200)
        DailySummaryWidget(
            totalTime: 28800,
            topApps: [("Xcode", 14400), ("Safari", 7200), ("Slack", 3600)]
        )
    }
    .padding()
}
