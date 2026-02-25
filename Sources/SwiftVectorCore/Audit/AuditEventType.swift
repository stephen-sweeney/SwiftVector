//
//  AuditEventType.swift
//  SwiftVectorCore
//
//  Created by Stephen Sweeney
//  Copyright © 2026 Flightworks Aerial LLC. All rights reserved.
//

import Foundation

// MARK: - AuditEventType

/// Describes the type of event recorded in an audit trail.
///
/// `AuditEventType` is generic over the `Action` type, allowing the audit
/// system to work with any domain-specific action enum.
///
/// ## Event Types
/// - `initialization`: System startup, initial state established
/// - `actionProposed`: An agent proposed an action for validation
/// - `stateRestored`: State was restored from a snapshot or replay
/// - `systemEvent`: Custom system-level events (shutdown, checkpoint, etc.)
///
/// ## Example
/// ```swift
/// enum GameAction: Action { case move, attack, rest }
///
/// let event: AuditEventType<GameAction> = .actionProposed(
///     .move,
///     agentID: "player-agent"
/// )
/// ```
public enum AuditEventType<A: Action>: Sendable, Equatable {
    
    /// System initialization event.
    ///
    /// Recorded when the orchestrator starts and establishes initial state.
    /// The associated state hash represents the starting point for all
    /// subsequent transitions.
    case initialization
    
    /// An agent proposed an action.
    ///
    /// - Parameters:
    ///   - action: The proposed action
    ///   - agentID: Identifier of the agent that proposed the action
    ///
    /// This is the most common event type. Every action flowing through
    /// the control loop generates one of these, whether accepted or rejected.
    case actionProposed(A, agentID: String)
    
    /// State was restored from external source.
    ///
    /// - Parameter source: Description of where state was restored from
    ///
    /// Recorded when state is loaded from a snapshot, replay, or migration.
    /// This breaks the normal action chain but maintains audit continuity.
    case stateRestored(source: String)
    
    /// An action was denied by the governance layer before reaching the reducer.
    ///
    /// - Parameters:
    ///   - action: The proposed action that governance denied
    ///   - agentID: Identifier of the agent that proposed the action
    ///
    /// Unlike `.actionProposed` with `applied == false` (a reducer rejection),
    /// `.governanceDenied` means the reducer never ran. The `CompositionTrace`
    /// attached to the `AuditEvent` records which Laws denied and why.
    case governanceDenied(A, agentID: String)

    /// Custom system-level event.
    ///
    /// - Parameter description: Human-readable description of the event
    ///
    /// Use for events that don't fit other categories: shutdown, checkpoint,
    /// configuration change, external trigger, etc.
    case systemEvent(description: String)
}

// MARK: - CustomStringConvertible

extension AuditEventType: CustomStringConvertible {
    
    public var description: String {
        switch self {
        case .initialization:
            return "initialization"
        case .actionProposed(let action, let agentID):
            return "actionProposed(\(action.actionDescription), agent: \(agentID))"
        case .stateRestored(let source):
            return "stateRestored(from: \(source))"
        case .governanceDenied(let action, let agentID):
            return "governanceDenied(\(action.actionDescription), agent: \(agentID))"
        case .systemEvent(let description):
            return "systemEvent(\(description))"
        }
    }
}

// MARK: - Codable

extension AuditEventType: Codable where A: Codable {
    
    private enum CodingKeys: String, CodingKey {
        case type
        case action
        case agentID
        case source
        case description
    }
    
    private enum EventTypeName: String, Codable {
        case initialization
        case actionProposed
        case stateRestored
        case governanceDenied
        case systemEvent
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .initialization:
            try container.encode(EventTypeName.initialization, forKey: .type)
            
        case .actionProposed(let action, let agentID):
            try container.encode(EventTypeName.actionProposed, forKey: .type)
            try container.encode(action, forKey: .action)
            try container.encode(agentID, forKey: .agentID)
            
        case .stateRestored(let source):
            try container.encode(EventTypeName.stateRestored, forKey: .type)
            try container.encode(source, forKey: .source)

        case .governanceDenied(let action, let agentID):
            try container.encode(EventTypeName.governanceDenied, forKey: .type)
            try container.encode(action, forKey: .action)
            try container.encode(agentID, forKey: .agentID)

        case .systemEvent(let description):
            try container.encode(EventTypeName.systemEvent, forKey: .type)
            try container.encode(description, forKey: .description)
        }
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(EventTypeName.self, forKey: .type)
        
        switch type {
        case .initialization:
            self = .initialization
            
        case .actionProposed:
            let action = try container.decode(A.self, forKey: .action)
            let agentID = try container.decode(String.self, forKey: .agentID)
            self = .actionProposed(action, agentID: agentID)
            
        case .stateRestored:
            let source = try container.decode(String.self, forKey: .source)
            self = .stateRestored(source: source)

        case .governanceDenied:
            let action = try container.decode(A.self, forKey: .action)
            let agentID = try container.decode(String.self, forKey: .agentID)
            self = .governanceDenied(action, agentID: agentID)

        case .systemEvent:
            let description = try container.decode(String.self, forKey: .description)
            self = .systemEvent(description: description)
        }
    }
}
