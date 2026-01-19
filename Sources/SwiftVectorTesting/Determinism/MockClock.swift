//
//  MockClock.swift
//  SwiftVectorTesting
//
//  Created by Stephen Sweeney
//  Copyright © 2026 Flightworks Aerial LLC. All rights reserved.
//

import Foundation
import SwiftVectorCore

// MARK: - MockClock

/// A controllable clock for deterministic testing.
///
/// MockClock allows tests to:
/// - Start at a known time
/// - Advance time explicitly
/// - Verify time-dependent behavior without waiting
///
/// ## Thread Safety
/// MockClock uses a lock to ensure safe concurrent access.
/// It can be safely shared across actors in async tests.
///
/// ## Example
/// ```swift
/// @Test func testTimestampedEvents() async {
///     let epoch = Date(timeIntervalSince1970: 0)
///     let clock = MockClock(fixed: epoch)
///
///     let event1 = createEvent(clock: clock)
///     #expect(event1.timestamp == epoch)
///
///     clock.advance(by: 60)  // One minute later
///
///     let event2 = createEvent(clock: clock)
///     #expect(event2.timestamp == epoch.addingTimeInterval(60))
/// }
/// ```
public final class MockClock: Clock, @unchecked Sendable {
    
    private var current: Date
    private let lock = NSLock()
    
    /// Creates a mock clock starting at the specified time.
    ///
    /// - Parameter fixed: The initial time. Defaults to Unix epoch (1970-01-01 00:00:00 UTC).
    public init(fixed: Date = Date(timeIntervalSince1970: 0)) {
        self.current = fixed
    }
    
    /// Returns the current mock time.
    ///
    /// This value only changes when `advance(by:)` or `set(_:)` is called.
    public func now() -> Date {
        lock.withLock { current }
    }
    
    /// Advances the clock by the specified interval.
    ///
    /// - Parameter interval: The number of seconds to advance. Can be negative to go back.
    ///
    /// ## Example
    /// ```swift
    /// clock.advance(by: 3600)  // One hour later
    /// clock.advance(by: -60)   // One minute earlier (use carefully)
    /// ```
    public func advance(by interval: TimeInterval) {
        lock.withLock {
            current = current.addingTimeInterval(interval)
        }
    }
    
    /// Sets the clock to a specific time.
    ///
    /// - Parameter date: The new current time.
    ///
    /// ## Example
    /// ```swift
    /// clock.set(Date(timeIntervalSince1970: 1000000))
    /// ```
    public func set(_ date: Date) {
        lock.withLock {
            current = date
        }
    }
    
    /// Resets the clock to Unix epoch.
    public func reset() {
        set(Date(timeIntervalSince1970: 0))
    }
}
