// swift-tools-version:6.0
// ActivityTracker - Local/iCloud storage (FREE)
// No Firebase costs

import PackageDescription

let package = Package(
    name: "ActivityTracker",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "ActivityTracker", targets: ["ActivityTrackerApp"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "ActivityTrackerApp",
            swiftSettings: [.swiftLanguageMode(.v6)]
        )
    ]
)
