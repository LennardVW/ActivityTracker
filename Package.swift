// swift-tools-version:6.0
// ActivityTracker - Beautiful activity tracking for macOS
// Tracks app usage with gorgeous visualizations
// Connects to MindGrowee for habit correlation

import PackageDescription

let package = Package(
    name: "ActivityTracker",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "activitytracker", targets: ["ActivityTracker"]),
        .library(name: "ActivityWidgets", targets: ["ActivityWidgets"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "ActivityTracker",
            dependencies: ["ActivityWidgets"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .target(
            name: "ActivityWidgets",
            swiftSettings: [.swiftLanguageMode(.v6)]
        )
    ]
)
