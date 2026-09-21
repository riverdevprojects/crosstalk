// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CrosstalkCore",
    platforms: [.macOS(.v13)],
    products: [.library(name: "CrosstalkCore", targets: ["CrosstalkCore"])],
    targets: [
        .target(name: "CrosstalkCore", path: "Crosstalk",
                exclude: ["Assets.xcassets", "Resources", "Info.plist", "ContentView.swift", "CrosstalkApp.swift", "GameStore.swift", "MPCSession.swift"],
                sources: ["Models.swift", "Engine.swift"]),
        .testTarget(name: "CrosstalkCoreTests", dependencies: ["CrosstalkCore"])
    ]
)
