//
//  RandomSource.swift
//  SwiftVectorCore
//
//  Created by Stephen Sweeney
//  Copyright © 2026 Flightworks Aerial LLC. All rights reserved.
//

import Foundation

// MARK: - RandomSource Protocol

/// Injectable random number source for deterministic systems.
///
/// RandomSource abstracts randomness so that:
/// - Production code uses system randomness
/// - Tests use seeded, reproducible sequences
/// - Replay uses recorded random values
///
/// ## Why This Matters
/// Direct use of `.random()` or `.randomElement()` is hidden nondeterminism.
/// Each run produces different values, breaking:
/// - Deterministic replay
/// - Test reproducibility
/// - Debugging (can't reproduce edge cases)
///
/// ## Usage
/// ```swift
/// struct StoryAgent {
///     let randomSource: any RandomSource
///
///     func selectFallbackAction() -> Action {
///         let index = randomSource.nextInt(in: 0..<possibleActions.count)
///         return possibleActions[index]
///     }
/// }
///
/// // Production
/// let agent = StoryAgent(randomSource: SystemRandomSource())
///
/// // Test - deterministic sequence
/// let mockRandom = MockRandomSource(intSequence: [0, 2, 1])
/// let agent = StoryAgent(randomSource: mockRandom)
/// ```
public protocol RandomSource: Sendable {
    
    /// Returns a random integer within the specified range.
    ///
    /// - Parameter range: The range of valid values (half-open)
    /// - Returns: A random integer where `range.lowerBound <= result < range.upperBound`
    /// - Precondition: `range` must not be empty
    func nextInt(in range: Range<Int>) -> Int
    
    /// Returns a random integer within the specified closed range.
    ///
    /// - Parameter range: The range of valid values (closed)
    /// - Returns: A random integer where `range.lowerBound <= result <= range.upperBound`
    /// - Precondition: `range` must not be empty
    func nextInt(in range: ClosedRange<Int>) -> Int
    
    /// Returns a random floating-point value between 0 and 1.
    ///
    /// - Returns: A value in the range `[0.0, 1.0)`
    func nextDouble() -> Double
    
    /// Returns a random boolean value.
    ///
    /// - Returns: `true` or `false` with equal probability
    func nextBool() -> Bool
}

// MARK: - Default Implementations

extension RandomSource {
    
    /// Default implementation using half-open range conversion.
    public func nextInt(in range: ClosedRange<Int>) -> Int {
        guard range.upperBound < Int.max else {
            precondition(range.lowerBound > Int.min,
                "RandomSource: ClosedRange spanning Int.min...Int.max is not supported")
            // Shift range down by 1, generate, shift result back up
            let shifted = (range.lowerBound - 1)...(range.upperBound - 1)
            return nextInt(in: shifted) + 1
        }
        return nextInt(in: range.lowerBound..<(range.upperBound + 1))
    }
    
    /// Default implementation using nextDouble.
    public func nextBool() -> Bool {
        nextDouble() < 0.5
    }
}

// MARK: - RandomSource Collection Extensions

extension RandomSource {
    
    /// Returns a random element from the collection.
    ///
    /// - Parameter collection: The collection to select from
    /// - Returns: A random element, or `nil` if the collection is empty
    public func randomElement<C: RandomAccessCollection>(from collection: C) -> C.Element? {
        guard !collection.isEmpty else { return nil }
        let offset = nextInt(in: 0..<collection.count)
        let index = collection.index(collection.startIndex, offsetBy: offset)
        return collection[index]
    }
    
    /// Shuffles the collection using this random source.
    ///
    /// - Parameter collection: The collection to shuffle
    /// - Returns: A new array with elements in random order
    public func shuffled<C: RandomAccessCollection>(_ collection: C) -> [C.Element] {
        var result = Array(collection)
        for i in stride(from: result.count - 1, through: 1, by: -1) {
            let j = nextInt(in: 0...i)
            result.swapAt(i, j)
        }
        return result
    }
}

// MARK: - SystemRandomSource

/// RandomSource implementation using system randomness.
///
/// Use this in production code. For tests, use `MockRandomSource` from
/// `SwiftVectorTesting`.
///
/// ## Thread Safety
/// `SystemRandomSource` is stateless and safe to use from any context.
/// It delegates to Swift's built-in random number generation.
///
/// ## Example
/// ```swift
/// let random = SystemRandomSource()
/// let diceRoll = random.nextInt(in: 1...6)
/// let coinFlip = random.nextBool()
/// ```
public struct SystemRandomSource: RandomSource, Sendable {
    
    /// Creates a system random source.
    public init() {}
    
    /// Returns a random integer within the specified range.
    public func nextInt(in range: Range<Int>) -> Int {
        Int.random(in: range)
    }
    
    /// Returns a random integer within the specified closed range.
    public func nextInt(in range: ClosedRange<Int>) -> Int {
        Int.random(in: range)
    }
    
    /// Returns a random floating-point value between 0 and 1.
    public func nextDouble() -> Double {
        Double.random(in: 0..<1)
    }
    
    /// Returns a random boolean value.
    public func nextBool() -> Bool {
        Bool.random()
    }
}
