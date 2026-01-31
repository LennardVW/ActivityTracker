// swift-tools-version:6.0
// ActivityTracker - Uses SAME Firebase backend as MindGrowee
// Free tier (Spark) - shared database

import PackageDescription

let package = Package(
    name: "ActivityTracker",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "activitytracker", targets: ["ActivityTracker"])
    ],
    dependencies: [
        // Firebase - same as MindGrowee
        .package(url: "https://github.com/firebase/firebase-ios-sdk", from: "10.0.0")
    ],
    targets: [
        .executableTarget(
            name: "ActivityTracker",
            dependencies: [
                .product(name: "FirebaseFirestore", package: "firebase-ios-sdk"),
                .product(name: "FirebaseAuth", package: "firebase-ios-sdk")
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableExperimentalFeature("StrictConcurrency")
            ]
        )
    ]
)
