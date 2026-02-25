//
//  CompositionEngineTests.swift
//  SwiftVectorCoreTests
//
//  Copyright © 2026 Flightworks Aerial LLC. All rights reserved.
//

import Testing
import Foundation
@testable import SwiftVectorCore

// MARK: - CompositionRule Tests

@Suite("CompositionRule")
struct CompositionRuleTests {

    @Test("Raw values are stable strings")
    func rawValuesAreStableStrings() {
        #expect(CompositionRule.denyWins.rawValue == "denyWins")
        #expect(CompositionRule.unanimousAllow.rawValue == "unanimousAllow")
        #expect(CompositionRule.majorityAllow.rawValue == "majorityAllow")
    }

    @Test("Codable round-trip preserves value")
    func codableRoundTrip() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        for rule in CompositionRule.allCases {
            let data = try encoder.encode(rule)
            let decoded = try decoder.decode(CompositionRule.self, from: data)
            #expect(decoded == rule, "Round-trip failed for \(rule)")
        }
    }

    @Test("Equatable distinguishes all cases")
    func equatable() {
        #expect(CompositionRule.denyWins == CompositionRule.denyWins)
        #expect(CompositionRule.denyWins != CompositionRule.unanimousAllow)
        #expect(CompositionRule.unanimousAllow != CompositionRule.majorityAllow)
    }
}

// MARK: - CompositionTrace Tests

@Suite("CompositionTrace")
struct CompositionTraceTests {

    @Test("Stores all fields correctly")
    func storesAllFields() {
        let verdicts = [
            LawVerdict(lawID: "Law1", decision: .allow, reason: "OK"),
            LawVerdict(lawID: "Law2", decision: .deny, reason: "Blocked"),
        ]
        let correlationID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

        let trace = CompositionTrace(
            verdicts: verdicts,
            compositionRule: .denyWins,
            composedDecision: .deny,
            jurisdictionID: "ClawLaw",
            correlationID: correlationID
        )

        #expect(trace.verdicts.count == 2)
        #expect(trace.compositionRule == .denyWins)
        #expect(trace.composedDecision == .deny)
        #expect(trace.jurisdictionID == "ClawLaw")
        #expect(trace.correlationID == correlationID)
    }

    @Test("correlationID defaults to nil")
    func correlationIDDefaultsToNil() {
        let trace = CompositionTrace(
            verdicts: [],
            compositionRule: .denyWins,
            composedDecision: .allow,
            jurisdictionID: "Test"
        )

        #expect(trace.correlationID == nil)
    }

    @Test("Codable round-trip preserves all fields")
    func codableRoundTrip() throws {
        let verdicts = [
            LawVerdict(lawID: "BoundaryLaw", decision: .deny, reason: "Path outside sandbox"),
            LawVerdict(lawID: "ResourceLaw", decision: .allow, reason: "Budget OK"),
            LawVerdict(lawID: "AuthorityLaw", decision: .escalate, reason: "High risk"),
        ]
        let correlationID = UUID(uuidString: "00000000-0000-0000-0000-000000000099")!

        let original = CompositionTrace(
            verdicts: verdicts,
            compositionRule: .denyWins,
            composedDecision: .deny,
            jurisdictionID: "ClawLaw",
            correlationID: correlationID
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(CompositionTrace.self, from: data)

        #expect(decoded == original)
    }

    @Test("Codable round-trip with nil correlationID")
    func codableRoundTripNilCorrelation() throws {
        let original = CompositionTrace(
            verdicts: [LawVerdict(lawID: "Law1", decision: .allow, reason: "OK")],
            compositionRule: .unanimousAllow,
            composedDecision: .allow,
            jurisdictionID: "ChronicleLaw"
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(CompositionTrace.self, from: data)

        #expect(decoded == original)
        #expect(decoded.correlationID == nil)
    }

    @Test("Equatable compares all fields")
    func equatable() {
        let v1 = [LawVerdict(lawID: "Law1", decision: .allow, reason: "OK")]
        let v2 = [LawVerdict(lawID: "Law1", decision: .deny, reason: "No")]

        let a = CompositionTrace(verdicts: v1, compositionRule: .denyWins, composedDecision: .allow, jurisdictionID: "A")
        let b = CompositionTrace(verdicts: v1, compositionRule: .denyWins, composedDecision: .allow, jurisdictionID: "A")
        let c = CompositionTrace(verdicts: v2, compositionRule: .denyWins, composedDecision: .deny, jurisdictionID: "A")
        let d = CompositionTrace(verdicts: v1, compositionRule: .unanimousAllow, composedDecision: .allow, jurisdictionID: "A")
        let e = CompositionTrace(verdicts: v1, compositionRule: .denyWins, composedDecision: .allow, jurisdictionID: "B")

        #expect(a == b, "Identical traces should be equal")
        #expect(a != c, "Different verdicts should not be equal")
        #expect(a != d, "Different composition rule should not be equal")
        #expect(a != e, "Different jurisdictionID should not be equal")
    }

    @Test("Sendable conformance compiles across actor boundary")
    func sendableConformance() async {
        let trace = CompositionTrace(
            verdicts: [LawVerdict(lawID: "Law1", decision: .allow, reason: "OK")],
            compositionRule: .denyWins,
            composedDecision: .allow,
            jurisdictionID: "Test"
        )

        let result = await Task.detached {
            return trace
        }.value

        #expect(result == trace)
    }
}

// MARK: - CompositionEngine Tests

@Suite("CompositionEngine")
struct CompositionEngineTests {

    // MARK: - denyWins

    @Test("denyWins: single deny overrides multiple allows")
    func denyWinsSingleDenyOverridesAllows() {
        let verdicts = [
            LawVerdict(lawID: "Law1", decision: .allow, reason: "OK"),
            LawVerdict(lawID: "Law2", decision: .allow, reason: "OK"),
            LawVerdict(lawID: "Law3", decision: .deny, reason: "Blocked"),
        ]

        let trace = CompositionEngine.compose(
            verdicts: verdicts,
            rule: .denyWins,
            jurisdictionID: "Test"
        )

        #expect(trace.composedDecision == .deny)
        #expect(trace.verdicts.count == 3)
        #expect(trace.compositionRule == .denyWins)
    }

    @Test("denyWins: all allow produces allow")
    func denyWinsAllAllowProducesAllow() {
        let verdicts = [
            LawVerdict(lawID: "Law1", decision: .allow, reason: "OK"),
            LawVerdict(lawID: "Law2", decision: .allow, reason: "OK"),
        ]

        let trace = CompositionEngine.compose(
            verdicts: verdicts,
            rule: .denyWins,
            jurisdictionID: "Test"
        )

        #expect(trace.composedDecision == .allow)
    }

    @Test("denyWins: escalate without deny produces escalate")
    func denyWinsEscalateWithoutDeny() {
        let verdicts = [
            LawVerdict(lawID: "Law1", decision: .allow, reason: "OK"),
            LawVerdict(lawID: "Law2", decision: .escalate, reason: "Needs approval"),
        ]

        let trace = CompositionEngine.compose(
            verdicts: verdicts,
            rule: .denyWins,
            jurisdictionID: "Test"
        )

        #expect(trace.composedDecision == .escalate)
    }

    @Test("denyWins: deny overrides escalate")
    func denyWinsDenyOverridesEscalate() {
        let verdicts = [
            LawVerdict(lawID: "Law1", decision: .escalate, reason: "Needs approval"),
            LawVerdict(lawID: "Law2", decision: .deny, reason: "Blocked"),
        ]

        let trace = CompositionEngine.compose(
            verdicts: verdicts,
            rule: .denyWins,
            jurisdictionID: "Test"
        )

        #expect(trace.composedDecision == .deny)
    }

    @Test("denyWins: abstain is ignored")
    func denyWinsAbstainIgnored() {
        let verdicts = [
            LawVerdict(lawID: "Law1", decision: .allow, reason: "OK"),
            LawVerdict(lawID: "Law2", decision: .abstain, reason: "No jurisdiction"),
        ]

        let trace = CompositionEngine.compose(
            verdicts: verdicts,
            rule: .denyWins,
            jurisdictionID: "Test"
        )

        #expect(trace.composedDecision == .allow)
    }

    @Test("denyWins: all abstain produces allow")
    func denyWinsAllAbstainProducesAllow() {
        let verdicts = [
            LawVerdict(lawID: "Law1", decision: .abstain, reason: "No jurisdiction"),
            LawVerdict(lawID: "Law2", decision: .abstain, reason: "No jurisdiction"),
        ]

        let trace = CompositionEngine.compose(
            verdicts: verdicts,
            rule: .denyWins,
            jurisdictionID: "Test"
        )

        #expect(trace.composedDecision == .allow)
    }

    // MARK: - unanimousAllow

    @Test("unanimousAllow: all allow produces allow")
    func unanimousAllowAllAllow() {
        let verdicts = [
            LawVerdict(lawID: "Law1", decision: .allow, reason: "OK"),
            LawVerdict(lawID: "Law2", decision: .allow, reason: "OK"),
        ]

        let trace = CompositionEngine.compose(
            verdicts: verdicts,
            rule: .unanimousAllow,
            jurisdictionID: "Test"
        )

        #expect(trace.composedDecision == .allow)
    }

    @Test("unanimousAllow: one deny produces deny")
    func unanimousAllowOneDeny() {
        let verdicts = [
            LawVerdict(lawID: "Law1", decision: .allow, reason: "OK"),
            LawVerdict(lawID: "Law2", decision: .deny, reason: "No"),
        ]

        let trace = CompositionEngine.compose(
            verdicts: verdicts,
            rule: .unanimousAllow,
            jurisdictionID: "Test"
        )

        #expect(trace.composedDecision == .deny)
    }

    @Test("unanimousAllow: escalate without deny produces escalate")
    func unanimousAllowEscalateWithoutDeny() {
        let verdicts = [
            LawVerdict(lawID: "Law1", decision: .allow, reason: "OK"),
            LawVerdict(lawID: "Law2", decision: .escalate, reason: "Needs approval"),
        ]

        let trace = CompositionEngine.compose(
            verdicts: verdicts,
            rule: .unanimousAllow,
            jurisdictionID: "Test"
        )

        #expect(trace.composedDecision == .escalate)
    }

    @Test("unanimousAllow: abstain is ignored, remaining must be unanimous")
    func unanimousAllowAbstainIgnored() {
        let verdicts = [
            LawVerdict(lawID: "Law1", decision: .allow, reason: "OK"),
            LawVerdict(lawID: "Law2", decision: .abstain, reason: "No jurisdiction"),
        ]

        let trace = CompositionEngine.compose(
            verdicts: verdicts,
            rule: .unanimousAllow,
            jurisdictionID: "Test"
        )

        #expect(trace.composedDecision == .allow)
    }

    // MARK: - majorityAllow

    @Test("majorityAllow: majority allow produces allow")
    func majorityAllowMajorityAllow() {
        let verdicts = [
            LawVerdict(lawID: "Law1", decision: .allow, reason: "OK"),
            LawVerdict(lawID: "Law2", decision: .allow, reason: "OK"),
            LawVerdict(lawID: "Law3", decision: .deny, reason: "No"),
        ]

        let trace = CompositionEngine.compose(
            verdicts: verdicts,
            rule: .majorityAllow,
            jurisdictionID: "Test"
        )

        #expect(trace.composedDecision == .allow)
    }

    @Test("majorityAllow: majority deny produces deny")
    func majorityAllowMajorityDeny() {
        let verdicts = [
            LawVerdict(lawID: "Law1", decision: .allow, reason: "OK"),
            LawVerdict(lawID: "Law2", decision: .deny, reason: "No"),
            LawVerdict(lawID: "Law3", decision: .deny, reason: "No"),
        ]

        let trace = CompositionEngine.compose(
            verdicts: verdicts,
            rule: .majorityAllow,
            jurisdictionID: "Test"
        )

        #expect(trace.composedDecision == .deny)
    }

    @Test("majorityAllow: tie goes to deny (not strict majority)")
    func majorityAllowTieGoesToDeny() {
        let verdicts = [
            LawVerdict(lawID: "Law1", decision: .allow, reason: "OK"),
            LawVerdict(lawID: "Law2", decision: .deny, reason: "No"),
        ]

        let trace = CompositionEngine.compose(
            verdicts: verdicts,
            rule: .majorityAllow,
            jurisdictionID: "Test"
        )

        // 1 allow out of 2 is not > 50%, so not allow
        #expect(trace.composedDecision == .deny)
    }

    @Test("majorityAllow: escalate without deny when no majority allow")
    func majorityAllowEscalateWhenNoMajority() {
        let verdicts = [
            LawVerdict(lawID: "Law1", decision: .allow, reason: "OK"),
            LawVerdict(lawID: "Law2", decision: .escalate, reason: "Needs approval"),
            LawVerdict(lawID: "Law3", decision: .escalate, reason: "Needs approval"),
        ]

        let trace = CompositionEngine.compose(
            verdicts: verdicts,
            rule: .majorityAllow,
            jurisdictionID: "Test"
        )

        #expect(trace.composedDecision == .escalate)
    }

    @Test("majorityAllow: abstain is ignored")
    func majorityAllowAbstainIgnored() {
        let verdicts = [
            LawVerdict(lawID: "Law1", decision: .allow, reason: "OK"),
            LawVerdict(lawID: "Law2", decision: .allow, reason: "OK"),
            LawVerdict(lawID: "Law3", decision: .abstain, reason: "No jurisdiction"),
            LawVerdict(lawID: "Law4", decision: .deny, reason: "No"),
        ]

        // 2 allow out of 3 non-abstaining (2 > 3/2 = 1.5) -> allow
        let trace = CompositionEngine.compose(
            verdicts: verdicts,
            rule: .majorityAllow,
            jurisdictionID: "Test"
        )

        #expect(trace.composedDecision == .allow)
    }

    // MARK: - Edge cases

    @Test("Empty verdicts produces allow")
    func emptyVerdictsProducesAllow() {
        let trace = CompositionEngine.compose(
            verdicts: [],
            rule: .denyWins,
            jurisdictionID: "Test"
        )

        #expect(trace.composedDecision == .allow)
        #expect(trace.verdicts.isEmpty)
    }

    @Test("Preserves jurisdictionID and correlationID")
    func preservesMetadata() {
        let correlationID = UUID(uuidString: "00000000-0000-0000-0000-000000000042")!

        let trace = CompositionEngine.compose(
            verdicts: [LawVerdict(lawID: "Law1", decision: .allow, reason: "OK")],
            rule: .denyWins,
            jurisdictionID: "FlightLaw",
            correlationID: correlationID
        )

        #expect(trace.jurisdictionID == "FlightLaw")
        #expect(trace.correlationID == correlationID)
    }

    @Test("Preserves verdict ordering")
    func preservesVerdictOrdering() {
        let verdicts = [
            LawVerdict(lawID: "First", decision: .allow, reason: "1"),
            LawVerdict(lawID: "Second", decision: .deny, reason: "2"),
            LawVerdict(lawID: "Third", decision: .escalate, reason: "3"),
        ]

        let trace = CompositionEngine.compose(
            verdicts: verdicts,
            rule: .denyWins,
            jurisdictionID: "Test"
        )

        #expect(trace.verdicts[0].lawID == "First")
        #expect(trace.verdicts[1].lawID == "Second")
        #expect(trace.verdicts[2].lawID == "Third")
    }

    // MARK: - Determinism

    @Test("Same inputs produce identical traces")
    func determinism() {
        let verdicts = [
            LawVerdict(lawID: "BoundaryLaw", decision: .deny, reason: "Outside sandbox"),
            LawVerdict(lawID: "ResourceLaw", decision: .allow, reason: "Budget OK"),
            LawVerdict(lawID: "AuthorityLaw", decision: .escalate, reason: "High risk"),
        ]
        let correlationID = UUID(uuidString: "00000000-0000-0000-0000-000000000007")!

        let trace1 = CompositionEngine.compose(
            verdicts: verdicts,
            rule: .denyWins,
            jurisdictionID: "ClawLaw",
            correlationID: correlationID
        )
        let trace2 = CompositionEngine.compose(
            verdicts: verdicts,
            rule: .denyWins,
            jurisdictionID: "ClawLaw",
            correlationID: correlationID
        )

        #expect(trace1 == trace2, "Identical inputs must produce identical traces")
    }
}
