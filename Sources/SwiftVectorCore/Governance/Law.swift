//
//  Law.swift
//  SwiftVectorCore
//
//  Copyright © 2026 Flightworks Aerial LLC. All rights reserved.
//

import Foundation

// MARK: - Law Protocol

/// A deterministic governance constraint that evaluates proposed actions.
///
/// Laws are the governance layer in SwiftVector's constitutional architecture.
/// Each Law evaluates a proposed action against the current state and produces
/// a `LawVerdict`. Multiple Laws compose through a `CompositionRule` to produce
/// a final governance decision recorded as a `CompositionTrace`.
///
/// ## Position in the Control Loop
/// ```
/// Agent → Action → Laws evaluate → CompositionTrace
///                                     |
///                     deny/escalate?  |  allow?
///                           |         |
///                     AuditEvent    Reducer → ReducerResult → AuditEvent
/// ```
///
/// ## Determinism Contract
/// Laws must be **pure functions**:
/// - Same `(state, action)` → same `LawVerdict`, always
/// - No side effects (I/O, network, randomness, `Date()`, `UUID()`)
/// - No dependency on external mutable state
///
/// This guarantee enables deterministic replay of governance decisions.
///
/// ## Laws vs Reducers
/// Laws and Reducers both validate actions, but they serve different roles:
/// - **Laws** enforce cross-cutting governance constraints (boundaries,
///   budgets, authority). They run before the Reducer.
/// - **Reducers** enforce domain-specific state transitions (game rules,
///   flight envelope). They run after governance approves.
///
/// If governance denies, the Reducer never runs.
///
/// ## Example
/// ```swift
/// struct GoldBudgetLaw: Law {
///     let lawID = "GoldBudgetLaw"
///
///     func evaluate(state: GameState, action: GameAction) -> LawVerdict {
///         if case .findGold(let amount) = action, amount > 100 {
///             return LawVerdict(lawID: lawID, decision: .deny,
///                               reason: "Gold \(amount) exceeds limit of 100")
///         }
///         return LawVerdict(lawID: lawID, decision: .allow, reason: "Within budget")
///     }
/// }
/// ```
///
/// ## Composition
/// Laws are composed into a `GovernancePolicy` which evaluates all Laws
/// and combines their verdicts:
/// ```swift
/// let policy = GovernancePolicy(
///     laws: [AnyLaw(GoldBudgetLaw()), AnyLaw(SafeLocationLaw())],
///     compositionRule: .denyWins,
///     jurisdictionID: "ChronicleLaw"
/// )
/// ```
public protocol Law<S, A>: Sendable {

    /// The state type this Law evaluates against.
    associatedtype S: State

    /// The action type this Law evaluates.
    associatedtype A: Action

    /// Stable identifier for this Law.
    ///
    /// By convention, this matches the type name (e.g., `"BoundaryLaw"`,
    /// `"ResourceLaw"`). Must be stable across versions for audit trail
    /// consistency and replay verification.
    var lawID: String { get }

    /// Evaluates an action against the current state and returns a verdict.
    ///
    /// This method must be a **pure function**:
    /// - Deterministic: same `(state, action)` → same `LawVerdict`
    /// - No side effects: no I/O, network, or mutation
    /// - No hidden dependencies: no `Date()`, `UUID()`, or globals
    ///
    /// - Parameters:
    ///   - state: The current immutable state
    ///   - action: The proposed action to evaluate
    /// - Returns: A verdict recording this Law's decision and reasoning
    func evaluate(state: S, action: A) -> LawVerdict
}

// MARK: - AnyLaw (Type Erasure)

/// Type-erased wrapper for Laws.
///
/// Enables heterogeneous collections of Laws with the same State and
/// Action types, which is required for `GovernancePolicy` to hold
/// an array of different Law implementations.
///
/// ## Usage
/// ```swift
/// let laws: [AnyLaw<GameState, GameAction>] = [
///     AnyLaw(GoldBudgetLaw()),
///     AnyLaw(SafeLocationLaw()),
///     AnyLaw(GameOverLaw()),
/// ]
/// ```
///
/// ## Closure Initializer
/// For lightweight or test Laws:
/// ```swift
/// let testLaw = AnyLaw<GameState, GameAction>(lawID: "TestLaw") { state, action in
///     LawVerdict(lawID: "TestLaw", decision: .allow, reason: "Test")
/// }
/// ```
public struct AnyLaw<S: State, A: Action>: Law, Sendable {

    /// The stable identifier of the wrapped Law.
    public let lawID: String

    private let _evaluate: @Sendable (S, A) -> LawVerdict

    /// Creates a type-erased Law from any conforming Law.
    ///
    /// - Parameter law: The Law to wrap
    public init<L: Law>(_ law: L) where L.S == S, L.A == A {
        self.lawID = law.lawID
        self._evaluate = law.evaluate
    }

    /// Creates a type-erased Law from a closure.
    ///
    /// - Parameters:
    ///   - lawID: Stable identifier for this Law
    ///   - evaluate: The evaluation function
    public init(
        lawID: String,
        evaluate: @escaping @Sendable (S, A) -> LawVerdict
    ) {
        self.lawID = lawID
        self._evaluate = evaluate
    }

    public func evaluate(state: S, action: A) -> LawVerdict {
        _evaluate(state, action)
    }
}
