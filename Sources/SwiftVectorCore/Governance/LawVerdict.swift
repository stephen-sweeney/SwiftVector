//
//  LawVerdict.swift
//  SwiftVectorCore
//
//  Copyright © 2026 Flightworks Aerial LLC. All rights reserved.
//

import Foundation

// MARK: - LawVerdict

/// The individual verdict of a single Law evaluating a proposed action.
///
/// Every Law that participates in governance produces a `LawVerdict`
/// recording its identity, decision, and reasoning. Verdicts are collected
/// into an ordered array and composed by the `CompositionEngine` to produce
/// a final governance decision.
///
/// ## Determinism
/// Verdicts are pure data — no timestamps, no generated IDs. The
/// evaluation context (state hash, action hash, timestamp) lives on the
/// `AuditEvent` that wraps the `CompositionTrace`, not on individual
/// verdicts. This avoids `Date()` or `UUID()` calls inside Law evaluation.
///
/// ## Example
/// ```swift
/// let verdict = LawVerdict(
///     lawID: "BoundaryLaw",
///     decision: .deny,
///     reason: "Path /etc/passwd is outside sandbox"
/// )
/// ```
///
/// ## Audit Trail
/// Verdicts are serializable (`Codable`) and recorded as part of the
/// `CompositionTrace` in the audit log. This enables post-hoc analysis
/// of which Laws fired, what each decided, and why.
public struct LawVerdict: Sendable, Equatable, Codable {

    /// The identifier of the Law that produced this verdict.
    ///
    /// By convention, this matches the Law's type name or a stable
    /// registry identifier (e.g., `"BoundaryLaw"`, `"ResourceLaw"`).
    /// Must be stable across versions for audit trail consistency.
    public let lawID: String

    /// The decision this Law reached about the proposed action.
    public let decision: LawDecision

    /// A human-readable explanation of the decision.
    ///
    /// Must be deterministic — the same (state, action) inputs must
    /// produce the same reason string. This field is critical for
    /// debugging, incident investigation, and audit compliance.
    public let reason: String

    /// Creates a new Law verdict.
    ///
    /// - Parameters:
    ///   - lawID: Identifier of the Law that produced this verdict
    ///   - decision: The governance decision reached
    ///   - reason: Human-readable explanation of the decision
    public init(lawID: String, decision: LawDecision, reason: String) {
        self.lawID = lawID
        self.decision = decision
        self.reason = reason
    }
}
