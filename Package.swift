// swift-tools-version:6.0
// ActivityTrackerApp - Native macOS SwiftUI App
// Shares Firebase with MindGrowee

import PackageDescription

let package = Package(
    name: "ActivityTracker",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "ActivityTracker", targets: ["ActivityTrackerApp"])
    ],
    dependencies: [
        .package(url: "https://github.com/firebase/firebase-ios-sdk", from: "10.0.0")
    ],
    targets: [
        .executableTarget(
            name: "ActivityTrackerApp",
            dependencies: [
                .product(name: "FirebaseFirestore", package: "firebase-ios-sdk"),
                .product(name: "FirebaseAuth", package: "firebase-ios-sdk")
            ],
            swiftSettings: [.swiftLanguageMode(.v6)]
        )
    ]
)
