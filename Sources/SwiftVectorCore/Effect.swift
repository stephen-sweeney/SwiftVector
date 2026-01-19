//
//  Effect.swift
//  SwiftVectorCore
//
//  Created by Stephen Sweeney
//  Copyright © 2026 Flightworks Aerial LLC. All rights reserved.
//

import Foundation

// MARK: - Effect Protocol

/// A description of a side effect to be performed after a state transition.
///
/// Effects are **descriptions of work**, not the work itself. This separation
/// enables:
/// - **Testability**: Effects can be inspected without execution
/// - **Determinism**: State transitions remain pure; effects happen after
/// - **Replay**: Effects can be skipped during replay
///
/// ## The Effect Lifecycle
/// ```
/// State → Reducer → (New State, Effects)
///                         ↓
///                   EffectRunner
///                         ↓
///                   ResultAction
///                         ↓
///                      Reducer
/// ```
///
/// Effects execute asynchronously and produce Actions that feed back into
/// the control loop. This keeps the Reducer pure while allowing I/O.
///
/// ## Example
/// ```swift
/// struct SendTelemetryEffect: Effect {
///     typealias ResultAction = TelemetryAction
///     
///     let payload: TelemetryData
///     let endpoint: URL
///     
///     func execute() async throws -> TelemetryAction {
///         let response = try await URLSession.shared.upload(to: endpoint, data: payload)
///         return .telemetrySent(response.statusCode)
///     }
/// }
/// ```
///
/// ## Effect Isolation
/// Effects are the **only** place where side effects are permitted:
/// - Network requests
/// - File I/O
/// - Database writes
/// - Hardware interaction
///
/// Agents and Reducers must remain pure.
public protocol Effect: Sendable, Equatable {
    
    /// The type of action this effect produces when complete.
    associatedtype ResultAction: Action
    
    /// Executes the effect and returns an action to feed back into the loop.
    ///
    /// This method may perform I/O, network calls, or other side effects.
    /// It runs asynchronously and may throw.
    ///
    /// - Returns: An action describing the effect's outcome
    /// - Throws: If the effect fails
    func execute() async throws -> ResultAction
}

// MARK: - EffectRunner Protocol

/// Coordinates execution of effects with proper isolation.
///
/// The EffectRunner is an actor that:
/// - Executes effects asynchronously
/// - Handles errors and converts them to actions
/// - Maintains ordering guarantees if required
///
/// ## Example
/// ```swift
/// actor DefaultEffectRunner: EffectRunner {
///     func run<E: Effect>(_ effect: E) async throws -> E.ResultAction {
///         try await effect.execute()
///     }
/// }
/// ```
public protocol EffectRunner: Sendable, Actor {
    
    /// Executes an effect and returns its result action.
    ///
    /// - Parameter effect: The effect to execute
    /// - Returns: The action produced by the effect
    /// - Throws: If the effect execution fails
    func run<E: Effect>(_ effect: E) async throws -> E.ResultAction
}

// MARK: - NoEffect

/// A placeholder for reducers that don't produce effects.
///
/// Use when defining a reducer that only transforms state without
/// triggering side effects:
///
/// ```swift
/// func reduce(state: S, action: A) -> (ReducerResult<S>, [NoEffect]) {
///     // Pure state transformation
///     return (.accepted(newState, rationale: "..."), [])
/// }
/// ```
public struct NoEffect: Effect, Sendable, Equatable {
    
    /// Placeholder action type (never actually produced).
    public struct NeverAction: Action {
        public var actionDescription: String { "" }
        public var correlationID: UUID { UUID() }
        
        private init() {}  // Cannot be instantiated
    }
    
    public typealias ResultAction = NeverAction
    
    public func execute() async throws -> NeverAction {
        fatalError("NoEffect should never be executed")
    }
}

// MARK: - EffectResult

/// The outcome of executing an effect.
///
/// Wraps either a successful result action or a failure, allowing
/// the control loop to handle both cases as actions.
public enum EffectResult<A: Action>: Sendable {
    
    /// Effect completed successfully with a result action.
    case success(A)
    
    /// Effect failed with an error.
    case failure(Error)
    
    /// The result action if successful, nil if failed.
    public var action: A? {
        if case .success(let action) = self {
            return action
        }
        return nil
    }
    
    /// The error if failed, nil if successful.
    public var error: Error? {
        if case .failure(let error) = self {
            return error
        }
        return nil
    }
}

// MARK: - EffectResult Sendable Conformance

extension EffectResult: Equatable where A: Equatable {
    public static func == (lhs: EffectResult<A>, rhs: EffectResult<A>) -> Bool {
        switch (lhs, rhs) {
        case (.success(let a), .success(let b)):
            return a == b
        case (.failure, .failure):
            // Errors aren't generally Equatable; consider equal if both failed
            return true
        default:
            return false
        }
    }
}
