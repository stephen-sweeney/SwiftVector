//
//  MockUUIDGenerator.swift
//  SwiftVectorTesting
//
//  Created by Stephen Sweeney
//  Copyright © 2026 Flightworks Aerial LLC. All rights reserved.
//

import Foundation
import SwiftVectorCore

// MARK: - MockUUIDGenerator

/// A controllable UUID generator for deterministic testing.
///
/// MockUUIDGenerator allows tests to:
/// - Provide a known sequence of UUIDs
/// - Verify UUID-dependent behavior deterministically
/// - Assert on the number of UUIDs consumed
///
/// ## Thread Safety
/// MockUUIDGenerator uses a lock to ensure safe concurrent access.
/// It can be safely shared across actors in async tests.
///
/// ## Example
/// ```swift
/// @Test func testActionCreation() async {
///     let id1 = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
///     let id2 = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
///     let generator = MockUUIDGenerator(sequence: [id1, id2])
///
///     let action1 = factory.createAction(uuidGenerator: generator)
///     let action2 = factory.createAction(uuidGenerator: generator)
///
///     #expect(action1.id == id1)
///     #expect(action2.id == id2)
///     #expect(generator.callCount == 2)
/// }
/// ```
public final class MockUUIDGenerator: UUIDGenerator, @unchecked Sendable {
    
    private var sequence: [UUID]
    private var index: Int = 0
    private let lock = NSLock()
    
    /// The number of times `next()` has been called.
    public var callCount: Int {
        lock.withLock { index }
    }
    
    /// Creates a mock generator with a predefined sequence.
    ///
    /// - Parameter sequence: The UUIDs to return, in order.
    /// - Precondition: If the sequence is exhausted, `next()` will crash.
    ///   Ensure the sequence has enough UUIDs for your test.
    public init(sequence: [UUID]) {
        self.sequence = sequence
    }
    
    /// Creates a mock generator that produces sequential UUIDs.
    ///
    /// Generates UUIDs in the form `00000000-0000-0000-0000-00000000000N`
    /// where N increments from the starting value.
    ///
    /// - Parameter startingFrom: The first sequential number. Defaults to 1.
    /// - Parameter count: How many UUIDs to generate. Defaults to 1000.
    public convenience init(sequential startingFrom: Int = 1, count: Int = 1000) {
        let sequence = (startingFrom..<(startingFrom + count)).map { n in
            UUID(uuidString: String(format: "00000000-0000-0000-0000-%012x", n))!
        }
        self.init(sequence: sequence)
    }
    
    /// Returns the next UUID in the sequence.
    ///
    /// - Precondition: The sequence must not be exhausted.
    ///   Call `remaining` to check how many UUIDs are left.
    public func next() -> UUID {
        lock.withLock {
            precondition(index < sequence.count,
                "MockUUIDGenerator exhausted: requested UUID \(index + 1) but only \(sequence.count) provided")
            let uuid = sequence[index]
            index += 1
            return uuid
        }
    }
    
    /// The number of UUIDs remaining in the sequence.
    public var remaining: Int {
        lock.withLock { sequence.count - index }
    }
    
    /// Resets the generator to the beginning of the sequence.
    public func reset() {
        lock.withLock { index = 0 }
    }
    
    /// Appends additional UUIDs to the sequence.
    ///
    /// - Parameter uuids: The UUIDs to add.
    public func append(_ uuids: [UUID]) {
        lock.withLock {
            sequence.append(contentsOf: uuids)
        }
    }
}
