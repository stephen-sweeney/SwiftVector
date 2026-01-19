//
//  MockRandomSource.swift
//  SwiftVectorTesting
//
//  Created by Stephen Sweeney
//  Copyright © 2026 Flightworks Aerial LLC. All rights reserved.
//

import Foundation
import SwiftVectorCore

// MARK: - MockRandomSource

/// A controllable random source for deterministic testing.
///
/// MockRandomSource allows tests to:
/// - Provide known sequences of random values
/// - Use a seeded generator for reproducible randomness
/// - Verify random-dependent behavior deterministically
///
/// ## Thread Safety
/// MockRandomSource uses a lock to ensure safe concurrent access.
/// It can be safely shared across actors in async tests.
///
/// ## Example: Fixed Sequence
/// ```swift
/// @Test func testFallbackSelection() async {
///     // Always select index 2, then 0, then 1
///     let random = MockRandomSource(intSequence: [2, 0, 1])
///
///     let first = agent.selectFallback(randomSource: random)
///     let second = agent.selectFallback(randomSource: random)
///
///     #expect(first == possibleActions[2])
///     #expect(second == possibleActions[0])
/// }
/// ```
///
/// ## Example: Seeded Generator
/// ```swift
/// @Test func testShuffling() async {
///     let random = MockRandomSource(seed: 42)
///
///     let result1 = random.shuffled([1, 2, 3, 4, 5])
///     
///     random.reset()  // Same seed produces same sequence
///     let result2 = random.shuffled([1, 2, 3, 4, 5])
///
///     #expect(result1 == result2)
/// }
/// ```
public final class MockRandomSource: RandomSource, @unchecked Sendable {
    
    private var intSequence: [Int]
    private var doubleSequence: [Double]
    private var intIndex: Int = 0
    private var doubleIndex: Int = 0
    private var seededGenerator: SeededGenerator?
    private let lock = NSLock()
    
    // MARK: - Initialization
    
    /// Creates a mock random source with fixed sequences.
    ///
    /// - Parameters:
    ///   - intSequence: Integers to return from `nextInt(in:)`. Values are clamped to requested ranges.
    ///   - doubleSequence: Doubles to return from `nextDouble()`. Should be in `[0, 1)`.
    public init(intSequence: [Int] = [], doubleSequence: [Double] = []) {
        self.intSequence = intSequence
        self.doubleSequence = doubleSequence
        self.seededGenerator = nil
    }
    
    /// Creates a mock random source with a seeded generator.
    ///
    /// The same seed always produces the same sequence of values,
    /// making tests reproducible across runs.
    ///
    /// - Parameter seed: The random seed.
    public init(seed: UInt64) {
        self.intSequence = []
        self.doubleSequence = []
        self.seededGenerator = SeededGenerator(seed: seed)
    }
    
    // MARK: - RandomSource Protocol
    
    /// Returns the next integer, clamped to the specified range.
    public func nextInt(in range: Range<Int>) -> Int {
        lock.withLock {
            if let generator = seededGenerator {
                return generator.nextInt(in: range)
            }
            
            precondition(intIndex < intSequence.count,
                "MockRandomSource int sequence exhausted: requested index \(intIndex) but only \(intSequence.count) provided")
            
            let value = intSequence[intIndex]
            intIndex += 1
            
            // Clamp to range
            return min(max(value, range.lowerBound), range.upperBound - 1)
        }
    }
    
    /// Returns the next integer, clamped to the specified closed range.
    public func nextInt(in range: ClosedRange<Int>) -> Int {
        lock.withLock {
            if let generator = seededGenerator {
                return generator.nextInt(in: range)
            }
            
            precondition(intIndex < intSequence.count,
                "MockRandomSource int sequence exhausted: requested index \(intIndex) but only \(intSequence.count) provided")
            
            let value = intSequence[intIndex]
            intIndex += 1
            
            // Clamp to range
            return min(max(value, range.lowerBound), range.upperBound)
        }
    }
    
    /// Returns the next double value.
    public func nextDouble() -> Double {
        lock.withLock {
            if let generator = seededGenerator {
                return generator.nextDouble()
            }
            
            precondition(doubleIndex < doubleSequence.count,
                "MockRandomSource double sequence exhausted: requested index \(doubleIndex) but only \(doubleSequence.count) provided")
            
            let value = doubleSequence[doubleIndex]
            doubleIndex += 1
            return value
        }
    }
    
    /// Returns the next boolean value.
    public func nextBool() -> Bool {
        nextDouble() < 0.5
    }
    
    // MARK: - Test Utilities
    
    /// The number of integers consumed from the sequence.
    public var intCallCount: Int {
        lock.withLock { intIndex }
    }
    
    /// The number of doubles consumed from the sequence.
    public var doubleCallCount: Int {
        lock.withLock { doubleIndex }
    }
    
    /// Resets the generator to the beginning of sequences or reseeds.
    public func reset() {
        lock.withLock {
            intIndex = 0
            doubleIndex = 0
            seededGenerator?.reset()
        }
    }
}

// MARK: - SeededGenerator

/// A simple seeded random number generator using xorshift64.
///
/// This provides reproducible randomness for testing without
/// depending on platform-specific implementations.
private final class SeededGenerator {
    
    private let initialSeed: UInt64
    private var state: UInt64
    
    init(seed: UInt64) {
        // Ensure non-zero state (xorshift requires this)
        self.initialSeed = seed == 0 ? 1 : seed
        self.state = self.initialSeed
    }
    
    func reset() {
        state = initialSeed
    }
    
    /// xorshift64 algorithm - simple, fast, deterministic
    private func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
    
    func nextInt(in range: Range<Int>) -> Int {
        precondition(!range.isEmpty, "RandomSource: range must not be empty")
        let lower = UInt(bitPattern: range.lowerBound)
        let upper = UInt(bitPattern: range.upperBound)
        let span = upper &- lower
        let offset = next() % UInt64(span)
        return range.lowerBound &+ Int(truncatingIfNeeded: offset)
    }

    func nextInt(in range: ClosedRange<Int>) -> Int {
        precondition(!range.isEmpty, "RandomSource: range must not be empty")
        let lower = UInt(bitPattern: range.lowerBound)
        let upper = UInt(bitPattern: range.upperBound)
        let span = upper &- lower &+ 1
        let offset = next() % UInt64(span)
        return range.lowerBound &+ Int(truncatingIfNeeded: offset)
    }
    
    func nextDouble() -> Double {
        Double(next()) / (Double(UInt64.max) + 1.0) // [0, 1)
    }
}
