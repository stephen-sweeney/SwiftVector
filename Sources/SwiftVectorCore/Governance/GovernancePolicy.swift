//
//  GovernancePolicy.swift
//  SwiftVectorCore
//
//  Copyright © 2026 Flightworks Aerial LLC. All rights reserved.
//

import Foundation

// MARK: - GovernancePolicy

/// A governance evaluation policy that composes multiple Laws into a single decision.
///
/// `GovernancePolicy` is a pure-function container — it holds the Laws, the
/// composition rule, and the jurisdiction, then evaluates them as a unit.
/// Its `evaluate(state:action:)` method is deterministic: same state + same
/// action + same laws = same `CompositionTrace`, always.
///
/// ## Position in the Control Loop
/// ```
/// Agent → Action → GovernancePolicy.evaluate() → CompositionTrace
///                                                   |
///                                   deny/escalate?  |  allow?
///                                         |         |
///                                   AuditEvent    Reducer → ReducerResult → AuditEvent
/// ```
///
/// ## Usage
/// ```swift
/// let policy = GovernancePolicy(
///     laws: [AnyLaw(GoldBudgetLaw()), AnyLaw(SafeLocationLaw())],
///     compositionRule: .denyWins,
///     jurisdictionID: "ChronicleLaw"
/// )
///
/// let trace = policy.evaluate(state: gameState, action: .findGold(500))
/// switch trace.composedDecision {
/// case .allow: // proceed to reducer
/// case .deny, .escalate: // block, record in audit
/// case .abstain: break // should not appear as composed decision
/// }
/// ```
///
/// ## Opt-In Design
/// `GovernancePolicy` is optional on `BaseOrchestrator`. When nil, behavior
/// is identical to pre-governance code — no Laws evaluated, no traces recorded.
public struct GovernancePolicy<S: State, A: Action>: Sendable {

    /// The Laws that evaluate proposed actions.
    ///
    /// Laws are evaluated in array order. Order is preserved in the
    /// `CompositionTrace` for deterministic replay.
    public let laws: [AnyLaw<S, A>]

    /// The rule used to compose individual Law verdicts.
    public let compositionRule: CompositionRule

    /// The jurisdiction producing governance traces.
    ///
    /// By convention, this identifies the Domain Law that defined which
    /// Laws are active (e.g., `"ChronicleLaw"`, `"FlightLaw"`).
    public let jurisdictionID: String

    /// Creates a governance policy.
    ///
    /// - Parameters:
    ///   - laws: Ordered array of Laws to evaluate
    ///   - compositionRule: Rule for composing verdicts
    ///   - jurisdictionID: Domain jurisdiction identifier
    public init(
        laws: [AnyLaw<S, A>],
        compositionRule: CompositionRule,
        jurisdictionID: String
    ) {
        self.laws = laws
        self.compositionRule = compositionRule
        self.jurisdictionID = jurisdictionID
    }

    /// Evaluates all Laws against the given state and action.
    ///
    /// This is a **pure function**: same inputs always produce the same
    /// `CompositionTrace`. No side effects, no timestamps, no generated IDs.
    ///
    /// - Parameters:
    ///   - state: The current immutable state
    ///   - action: The proposed action to evaluate
    ///   - correlationID: Optional link to the originating action
    /// - Returns: A `CompositionTrace` recording all verdicts and the composed decision
    public func evaluate(
        state: S,
        action: A,
        correlationID: UUID? = nil
    ) -> CompositionTrace {
        let verdicts = laws.map { law in
            law.evaluate(state: state, action: action)
        }

        return CompositionEngine.compose(
            verdicts: verdicts,
            rule: compositionRule,
            jurisdictionID: jurisdictionID,
            correlationID: correlationID
        )
    }
}
