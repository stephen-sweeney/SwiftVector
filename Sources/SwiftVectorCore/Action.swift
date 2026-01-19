//
//  Action.swift
//  SwiftVectorCore
//
//  Created by Stephen Sweeney
//  Copyright © 2026 Flightworks Aerial LLC. All rights reserved.
//

import Foundation

// MARK: - Action Protocol

/// An intent to transition state. Actions are proposals, not commands.
///
/// In SwiftVector's control loop, agents propose Actions, but only the Reducer
/// decides whether to apply them:
/// ```
/// State → Agent → Action → Reducer → New State
///                   ↑          ↓
///              (proposed)  (validated)
/// ```
///
/// Actions are:
/// - **Serializable**: Can be persisted for audit trails and replay
/// - **Equatable**: Can be compared for testing and deduplication
/// - **Sendable**: Safe to pass across actor boundaries
///
/// ## Example
/// ```swift
/// enum FlightAction: Action {
///     case setAltitude(meters: Double)
///     case setHeading(degrees: Double)
///     case returnToHome
///
///     var actionDescription: String {
///         switch self {
///         case .setAltitude(let m): return "Set altitude to \(m)m"
///         case .setHeading(let d): return "Set heading to \(d)°"
///         case .returnToHome: return "Return to home"
///         }
///     }
/// }
/// ```
///
/// ## Correlation
/// Each action carries a `correlationID` for tracing through distributed systems
/// and linking related events in audit logs.
public protocol Action: Sendable, Equatable, Codable {
    
    /// Human-readable description of the action for audit logs.
    ///
    /// This should be concise but informative. It appears in:
    /// - Audit trail entries
    /// - Debug output
    /// - Incident reports
    ///
    /// Example: "Move to dark cave" or "Set altitude to 120m"
    var actionDescription: String { get }
    
    /// Unique identifier for correlating this action across system boundaries.
    ///
    /// Used for:
    /// - Linking audit entries across services
    /// - Tracing action flow in distributed systems
    /// - Debugging multi-agent interactions
    ///
    /// Default implementation generates a new UUID. Override if actions
    /// arrive from external systems with existing correlation IDs.
    var correlationID: UUID { get }
}

// MARK: - Implementation Notes
//
// No default correlationID implementation is provided.
//
// Rationale: A default that generates UUID() on each access would be:
// - Nondeterministic (violates Core principles)
// - Unstable (different value each access)
// - Lost on serialization round-trip
//
// Conformers must explicitly store and provide correlationID:
//
// ```swift
// enum MyAction: Action {
//     case doSomething(id: UUID, payload: String)
//
//     var correlationID: UUID {
//         switch self {
//         case .doSomething(let id, _): return id
//         }
//     }
//
//     var actionDescription: String { /* ... */ }
// }
// ```
//
// For convenience, consider a factory that uses an injected UUIDGenerator
// (see SwiftVectorCore/Determinism after Commit 2).

// MARK: - ActionProposal

/// Wraps an action with metadata about its source.
///
/// Used by the Orchestrator to track which agent proposed each action,
/// enabling attribution in audit trails.
public struct ActionProposal<A: Action>: Sendable {
    
    /// The proposed action.
    public let action: A
    
    /// Identifier of the agent that proposed this action.
    public let agentID: String
    
    /// When the action was proposed.
    public let timestamp: Date
    
    /// Creates a new action proposal.
    ///
    /// - Parameters:
    ///   - action: The action being proposed
    ///   - agentID: Identifier of the proposing agent
    ///   - timestamp: When the proposal was made (obtain from injected Clock)
    ///
    /// - Note: No default timestamp is provided to enforce determinism.
    ///   Use an injected `Clock` (see SwiftVectorCore/Determinism) to obtain
    ///   timestamps in a testable way.
    public init(action: A, agentID: String, timestamp: Date) {
        self.action = action
        self.agentID = agentID
        self.timestamp = timestamp
    }
}
