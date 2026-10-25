// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "gitaffeine",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "gitaffeine"),
        .testTarget(name: "gitaffeineTests", dependencies: ["gitaffeine"]),
    ]
)
