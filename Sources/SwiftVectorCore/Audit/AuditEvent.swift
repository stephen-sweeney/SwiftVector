//
//  AuditEvent.swift
//  SwiftVectorCore
//
//  Created by Stephen Sweeney
//  Copyright © 2026 Flightworks Aerial LLC. All rights reserved.
//

import Foundation
import CryptoKit

// MARK: - AuditEvent

/// A single entry in the audit trail, recording a state transition attempt.
///
/// `AuditEvent` captures everything needed to understand and replay a
/// state transition:
/// - When it happened (`timestamp`)
/// - What was proposed (`eventType`)
/// - The state before and after (`stateHashBefore`, `stateHashAfter`)
/// - Whether it succeeded (`applied`)
/// - Why it succeeded or failed (`rationale`)
/// - Cryptographic link to previous entry (`previousEntryHash`)
///
/// ## Deterministic Construction
/// `AuditEvent` requires explicit `id` and `timestamp` parameters to ensure
/// deterministic replay. Use injected `Clock` and `UUIDGenerator`:
///
/// ```swift
/// let event = AuditEvent<GameAction>(
///     id: uuidGenerator.next(),
///     timestamp: clock.now(),
///     eventType: .actionProposed(action, agentID: "agent-1"),
///     stateHashBefore: previousState.stateHash(),
///     stateHashAfter: newState.stateHash(),
///     applied: true,
///     rationale: "Action validated successfully",
///     previousEntryHash: log.last?.entryHash ?? ""
/// )
/// ```
///
/// ## Hash Chain
/// Each entry contains:
/// - `previousEntryHash`: The `entryHash` of the preceding entry
/// - `entryHash`: SHA256 of all fields including `previousEntryHash`
///
/// This forms a tamper-evident chain. Modifying any field in any entry
/// invalidates all subsequent `previousEntryHash` references.
///
/// ## Regulatory Compliance
/// This structure satisfies audit requirements from:
/// - DO-178C (aviation): Traceability and reproducibility
/// - IEC 62304 (medical): Change attribution
/// - ISO 26262 (automotive): Deterministic behavior verification
public struct AuditEvent<A: Action>: Sendable, Identifiable {
    
    /// Unique identifier for this audit entry.
    ///
    /// Must be provided explicitly (via `UUIDGenerator`) to ensure
    /// deterministic replay.
    public let id: UUID
    
    /// When this event occurred.
    ///
    /// Must be provided explicitly (via `Clock`) to ensure
    /// deterministic replay.
    public let timestamp: Date
    
    /// The type of event (initialization, action proposed, etc.).
    public let eventType: AuditEventType<A>
    
    /// Hash of the state before this event was processed.
    ///
    /// For the first event (initialization), this may be empty or
    /// represent a "null state" hash.
    public let stateHashBefore: String
    
    /// Hash of the state after this event was processed.
    ///
    /// If `applied == false`, this should equal `stateHashBefore`
    /// (rejected actions don't change state).
    public let stateHashAfter: String
    
    /// Whether the proposed action was accepted and applied.
    ///
    /// - `true`: Action was valid; state was updated
    /// - `false`: Action was rejected; state unchanged
    ///
    /// For non-action events (initialization, system events), this
    /// is typically `true`.
    public let applied: Bool
    
    /// Human-readable explanation of the outcome.
    ///
    /// For accepted actions: describes what changed.
    /// For rejected actions: explains why validation failed.
    ///
    /// This field is critical for debugging and incident investigation.
    public let rationale: String
    
    /// Hash of the previous entry in the chain.
    ///
    /// Empty string for the first entry. Forms the cryptographic link
    /// that makes the audit trail tamper-evident.
    public let previousEntryHash: String
    
    /// This entry's hash, computed from all content plus the previous entry hash.
    ///
    /// Forms the cryptographic link in the hash chain. The next entry's
    /// `previousEntryHash` must equal this value.
    public var entryHash: String {
        computeEntryHash()
    }
    
    /// Creates a new audit event.
    ///
    /// - Parameters:
    ///   - id: Unique identifier (use `UUIDGenerator.next()`)
    ///   - timestamp: When the event occurred (use `Clock.now()`)
    ///   - eventType: The type of event being recorded
    ///   - stateHashBefore: Hash of state before processing
    ///   - stateHashAfter: Hash of state after processing
    ///   - applied: Whether the action was applied
    ///   - rationale: Human-readable explanation
    ///   - previousEntryHash: Hash of the previous entry (empty for first entry)
    public init(
        id: UUID,
        timestamp: Date,
        eventType: AuditEventType<A>,
        stateHashBefore: String,
        stateHashAfter: String,
        applied: Bool,
        rationale: String,
        previousEntryHash: String = ""
    ) {
        self.id = id
        self.timestamp = timestamp
        self.eventType = eventType
        self.stateHashBefore = stateHashBefore
        self.stateHashAfter = stateHashAfter
        self.applied = applied
        self.rationale = rationale
        self.previousEntryHash = previousEntryHash
    }

    private struct HashableContent: Encodable {
        let id: UUID
        let timestamp: String
        let eventType: AuditEventType<A>
        let stateHashBefore: String
        let stateHashAfter: String
        let applied: Bool
        let rationale: String
        let previousEntryHash: String
    }

    // MARK: - Hash Computation
    
    /// Computes the SHA256 hash of this entry's content.
    ///
    /// The hash includes all fields to ensure any modification is detectable.
    /// The `previousEntryHash` is included to form the chain link.
    private func computeEntryHash() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys

        let content = HashableContent(
            id: id,
            timestamp: String(format: "%.6f", timestamp.timeIntervalSince1970),
            eventType: eventType,
            stateHashBefore: stateHashBefore,
            stateHashAfter: stateHashAfter,
            applied: applied,
            rationale: rationale,
            previousEntryHash: previousEntryHash
        )

        guard let data = try? encoder.encode(content) else {
            preconditionFailure("AuditEvent must be JSON-encodable for hashing")
        }

        let digest = SHA256.hash(data: data)
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Equatable

extension AuditEvent: Equatable {
    
    public static func == (lhs: AuditEvent<A>, rhs: AuditEvent<A>) -> Bool {
        lhs.id == rhs.id &&
        lhs.timestamp == rhs.timestamp &&
        lhs.eventType == rhs.eventType &&
        lhs.stateHashBefore == rhs.stateHashBefore &&
        lhs.stateHashAfter == rhs.stateHashAfter &&
        lhs.applied == rhs.applied &&
        lhs.rationale == rhs.rationale &&
        lhs.previousEntryHash == rhs.previousEntryHash
    }
}

// MARK: - Codable

extension AuditEvent: Codable where A: Codable {
    
    private enum CodingKeys: String, CodingKey {
        case id
        case timestamp
        case eventType
        case stateHashBefore
        case stateHashAfter
        case applied
        case rationale
        case previousEntryHash
    }
}

// MARK: - Convenience Factories

extension AuditEvent {
    
    /// Creates an initialization event.
    ///
    /// - Parameters:
    ///   - id: Unique identifier
    ///   - timestamp: When initialization occurred
    ///   - initialStateHash: Hash of the initial state
    ///   - previousEntryHash: Hash of previous entry (empty for first entry)
    /// - Returns: An audit event recording system initialization
    public static func initialization(
        id: UUID,
        timestamp: Date,
        initialStateHash: String,
        previousEntryHash: String = ""
    ) -> AuditEvent {
        AuditEvent(
            id: id,
            timestamp: timestamp,
            eventType: .initialization,
            stateHashBefore: "",
            stateHashAfter: initialStateHash,
            applied: true,
            rationale: "System initialized",
            previousEntryHash: previousEntryHash
        )
    }
    
    /// Creates an event for an accepted action.
    ///
    /// - Parameters:
    ///   - id: Unique identifier
    ///   - timestamp: When the action was processed
    ///   - action: The action that was proposed
    ///   - agentID: Identifier of the proposing agent
    ///   - stateHashBefore: Hash before the action
    ///   - stateHashAfter: Hash after the action
    ///   - rationale: Description of what changed
    ///   - previousEntryHash: Hash of previous entry in the chain
    /// - Returns: An audit event recording the accepted action
    public static func accepted(
        id: UUID,
        timestamp: Date,
        action: A,
        agentID: String,
        stateHashBefore: String,
        stateHashAfter: String,
        rationale: String,
        previousEntryHash: String
    ) -> AuditEvent {
        AuditEvent(
            id: id,
            timestamp: timestamp,
            eventType: .actionProposed(action, agentID: agentID),
            stateHashBefore: stateHashBefore,
            stateHashAfter: stateHashAfter,
            applied: true,
            rationale: rationale,
            previousEntryHash: previousEntryHash
        )
    }
    
    /// Creates an event for a rejected action.
    ///
    /// - Parameters:
    ///   - id: Unique identifier
    ///   - timestamp: When the action was processed
    ///   - action: The action that was proposed
    ///   - agentID: Identifier of the proposing agent
    ///   - stateHash: Hash of the unchanged state
    ///   - rationale: Explanation of why the action was rejected
    ///   - previousEntryHash: Hash of previous entry in the chain
    /// - Returns: An audit event recording the rejected action
    public static func rejected(
        id: UUID,
        timestamp: Date,
        action: A,
        agentID: String,
        stateHash: String,
        rationale: String,
        previousEntryHash: String
    ) -> AuditEvent {
        AuditEvent(
            id: id,
            timestamp: timestamp,
            eventType: .actionProposed(action, agentID: agentID),
            stateHashBefore: stateHash,
            stateHashAfter: stateHash,  // Unchanged
            applied: false,
            rationale: rationale,
            previousEntryHash: previousEntryHash
        )
    }
    
    /// Creates a system event.
    ///
    /// - Parameters:
    ///   - id: Unique identifier
    ///   - timestamp: When the event occurred
    ///   - description: Human-readable description of the event
    ///   - stateHash: Hash of the current state (unchanged by system events)
    ///   - previousEntryHash: Hash of previous entry in the chain
    /// - Returns: An audit event recording the system event
    public static func systemEvent(
        id: UUID,
        timestamp: Date,
        description: String,
        stateHash: String,
        previousEntryHash: String
    ) -> AuditEvent {
        AuditEvent(
            id: id,
            timestamp: timestamp,
            eventType: .systemEvent(description: description),
            stateHashBefore: stateHash,
            stateHashAfter: stateHash,  // System events don't change state
            applied: true,
            rationale: description,
            previousEntryHash: previousEntryHash
        )
    }
    
    /// Creates a state restored event.
    ///
    /// - Parameters:
    ///   - id: Unique identifier
    ///   - timestamp: When the restoration occurred
    ///   - source: Description of where state was restored from
    ///   - stateHashBefore: Hash of state before restoration
    ///   - stateHashAfter: Hash of state after restoration
    ///   - previousEntryHash: Hash of previous entry in the chain
    /// - Returns: An audit event recording the state restoration
    public static func stateRestored(
        id: UUID,
        timestamp: Date,
        source: String,
        stateHashBefore: String,
        stateHashAfter: String,
        previousEntryHash: String
    ) -> AuditEvent {
        AuditEvent(
            id: id,
            timestamp: timestamp,
            eventType: .stateRestored(source: source),
            stateHashBefore: stateHashBefore,
            stateHashAfter: stateHashAfter,
            applied: true,
            rationale: "State restored from \(source)",
            previousEntryHash: previousEntryHash
        )
    }
}

