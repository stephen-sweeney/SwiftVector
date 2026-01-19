//
//  Reducer.swift
//  SwiftVectorCore
//
//  Created by Stephen Sweeney
//  Copyright © 2026 Flightworks Aerial LLC. All rights reserved.
//

import Foundation

// MARK: - ReducerResult

/// The outcome of attempting to reduce an action against state.
///
/// Every reducer call produces a `ReducerResult`, which captures:
/// - The resulting state (possibly unchanged if rejected)
/// - Whether the action was applied
/// - A human-readable rationale for the decision
///
/// ## Why Rationale Matters
/// The `rationale` field is critical for:
/// - **Audit trails**: Explains why actions were accepted or rejected
/// - **Debugging**: Identifies which validation rule triggered rejection
/// - **User feedback**: Can be surfaced to explain system behavior
///
/// ## Example
/// ```swift
/// // Rejection with explanation
/// ReducerResult.rejected(
///     state,
///     rationale: "Cannot rest in dangerous location: dark cave"
/// )
///
/// // Acceptance with confirmation
/// ReducerResult.accepted(
///     newState,
///     rationale: "Moved to sunlit meadow"
/// )
/// ```
public struct ReducerResult<S: State>: Sendable {
    
    /// The state after reduction (may be unchanged if action was rejected).
    public let newState: S
    
    /// Whether the action was applied to produce the new state.
    ///
    /// - `true`: Action was valid and applied
    /// - `false`: Action was rejected; `newState` equals input state
    public let applied: Bool
    
    /// Human-readable explanation of the reduction decision.
    ///
    /// For accepted actions: describes what changed.
    /// For rejected actions: explains why the action was invalid.
    public let rationale: String
    
    /// Creates a reducer result.
    ///
    /// Prefer the static factory methods `accepted(_:rationale:)` and
    /// `rejected(_:rationale:)` for clarity.
    public init(newState: S, applied: Bool, rationale: String) {
        self.newState = newState
        self.applied = applied
        self.rationale = rationale
    }
    
    // MARK: Factory Methods
    
    /// Creates a result indicating the action was accepted and applied.
    ///
    /// - Parameters:
    ///   - state: The new state after applying the action
    ///   - rationale: Description of what changed
    /// - Returns: A `ReducerResult` with `applied == true`
    public static func accepted(_ state: S, rationale: String) -> Self {
        ReducerResult(newState: state, applied: true, rationale: rationale)
    }
    
    /// Creates a result indicating the action was rejected.
    ///
    /// - Parameters:
    ///   - state: The unchanged state (must equal the input state)
    ///   - rationale: Explanation of why the action was invalid
    /// - Returns: A `ReducerResult` with `applied == false`
    public static func rejected(_ state: S, rationale: String) -> Self {
        ReducerResult(newState: state, applied: false, rationale: rationale)
    }
}

// MARK: - Reducer Protocol

/// Pure function that validates and applies actions to state.
///
/// The Reducer is the **deterministic boundary** in SwiftVector's control loop.
/// It is the only component allowed to produce new state:
/// ```
/// State → Agent → Action → Reducer → New State
///                            ↑
///                    (deterministic)
/// ```
///
/// ## Determinism Contract
/// Reducers must be **pure functions**:
/// - Same `(state, action)` → same `ReducerResult`, always
/// - No side effects (I/O, network, randomness)
/// - No dependency on external mutable state
///
/// This guarantee enables:
/// - **Replay**: Actions can be replayed to reproduce exact state
/// - **Testing**: Reducers are trivially unit-testable
/// - **Auditing**: Behavior is fully explainable from inputs
///
/// ## Example
/// ```swift
/// struct FlightReducer: Reducer {
///     typealias S = FlightState
///     typealias A = FlightAction
///
///     func reduce(state: FlightState, action: FlightAction) -> ReducerResult<FlightState> {
///         switch action {
///         case .setAltitude(let meters):
///             guard meters <= state.maxAltitude else {
///                 return .rejected(state, rationale: "Altitude \(meters)m exceeds limit")
///             }
///             var newState = state
///             newState.altitude = meters
///             return .accepted(newState, rationale: "Altitude set to \(meters)m")
///         // ... other cases
///         }
///     }
/// }
/// ```
///
/// ## Implementation Options
/// Reducers can be implemented as:
/// - **Struct**: Stateless, most common
/// - **Enum with static method**: Namespace for pure function
/// - **Class**: If configuration is needed (but instance must be immutable)
public protocol Reducer<S, A>: Sendable {
    
    /// The state type this reducer operates on.
    associatedtype S: State
    
    /// The action type this reducer handles.
    associatedtype A: Action
    
    /// Validates and applies an action to produce new state.
    ///
    /// This method must be a **pure function**:
    /// - Deterministic: same inputs → same output
    /// - No side effects: no I/O, network, or mutation of external state
    /// - No hidden dependencies: no reading from globals or environment
    ///
    /// - Parameters:
    ///   - state: The current state (immutable)
    ///   - action: The proposed action to validate and apply
    /// - Returns: Result containing new state (or unchanged state if rejected),
    ///            whether the action was applied, and explanation
    func reduce(state: S, action: A) -> ReducerResult<S>
}

// MARK: - AnyReducer (Type Erasure)

/// Type-erased wrapper for reducers.
///
/// Useful when you need to store reducers with different concrete types
/// but the same State and Action types.
public struct AnyReducer<S: State, A: Action>: Reducer {
    
    private let _reduce: @Sendable (S, A) -> ReducerResult<S>
    
    /// Creates a type-erased reducer from any conforming reducer.
    ///
    /// - Parameter reducer: The reducer to wrap
    public init<R: Reducer>(_ reducer: R) where R.S == S, R.A == A {
        self._reduce = reducer.reduce
    }
    
    /// Creates a type-erased reducer from a closure.
    ///
    /// - Parameter reduce: The reduce function
    public init(reduce: @escaping @Sendable (S, A) -> ReducerResult<S>) {
        self._reduce = reduce
    }
    
    public func reduce(state: S, action: A) -> ReducerResult<S> {
        _reduce(state, action)
    }
}
