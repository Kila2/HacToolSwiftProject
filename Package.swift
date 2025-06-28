// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "HactoolSwift",
    platforms: [
        .macOS(.v12)
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0"),
        .package(url: "https://github.com/krzyzanowskim/CryptoSwift.git", from: "1.8.0"),
        .package(name: "mbedtls", path: "../mbedtls")
    ],
    targets: [
        .executableTarget(
            name: "HactoolSwift",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                "CryptoSwift",
                .product(name: "MbedTLS", package: "mbedtls")
            ],
            path: "Sources/HactoolSwift"
        ),
        .testTarget(
            name: "HactoolSwiftTests",
            dependencies: ["HactoolSwift"],
            path: "Tests",
            resources: [.copy("Resources")]
        ),
    ]
)
