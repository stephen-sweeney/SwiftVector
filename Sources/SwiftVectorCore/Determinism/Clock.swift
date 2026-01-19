//
//  Clock.swift
//  SwiftVectorCore
//
//  Created by Stephen Sweeney
//  Copyright © 2026 Flightworks Aerial LLC. All rights reserved.
//

import Foundation

// MARK: - Clock Protocol

/// Injectable time source for deterministic systems.
///
/// Clock abstracts time access so that:
/// - Production code uses real system time
/// - Tests use controllable, predictable time
/// - Replay uses recorded timestamps
///
/// ## Why This Matters
/// Direct `Date()` calls are hidden nondeterminism. Two runs of the same
/// code produce different timestamps, breaking:
/// - Deterministic replay
/// - Test reproducibility
/// - Audit trail verification
///
/// ## Usage
/// ```swift
/// struct MyOrchestrator {
///     let clock: any Clock
///
///     func recordEvent() -> AuditEntry {
///         AuditEntry(timestamp: clock.now(), ...)
///     }
/// }
///
/// // Production
/// let orchestrator = MyOrchestrator(clock: SystemClock())
///
/// // Test
/// let mockClock = MockClock(fixed: Date(timeIntervalSince1970: 0))
/// let orchestrator = MyOrchestrator(clock: mockClock)
/// ```
public protocol Clock: Sendable {
    
    /// Returns the current time.
    ///
    /// Implementations must be safe to call from any actor or thread.
    /// The returned value should be consistent with the implementation's
    /// time model (system time, fixed time, advancing mock, etc.).
    func now() -> Date
}

// MARK: - SystemClock

/// Clock implementation that returns real system time.
///
/// Use this in production code. For tests, use `MockClock` from
/// `SwiftVectorTesting`.
///
/// ## Thread Safety
/// `SystemClock` is stateless and safe to use from any context.
///
/// ## Example
/// ```swift
/// let clock = SystemClock()
/// let timestamp = clock.now()  // Current system time
/// ```
public struct SystemClock: Clock, Sendable {
    
    /// Creates a system clock.
    public init() {}
    
    /// Returns the current system time.
    ///
    /// This is equivalent to `Date()` but accessed through the
    /// `Clock` protocol for dependency injection.
    public func now() -> Date {
        Date()
    }
}
