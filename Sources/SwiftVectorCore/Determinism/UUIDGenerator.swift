//
//  UUIDGenerator.swift
//  SwiftVectorCore
//
//  Created by Stephen Sweeney
//  Copyright © 2026 Flightworks Aerial LLC. All rights reserved.
//

import Foundation

// MARK: - UUIDGenerator Protocol

/// Injectable UUID source for deterministic systems.
///
/// UUIDGenerator abstracts UUID creation so that:
/// - Production code generates random UUIDs
/// - Tests use predictable, sequential UUIDs
/// - Replay uses recorded identifiers
///
/// ## Why This Matters
/// Direct `UUID()` calls are hidden nondeterminism. Each call produces
/// a different identifier, breaking:
/// - Deterministic replay (IDs won't match)
/// - Test assertions (can't predict values)
/// - Audit trail correlation (can't reproduce sequences)
///
/// ## Usage
/// ```swift
/// struct ActionFactory {
///     let uuidGenerator: any UUIDGenerator
///
///     func createAction(_ type: ActionType) -> MyAction {
///         MyAction(id: uuidGenerator.next(), type: type)
///     }
/// }
///
/// // Production
/// let factory = ActionFactory(uuidGenerator: SystemUUIDGenerator())
///
/// // Test
/// let mockGenerator = MockUUIDGenerator(sequence: [knownUUID1, knownUUID2])
/// let factory = ActionFactory(uuidGenerator: mockGenerator)
/// ```
public protocol UUIDGenerator: Sendable {
    
    /// Generates the next UUID.
    ///
    /// Implementations must be safe to call from any actor or thread.
    /// The returned value depends on the implementation:
    /// - `SystemUUIDGenerator`: Random UUID
    /// - `MockUUIDGenerator`: Next UUID from a predefined sequence
    func next() -> UUID
}

// MARK: - SystemUUIDGenerator

/// UUIDGenerator implementation that creates random UUIDs.
///
/// Use this in production code. For tests, use `MockUUIDGenerator` from
/// `SwiftVectorTesting`.
///
/// ## Thread Safety
/// `SystemUUIDGenerator` is stateless and safe to use from any context.
/// Each call to `next()` produces an independent random UUID.
///
/// ## Example
/// ```swift
/// let generator = SystemUUIDGenerator()
/// let id1 = generator.next()  // Random UUID
/// let id2 = generator.next()  // Different random UUID
/// ```
public struct SystemUUIDGenerator: UUIDGenerator, Sendable {
    
    /// Creates a system UUID generator.
    public init() {}
    
    /// Generates a new random UUID.
    ///
    /// This is equivalent to `UUID()` but accessed through the
    /// `UUIDGenerator` protocol for dependency injection.
    public func next() -> UUID {
        UUID()
    }
}
