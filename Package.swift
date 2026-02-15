// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "thinkur",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [
        .package(url: "https://github.com/argmaxinc/WhisperKit.git", from: "0.9.0"),
    ],
    targets: [
        .executableTarget(
            name: "thinkur",
            dependencies: [
                .product(name: "WhisperKit", package: "WhisperKit"),
            ],
            path: "Sources/thinkur"
        ),
        .testTarget(
            name: "thinkurTests",
            dependencies: ["thinkur"],
            path: "Tests/thinkurTests"
        ),
    ]
)
