//
//  CompositionTrace.swift
//  SwiftVectorCore
//
//  Copyright © 2026 Flightworks Aerial LLC. All rights reserved.
//

import Foundation

// MARK: - CompositionTrace

/// The complete, ordered record of how a governance decision was made.
///
/// A `CompositionTrace` is the artifact that makes governance replay
/// deterministic. It answers:
/// - Which Laws evaluated this action? (`verdicts`)
/// - In what order? (array ordering is evaluation order)
/// - What rule combined them? (`compositionRule`)
/// - What was the final decision? (`composedDecision`)
/// - Which jurisdiction produced this trace? (`jurisdictionID`)
///
/// ## Determinism
/// `CompositionTrace` contains no timestamps or generated IDs. All
/// time-varying metadata lives on the `AuditEvent` that wraps the trace.
/// This means the trace itself is a pure function of its inputs:
/// same verdicts + same rule = same trace, always.
///
/// ## Audit Integration
/// The trace is stored as an optional field on `AuditEvent`. For
/// governance-denied actions, it explains every Law that contributed
/// to the denial. For allowed actions that proceed to the Reducer,
/// it records that governance approved before the Reducer applied.
///
/// ## Example
/// ```swift
/// let trace = CompositionTrace(
///     verdicts: [
///         LawVerdict(lawID: "BoundaryLaw", decision: .deny, reason: "Outside sandbox"),
///         LawVerdict(lawID: "ResourceLaw", decision: .allow, reason: "Budget OK"),
///     ],
///     compositionRule: .denyWins,
///     composedDecision: .deny,
///     jurisdictionID: "ClawLaw"
/// )
/// ```
public struct CompositionTrace: Sendable, Equatable, Codable {

    /// Ordered array of individual Law verdicts.
    ///
    /// Array order IS evaluation order — this is the composition sequence.
    /// Preserving order is critical for deterministic replay.
    public let verdicts: [LawVerdict]

    /// The rule used to compose verdicts into the final decision.
    public let compositionRule: CompositionRule

    /// The final composed decision after applying the composition rule.
    public let composedDecision: LawDecision

    /// The jurisdiction (Domain Law) that defined which Laws were active.
    ///
    /// Examples: `"ClawLaw"`, `"FlightLaw"`, `"ChronicleLaw"`.
    /// Used for audit trail attribution and replay filtering.
    public let jurisdictionID: String

    /// Optional correlation ID for linking to the originating action.
    ///
    /// When present, this matches the `correlationID` of the `Action`
    /// that triggered governance evaluation. Enables tracing governance
    /// decisions back to specific agent proposals.
    public let correlationID: UUID?

    /// Creates a new composition trace.
    ///
    /// - Parameters:
    ///   - verdicts: Ordered array of individual Law verdicts
    ///   - compositionRule: The rule used to compose verdicts
    ///   - composedDecision: The final composed decision
    ///   - jurisdictionID: The Domain Law that produced this trace
    ///   - correlationID: Optional link to the originating action
    public init(
        verdicts: [LawVerdict],
        compositionRule: CompositionRule,
        composedDecision: LawDecision,
        jurisdictionID: String,
        correlationID: UUID? = nil
    ) {
        self.verdicts = verdicts
        self.compositionRule = compositionRule
        self.composedDecision = composedDecision
        self.jurisdictionID = jurisdictionID
        self.correlationID = correlationID
    }
}
