//
//  Agent.swift
//  SwiftVectorCore
//
//  Copyright © 2026 Flightworks Aerial LLC. All rights reserved.
//

import Foundation

/// A stochastic proposer that observes state and suggests actions.
///
/// Agents are the "stochastic" component in SwiftVector's control loop.
/// They observe immutable state and propose actions, which the Reducer
/// validates and applies.
///
/// ## Implementation
/// Recommend implementing as `actor` for thread-safe isolation:
/// ```swift
/// actor MyAgent: Agent {
///     func propose(about state: GameState) async -> GameAction {
///         // LLM, heuristics, or any strategy
///         return .attack
///     }
/// }
/// ```
/**
 public protocol Agent<S, A>: Sendable {
     associatedtype S: State
     associatedtype A: Action

     /// Proposes an action based on the observed state.
     ///
     /// - Parameter state: Current state snapshot (immutable)
     /// - Returns: A proposed action for the Reducer to validate
     func propose(about state: S) async -> A
 }

 */

public protocol Agent: Sendable {
    associatedtype State: SwiftVectorCore.State
    associatedtype Action: SwiftVectorCore.Action

    func propose(about state: State) async -> Action
}
