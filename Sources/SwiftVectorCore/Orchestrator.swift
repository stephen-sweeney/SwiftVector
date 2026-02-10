//
//  Orchestrator.swift
//  SwiftVectorCore
//
//  Copyright © 2026 Flightworks Aerial LLC. All rights reserved.
//

import Foundation

/// Coordinates the SwiftVector control loop: Agent -> Action -> Reducer -> State.
///
/// The Orchestrator is responsible for:
/// - Maintaining the single source of truth (state)
/// - Soliciting proposals from agents
/// - Applying actions through the reducer
/// - Broadcasting state changes to observers
/// - Maintaining the tamper-evident audit log
///
/// ## Implementation
/// Recommend implementing as `actor` for automatic isolation:
/// ```swift
/// actor MyOrchestrator: Orchestrator {
///     typealias State = GameState
///     typealias Action = GameAction
///     // ...
/// }
/// ```
///
/// ## Determinism Requirements
/// Implementations must:
/// - Use injected `Clock` and `UUIDGenerator` (never `Date()` or `UUID()`)
/// - Ensure `replay(_:)` produces identical state hashes for identical action sequences
/// - Log every state transition to the audit trail
public protocol Orchestrator: Sendable {

    /// The state type managed by this orchestrator.
    associatedtype State: SwiftVectorCore.State

    /// The action type this orchestrator handles.
    associatedtype Action: SwiftVectorCore.Action
    
    /// The reducer type this orchestrator uses.
    associatedtype ReducerType: Reducer where ReducerType.S == State, ReducerType.A == Action

    /// Executes one iteration of the control loop.
    ///
    /// 1. Agent observes current state
    /// 2. Agent proposes action
    /// 3. Reducer validates and applies (or rejects)
    /// 4. New state broadcast via `stateStream()`
    /// 5. Audit entry recorded
    func advance() async

    /// Replays a specific action without agent involvement.
    ///
    /// Used for:
    /// - Deterministic replay from audit logs
    /// - Testing with known action sequences
    /// - State restoration scenarios
    ///
    /// - Parameters:
    ///   - action: The action to replay through the reducer
    ///   - agentID: Identifier for audit attribution (typically "REPLAY")
    func replay(_ action: Action, agentID: String) async

    /// The current state snapshot.
    ///
    /// Returns an immutable copy of the current system state.
    var currentState: State { get async }

    /// Provides an async stream of state updates.
    ///
    /// Observers receive the current state immediately upon subscription,
    /// followed by updates after each `advance()` or `replay(_:)`.
    ///
    func stateStream() -> AsyncStream<State>

    /// Returns the complete audit log as a snapshot.
    ///
    /// The returned `EventLog` is a value type containing all audit entries
    /// from initialization to the current moment. Use `verify()` to check
    /// hash chain integrity, or `verifyReplay(initialState:reducer:)` for
    /// full replay verification.
    func auditLog() async -> EventLog<Action>
}

public extension Orchestrator {
    /// Convenience overload that uses a standard replay agent ID.
    func replay(_ action: Action) async {
        await replay(action, agentID: "REPLAY")
    }
}
