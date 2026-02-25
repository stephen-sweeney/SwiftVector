//
//  LawDecision.swift
//  SwiftVectorCore
//
//  Copyright © 2026 Flightworks Aerial LLC. All rights reserved.
//

import Foundation

// MARK: - LawDecision

/// The decision a single Law can reach about a proposed action.
///
/// Every Law that evaluates an action must produce one of these decisions.
/// The decision is recorded as part of a `LawVerdict` and composed with
/// other verdicts via a `CompositionRule` to produce the final governance
/// outcome.
///
/// ## Decision Semantics
/// - `allow`: The Law has no objection. The action may proceed (subject to
///   other Laws and the Reducer).
/// - `deny`: The Law rejects this action outright. Under most composition
///   rules, a single deny overrides all allows.
/// - `escalate`: The Law cannot decide autonomously. Human (Steward)
///   approval is required before proceeding.
/// - `abstain`: The action is outside this Law's jurisdiction. The Law
///   has no opinion and does not participate in composition.
///
/// ## Composition
/// Decisions are combined by a `CompositionRule` (e.g., `denyWins`).
/// The composition engine filters out `.abstain` verdicts before applying
/// the rule, so abstaining Laws never influence the outcome.
public enum LawDecision: String, Sendable, Equatable, Codable, CaseIterable {

    /// The Law has no objection to this action.
    case allow

    /// The Law denies this action outright.
    case deny

    /// The Law requires human (Steward) approval before proceeding.
    case escalate

    /// The Law has no opinion — the action is outside its jurisdiction.
    case abstain
}
