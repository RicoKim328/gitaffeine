// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "gitaffeine",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "GitaffeineCore"),
        .executableTarget(name: "gitaffeine", dependencies: ["GitaffeineCore"]),
        .testTarget(name: "gitaffeineTests", dependencies: ["gitaffeine"]),
        .testTarget(name: "GitaffeineCoreTests", dependencies: ["GitaffeineCore"]),
    ]
)
