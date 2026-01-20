//
//  EventLog.swift
//  SwiftVectorCore
//
//  Created by Stephen Sweeney
//  Copyright © 2026 Flightworks Aerial LLC. All rights reserved.
//

import Foundation

// MARK: - EventLogVerificationResult

/// Result of verifying an event log's integrity.
///
/// Returned by `EventLog.verify()` and `EventLog.verifyReplay()` to indicate
/// whether the log's hash chain and state continuity are intact.
///
/// ## Usage
/// ```swift
/// let result = log.verify()
/// if result.isValid {
///     print("Log integrity confirmed")
/// } else {
///     print("Chain broken at index \(result.brokenAtIndex!): \(result.failureReason!)")
/// }
/// ```
public struct EventLogVerificationResult: Sendable, Equatable {
    
    /// Whether the entire chain is valid.
    public let isValid: Bool
    
    /// The index where the chain first breaks, if invalid.
    ///
    /// `nil` if the chain is valid.
    public let brokenAtIndex: Int?
    
    /// Description of the verification failure, if any.
    ///
    /// `nil` if the chain is valid.
    public let failureReason: String?
    
    /// A valid verification result.
    public static let valid = EventLogVerificationResult(
        isValid: true,
        brokenAtIndex: nil,
        failureReason: nil
    )
    
    /// Creates a failure result.
    ///
    /// - Parameters:
    ///   - atIndex: The index where verification failed
    ///   - reason: Human-readable explanation of the failure
    /// - Returns: An invalid verification result
    public static func invalid(atIndex: Int, reason: String) -> EventLogVerificationResult {
        EventLogVerificationResult(
            isValid: false,
            brokenAtIndex: atIndex,
            failureReason: reason
        )
    }
}

// MARK: - EventLog

/// An append-only audit log with tamper-evident hash chain verification.
///
/// `EventLog` maintains an ordered sequence of `AuditEvent` entries with
/// integrity guarantees:
/// - Events can only be appended, never modified or removed
/// - Each event's `previousEntryHash` must match the previous event's `entryHash`
/// - Each event's `stateHashBefore` must match the previous event's `stateHashAfter`
/// - The chain can be verified at any time to detect tampering
///
/// ## Hash Chain
/// Each entry contains a cryptographic hash of its content plus the previous
/// entry's hash. This forms a tamper-evident chain:
/// ```
/// Entry 0: entryHash = SHA256(content + "")
/// Entry 1: entryHash = SHA256(content + Entry0.entryHash)
/// Entry 2: entryHash = SHA256(content + Entry1.entryHash)
/// ```
///
/// Modifying any field in any entry changes its `entryHash`, which invalidates
/// all subsequent `previousEntryHash` references. This makes tampering detectable.
///
/// ## Usage
/// ```swift
/// var log = EventLog<GameAction>()
///
/// // Append initialization event
/// log.append(.initialization(
///     id: uuidGenerator.next(),
///     timestamp: clock.now(),
///     initialStateHash: state.stateHash()
/// ))
///
/// // Append action events as they occur
/// log.append(.accepted(
///     id: uuidGenerator.next(),
///     timestamp: clock.now(),
///     action: .move,
///     agentID: "player-agent",
///     stateHashBefore: oldHash,
///     stateHashAfter: newHash,
///     rationale: "Moved to forest",
///     previousEntryHash: ""  // Set automatically by append()
/// ))
///
/// // Verify chain integrity
/// let result = log.verify()
/// if !result.isValid {
///     print("Chain broken at index \(result.brokenAtIndex!)")
/// }
/// ```
///
/// ## Replay Support
/// The log provides `actions()` to extract just the actions for replay:
/// ```swift
/// for (action, agentID) in log.actions() {
///     await orchestrator.replay(action, from: agentID)
/// }
/// ```
///
/// ## Serialization
/// `EventLog` conforms to `Codable` for persistence. The entire log can be
/// serialized to JSON and restored later with full integrity verification.
public struct EventLog<A: Action>: Sendable {
    
    /// The ordered sequence of audit events.
    public private(set) var entries: [AuditEvent<A>]
    
    /// Creates an empty event log.
    public init() {
        self.entries = []
    }
    
    /// Creates an event log with existing entries.
    ///
    /// - Parameter entries: The entries to initialize with
    ///
    /// - Note: This does not verify the chain. Call `verify()` after
    ///   construction if integrity must be confirmed.
    public init(entries: [AuditEvent<A>]) {
        self.entries = entries
    }
    
    /// The number of events in the log.
    public var count: Int {
        entries.count
    }
    
    /// Whether the log is empty.
    public var isEmpty: Bool {
        entries.isEmpty
    }
    
    /// The first event in the log (typically initialization).
    public var first: AuditEvent<A>? {
        entries.first
    }
    
    /// The most recent event in the log.
    public var last: AuditEvent<A>? {
        entries.last
    }
    
    /// The hash of the current state (from the last event).
    ///
    /// Returns `nil` if the log is empty.
    public var currentStateHash: String? {
        entries.last?.stateHashAfter
    }
    
    /// The entry hash of the last event (for chaining).
    ///
    /// Returns empty string if the log is empty.
    public var lastEntryHash: String {
        entries.last?.entryHash ?? ""
    }
}

// MARK: - Appending

extension EventLog {
    
    /// Appends an event to the log, automatically setting the hash chain link.
    ///
    /// - Parameter event: The event to append
    ///
    /// The event's `previousEntryHash` is set to the last entry's `entryHash`,
    /// forming the tamper-evident chain. Any value in `event.previousEntryHash`
    /// is replaced.
    public mutating func append(_ event: AuditEvent<A>) {
        let linkedEvent = AuditEvent<A>(
            id: event.id,
            timestamp: event.timestamp,
            eventType: event.eventType,
            stateHashBefore: event.stateHashBefore,
            stateHashAfter: event.stateHashAfter,
            applied: event.applied,
            rationale: event.rationale,
            previousEntryHash: lastEntryHash
        )
        entries.append(linkedEvent)
    }
    
    /// Appends an event, validating both state continuity and hash chain.
    ///
    /// - Parameter event: The event to append
    /// - Throws: `EventLogError.chainDiscontinuity` if the event's
    ///   `stateHashBefore` doesn't match the log's current state hash
    ///
    /// Use this method when strict integrity is required. For bulk
    /// imports or replay scenarios where you'll verify later, use
    /// `append(_:)` instead.
    public mutating func appendValidating(_ event: AuditEvent<A>) throws {
        if let lastHash = currentStateHash {
            guard event.stateHashBefore == lastHash else {
                throw EventLogError.chainDiscontinuity(
                    expected: lastHash,
                    found: event.stateHashBefore,
                    atIndex: entries.count
                )
            }
        }
        append(event)
    }
}

// MARK: - Verification

extension EventLog {
    /// Verifies the integrity of both state continuity and hash chain.
    ///
    /// Checks that:
    /// 1. Each event's `stateHashBefore` matches the previous event's `stateHashAfter`
    /// 2. Each event's `previousEntryHash` matches the previous event's `entryHash`
    /// 3. The first entry has an empty `previousEntryHash`
    ///
    /// - Returns: An `EventLogVerificationResult` indicating whether the chain is valid
    ///
    /// ## Complexity
    /// O(n) where n is the number of entries.
    public func verify() -> EventLogVerificationResult {
        guard !entries.isEmpty else {
            return .valid
        }
        
        // First entry should have empty previousEntryHash
        if !entries[0].previousEntryHash.isEmpty {
            return .invalid(
                atIndex: 0,
                reason: "First entry should have empty previousEntryHash but has '\(entries[0].previousEntryHash)'"
            )
        }
        
        for i in 1..<entries.count {
            let previous = entries[i - 1]
            let current = entries[i]
            
            // Check state hash continuity
            if current.stateHashBefore != previous.stateHashAfter {
                return .invalid(
                    atIndex: i,
                    reason: "State hash mismatch: expected '\(previous.stateHashAfter)' but found '\(current.stateHashBefore)'"
                )
            }
            
            // Check hash chain integrity (tamper detection)
            if current.previousEntryHash != previous.entryHash {
                return .invalid(
                    atIndex: i,
                    reason: "Hash chain broken: expected '\(previous.entryHash)' but found '\(current.previousEntryHash)'"
                )
            }
        }
        
        return .valid
    }
    
    /// Verifies that replaying actions produces the recorded state hashes.
    ///
    /// This is a stronger verification than `verify()`. It actually replays
    /// each action through the provided reducer and confirms the resulting
    /// state hash matches what was recorded.
    ///
    /// - Parameters:
    ///   - initialState: The starting state for replay
    ///   - reducer: The reducer to use for replay
    /// - Returns: An `EventLogVerificationResult` indicating whether replay matches
    ///
    /// ## Event Type Handling
    /// - `initialization`: Validates hash matches initial state
    /// - `actionProposed`: Replays through reducer and validates result
    /// - `systemEvent`: Validates state unchanged (hashBefore == hashAfter)
    /// - `stateRestored`: Cannot verify without snapshot; returns invalid
    ///
    /// ## Complexity
    /// O(n) where n is the number of entries, plus the cost of each reduce.
    public func verifyReplay<S: State, R: Reducer>(
        initialState: S,
        reducer: R
    ) -> EventLogVerificationResult where R.S == S, R.A == A {
        let chainResult = verify()
        guard chainResult.isValid else {
            return chainResult
        }

        var state = initialState
        
        for (index, entry) in entries.enumerated() {
            let computedHashBefore = state.stateHash()
            
            switch entry.eventType {
            case .initialization:
                // First entry: stateHashBefore is empty, stateHashAfter should match initial state
                if index == 0 {
                    if entry.stateHashAfter != computedHashBefore {
                        return .invalid(
                            atIndex: index,
                            reason: "Initialization hash mismatch: computed '\(computedHashBefore)' but log has '\(entry.stateHashAfter)'"
                        )
                    }
                } else {
                    // Initialization mid-log is unusual but validate hashes match
                    if entry.stateHashBefore != computedHashBefore {
                        return .invalid(
                            atIndex: index,
                            reason: "Pre-state hash mismatch at initialization: computed '\(computedHashBefore)' but log has '\(entry.stateHashBefore)'"
                        )
                    }
                }
                
            case .actionProposed(let action, _):
                // Verify state hash before
                if computedHashBefore != entry.stateHashBefore {
                    return .invalid(
                        atIndex: index,
                        reason: "Pre-state hash mismatch: computed '\(computedHashBefore)' but log has '\(entry.stateHashBefore)'"
                    )
                }
                
                // Apply action through reducer
                let result = reducer.reduce(state: state, action: action)
                
                // Verify applied flag matches
                if result.applied != entry.applied {
                    return .invalid(
                        atIndex: index,
                        reason: "Applied flag mismatch: reducer returned \(result.applied) but log has \(entry.applied)"
                    )
                }
                
                // Update state if applied
                if result.applied {
                    state = result.newState
                }
                
                // Verify state hash after
                let computedHashAfter = state.stateHash()
                if computedHashAfter != entry.stateHashAfter {
                    return .invalid(
                        atIndex: index,
                        reason: "Post-state hash mismatch: computed '\(computedHashAfter)' but log has '\(entry.stateHashAfter)'"
                    )
                }
                
            case .stateRestored(let source):
                // Cannot replay state restoration without the snapshot
                return .invalid(
                    atIndex: index,
                    reason: "Cannot verify replay across stateRestored event (source: \(source)) without snapshot"
                )
                
            case .systemEvent(let description):
                // System events should not change state
                if entry.stateHashBefore != entry.stateHashAfter {
                    return .invalid(
                        atIndex: index,
                        reason: "System event '\(description)' has mismatched hashes: before='\(entry.stateHashBefore)' after='\(entry.stateHashAfter)'"
                    )
                }
                
                // Verify recorded hash matches computed state
                if entry.stateHashBefore != computedHashBefore {
                    return .invalid(
                        atIndex: index,
                        reason: "System event hash mismatch: computed '\(computedHashBefore)' but log has '\(entry.stateHashBefore)'"
                    )
                }
            }
        }
        
        return .valid
    }
}

// MARK: - Querying

extension EventLog {
    
    /// Returns all proposed actions with their agent IDs.
    ///
    /// Filters to only `actionProposed` events and extracts the action
    /// and agent ID. Useful for replay scenarios.
    ///
    /// - Returns: Array of (action, agentID) tuples in log order
    public func actions() -> [(action: A, agentID: String)] {
        entries.compactMap { entry in
            if case .actionProposed(let action, let agentID) = entry.eventType {
                return (action, agentID)
            }
            return nil
        }
    }
    
    /// Returns only the accepted actions.
    ///
    /// - Returns: Array of (action, agentID) tuples for applied actions
    public func acceptedActions() -> [(action: A, agentID: String)] {
        entries.compactMap { entry in
            guard entry.applied,
                  case .actionProposed(let action, let agentID) = entry.eventType else {
                return nil
            }
            return (action, agentID)
        }
    }
    
    /// Returns only the rejected actions.
    ///
    /// - Returns: Array of (action, agentID, rationale) tuples for rejected actions
    public func rejectedActions() -> [(action: A, agentID: String, rationale: String)] {
        entries.compactMap { entry in
            guard !entry.applied,
                  case .actionProposed(let action, let agentID) = entry.eventType else {
                return nil
            }
            return (action, agentID, entry.rationale)
        }
    }
    
    /// Returns events within a time range.
    ///
    /// - Parameters:
    ///   - start: The start of the time range (inclusive)
    ///   - end: The end of the time range (inclusive)
    /// - Returns: Events whose timestamp falls within the range
    public func events(from start: Date, to end: Date) -> [AuditEvent<A>] {
        entries.filter { $0.timestamp >= start && $0.timestamp <= end }
    }
    
    /// Returns events for a specific agent.
    ///
    /// - Parameter agentID: The agent ID to filter by
    /// - Returns: Events proposed by the specified agent
    public func events(byAgent agentID: String) -> [AuditEvent<A>] {
        entries.filter { entry in
            if case .actionProposed(_, let id) = entry.eventType {
                return id == agentID
            }
            return false
        }
    }
}

// MARK: - Collection Conformance

extension EventLog: Collection {
    
    public typealias Index = Int
    public typealias Element = AuditEvent<A>
    
    public var startIndex: Int { entries.startIndex }
    public var endIndex: Int { entries.endIndex }
    
    public subscript(position: Int) -> AuditEvent<A> {
        entries[position]
    }
    
    public func index(after i: Int) -> Int {
        entries.index(after: i)
    }
}

// MARK: - Codable

extension EventLog: Codable where A: Codable {}

// MARK: - EventLogError

/// Errors that can occur when working with an event log.
public enum EventLogError: Error, Sendable, Equatable {
    
    /// The hash chain is broken at the specified index.
    ///
    /// - Parameters:
    ///   - expected: The hash that was expected (from previous event)
    ///   - found: The hash that was found (in current event)
    ///   - atIndex: The index where the discontinuity was detected
    case chainDiscontinuity(expected: String, found: String, atIndex: Int)
}

// MARK: - EventLogError LocalizedError

extension EventLogError: LocalizedError {
    
    public var errorDescription: String? {
        switch self {
        case .chainDiscontinuity(let expected, let found, let index):
            return "Hash chain discontinuity at index \(index): expected '\(expected)' but found '\(found)'"
        }
    }
}
