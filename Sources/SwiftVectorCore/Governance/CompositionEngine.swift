//
//  CompositionEngine.swift
//  SwiftVectorCore
//
//  Copyright © 2026 Flightworks Aerial LLC. All rights reserved.
//

import Foundation

// MARK: - CompositionEngine

/// Composes multiple Law verdicts into a single governance decision.
///
/// `CompositionEngine` is a pure-function namespace — no state, no side
/// effects, no dependency injection needed. Given the same verdicts and
/// the same rule, it always produces the same `CompositionTrace`.
///
/// ## Usage
/// ```swift
/// let trace = CompositionEngine.compose(
///     verdicts: [verdict1, verdict2, verdict3],
///     rule: .denyWins,
///     jurisdictionID: "ClawLaw"
/// )
///
/// switch trace.composedDecision {
/// case .allow: // proceed to reducer
/// case .deny:  // block action, record trace
/// case .escalate: // require steward approval
/// case .abstain: // should not appear as composed decision
/// }
/// ```
///
/// ## Abstention Handling
/// All composition rules filter out `.abstain` verdicts before applying
/// their logic. If all Laws abstain (or there are no verdicts), the
/// result is `.allow` — no governance objection means no governance block.
public enum CompositionEngine {

    /// Composes verdicts using the specified rule and produces a full trace.
    ///
    /// This is a pure function: same inputs always produce the same trace.
    ///
    /// - Parameters:
    ///   - verdicts: Ordered array of individual Law verdicts
    ///   - rule: The composition rule to apply
    ///   - jurisdictionID: The Domain Law producing this trace
    ///   - correlationID: Optional link to the originating action
    /// - Returns: A complete `CompositionTrace` recording the decision
    public static func compose(
        verdicts: [LawVerdict],
        rule: CompositionRule,
        jurisdictionID: String,
        correlationID: UUID? = nil
    ) -> CompositionTrace {
        let decision = resolveDecision(verdicts: verdicts, rule: rule)
        return CompositionTrace(
            verdicts: verdicts,
            compositionRule: rule,
            composedDecision: decision,
            jurisdictionID: jurisdictionID,
            correlationID: correlationID
        )
    }

    // MARK: - Private

    /// Resolves the final decision from verdicts and a rule.
    ///
    /// Filters out abstentions, then applies the composition rule
    /// to the remaining active verdicts.
    private static func resolveDecision(
        verdicts: [LawVerdict],
        rule: CompositionRule
    ) -> LawDecision {
        guard !verdicts.isEmpty else { return .allow }

        let active = verdicts.filter { $0.decision != .abstain }
        guard !active.isEmpty else { return .allow }

        switch rule {
        case .denyWins:
            return resolveDenyWins(active)
        case .unanimousAllow:
            return resolveUnanimousAllow(active)
        case .majorityAllow:
            return resolveMajorityAllow(active)
        }
    }

    /// Any deny → deny. Any escalate → escalate. Otherwise allow.
    private static func resolveDenyWins(_ active: [LawVerdict]) -> LawDecision {
        if active.contains(where: { $0.decision == .deny }) {
            return .deny
        }
        if active.contains(where: { $0.decision == .escalate }) {
            return .escalate
        }
        return .allow
    }

    /// All must allow. One deny → deny. One escalate (no deny) → escalate.
    private static func resolveUnanimousAllow(_ active: [LawVerdict]) -> LawDecision {
        if active.allSatisfy({ $0.decision == .allow }) {
            return .allow
        }
        if active.contains(where: { $0.decision == .deny }) {
            return .deny
        }
        return .escalate
    }

    /// Strict majority (> 50%) must allow. Tie goes to more restrictive.
    private static func resolveMajorityAllow(_ active: [LawVerdict]) -> LawDecision {
        let allowCount = active.filter { $0.decision == .allow }.count
        if allowCount > active.count / 2 {
            return .allow
        }
        if active.contains(where: { $0.decision == .deny }) {
            return .deny
        }
        return .escalate
    }
}
