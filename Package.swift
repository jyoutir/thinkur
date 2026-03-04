// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "thinkur",
    platforms: [
        .macOS("15.0")
    ],
    dependencies: [
        .package(url: "https://github.com/FluidInference/FluidAudio.git", from: "0.12.1"),
        .package(url: "https://github.com/TelemetryDeck/SwiftSDK.git", from: "2.0.0"),
        .package(url: "https://github.com/sparkle-project/Sparkle.git", from: "2.6.0"),
        .package(url: "https://github.com/modelcontextprotocol/swift-sdk.git", from: "0.11.0"),
    ],
    targets: [
        .executableTarget(
            name: "thinkur",
            dependencies: [
                .product(name: "FluidAudio", package: "FluidAudio"),
                .product(name: "TelemetryDeck", package: "SwiftSDK"),
                .product(name: "Sparkle", package: "Sparkle"),
            ],
            path: "Sources/thinkur",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),
        .executableTarget(
            name: "thinkur-mcp",
            dependencies: [
                .product(name: "MCP", package: "swift-sdk"),
            ],
            path: "Sources/thinkur-mcp",
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
        .testTarget(
            name: "thinkurMCPTests",
            dependencies: [
                "thinkur-mcp",
                .product(name: "MCP", package: "swift-sdk"),
            ],
            path: "Tests/thinkurMCPTests",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),
    ]
)
