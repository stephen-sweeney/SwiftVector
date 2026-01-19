// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftVector",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
        .tvOS(.v17),
        .watchOS(.v10),
        .visionOS(.v1)
    ],
    products: [
        // Core library: protocols, types, and determinism primitives
        .library(
            name: "SwiftVectorCore",
            targets: ["SwiftVectorCore"]
        ),
        // Testing utilities: mocks for deterministic testing
        .library(
            name: "SwiftVectorTesting",
            targets: ["SwiftVectorTesting"]
        ),
    ],
    dependencies: [
        // CryptoKit is available in Foundation on Apple platforms
        // No external dependencies for 0.1.0
    ],
    targets: [
        // MARK: - Core
        .target(
            name: "SwiftVectorCore",
            dependencies: [],
            path: "Sources/SwiftVectorCore"
        ),
        
        // MARK: - Testing Utilities
        .target(
            name: "SwiftVectorTesting",
            dependencies: ["SwiftVectorCore"],
            path: "Sources/SwiftVectorTesting"
        ),
        
        // MARK: - Tests
        .testTarget(
            name: "SwiftVectorCoreTests",
            dependencies: ["SwiftVectorCore", "SwiftVectorTesting"],
            path: "Tests/SwiftVectorCoreTests"
        ),
    ]
)
