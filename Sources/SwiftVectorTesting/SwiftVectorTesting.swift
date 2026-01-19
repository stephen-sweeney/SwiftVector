//
//  SwiftVectorTesting.swift
//  SwiftVectorTesting
//
//  Created by Stephen Sweeney
//  Copyright © 2026 Flightworks Aerial LLC. All rights reserved.
//

// MARK: - SwiftVectorTesting
//
// Testing utilities for SwiftVectorCore.
//
// This module provides mock implementations of determinism primitives,
// allowing tests to control time, UUIDs, and randomness for reproducible
// test execution.
//
// ## Mock Types
// - `MockClock`: Controllable time source
// - `MockUUIDGenerator`: Predictable UUID sequences
// - `MockRandomSource`: Seeded or sequenced random values
//
// ## Usage
// ```swift
// import SwiftVectorCore
// import SwiftVectorTesting
//
// @Test func testDeterministicReplay() async {
//     let clock = MockClock(fixed: Date(timeIntervalSince1970: 0))
//     let uuids = MockUUIDGenerator(sequential: 1)
//     let random = MockRandomSource(seed: 42)
//
//     let orchestrator = MyOrchestrator(
//         clock: clock,
//         uuidGenerator: uuids,
//         randomSource: random
//     )
//
//     // Run test with predictable time, IDs, and randomness
//     await orchestrator.advanceStory()
//
//     // Advance time explicitly
//     clock.advance(by: 60)
//
//     // Reset for replay verification
//     clock.reset()
//     uuids.reset()
//     random.reset()
// }
// ```
//
// ## Design Principles
// - All mocks are thread-safe (use NSLock internally)
// - All mocks conform to `@unchecked Sendable` for actor compatibility
// - Sequences exhaustion produces clear precondition failures
// - Reset methods enable replay verification in tests

@_exported import SwiftVectorCore

/// SwiftVectorTesting version (matches Core)
public let swiftVectorTestingVersion = "0.1.0"
