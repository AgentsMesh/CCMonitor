// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "CCMonitor",
    platforms: [
        .macOS(.v14),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-log.git", from: "1.5.0"),
    ],
    targets: [
        .executableTarget(
            name: "CCMonitor",
            dependencies: [
                .product(name: "Logging", package: "swift-log"),
            ],
            path: "Sources/CCMonitor",
            resources: [
                .process("Resources"),
            ]
        ),
        .testTarget(
            name: "CCMonitorTests",
            dependencies: ["CCMonitor"],
            path: "Tests/CCMonitorTests"
        ),
    ]
)
