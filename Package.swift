// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "thinkur",
    platforms: [
        .macOS("26.0")
    ],
    dependencies: [
        .package(url: "https://github.com/argmaxinc/WhisperKit.git", from: "0.9.0"),
        .package(url: "https://github.com/TelemetryDeck/SwiftSDK.git", from: "2.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "thinkur",
            dependencies: [
                .product(name: "WhisperKit", package: "WhisperKit"),
                .product(name: "TelemetryDeck", package: "SwiftSDK"),
            ],
            path: "Sources/thinkur",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),
        .testTarget(
            name: "thinkurTests",
            dependencies: ["thinkur"],
            path: "Tests/thinkurTests",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),
    ]
)
