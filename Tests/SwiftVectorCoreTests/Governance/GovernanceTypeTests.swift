//
//  GovernanceTypeTests.swift
//  SwiftVectorCoreTests
//
//  Copyright © 2026 Flightworks Aerial LLC. All rights reserved.
//

import Testing
import Foundation
@testable import SwiftVectorCore

// MARK: - LawDecision Tests

@Suite("LawDecision")
struct LawDecisionTests {

    @Test("Has all four governance decision cases")
    func hasFourCases() {
        let decisions: [LawDecision] = [.allow, .deny, .escalate, .abstain]
        #expect(decisions.count == 4)
    }

    @Test("Raw values are stable strings for serialization")
    func rawValuesAreStableStrings() {
        #expect(LawDecision.allow.rawValue == "allow")
        #expect(LawDecision.deny.rawValue == "deny")
        #expect(LawDecision.escalate.rawValue == "escalate")
        #expect(LawDecision.abstain.rawValue == "abstain")
    }

    @Test("Codable round-trip preserves value")
    func codableRoundTrip() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        for decision in LawDecision.allCases {
            let data = try encoder.encode(decision)
            let decoded = try decoder.decode(LawDecision.self, from: data)
            #expect(decoded == decision, "Round-trip failed for \(decision)")
        }
    }

    @Test("Equatable distinguishes all cases")
    func equatableDistinguishesAllCases() {
        #expect(LawDecision.allow == LawDecision.allow)
        #expect(LawDecision.deny == LawDecision.deny)
        #expect(LawDecision.allow != LawDecision.deny)
        #expect(LawDecision.escalate != LawDecision.abstain)
    }

    @Test("Conforms to CaseIterable")
    func caseIterable() {
        #expect(LawDecision.allCases.count == 4)
        #expect(LawDecision.allCases.contains(.allow))
        #expect(LawDecision.allCases.contains(.deny))
        #expect(LawDecision.allCases.contains(.escalate))
        #expect(LawDecision.allCases.contains(.abstain))
    }
}

// MARK: - LawVerdict Tests

@Suite("LawVerdict")
struct LawVerdictTests {

    @Test("Stores lawID, decision, and reason")
    func storesProperties() {
        let verdict = LawVerdict(
            lawID: "BoundaryLaw",
            decision: .deny,
            reason: "Action exceeds filesystem boundary"
        )

        #expect(verdict.lawID == "BoundaryLaw")
        #expect(verdict.decision == .deny)
        #expect(verdict.reason == "Action exceeds filesystem boundary")
    }

    @Test("Codable round-trip preserves all fields")
    func codableRoundTrip() throws {
        let original = LawVerdict(
            lawID: "ResourceLaw",
            decision: .escalate,
            reason: "Token budget at 95% — requires steward approval"
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(LawVerdict.self, from: data)

        #expect(decoded == original)
    }

    @Test("Codable round-trip for each decision type")
    func codableRoundTripAllDecisions() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let decisions: [(LawDecision, String)] = [
            (.allow, "No objection"),
            (.deny, "Denied"),
            (.escalate, "Needs approval"),
            (.abstain, "No jurisdiction"),
        ]

        for (decision, reason) in decisions {
            let verdict = LawVerdict(lawID: "TestLaw", decision: decision, reason: reason)
            let data = try encoder.encode(verdict)
            let decoded = try decoder.decode(LawVerdict.self, from: data)
            #expect(decoded == verdict, "Round-trip failed for decision: \(decision)")
        }
    }

    @Test("Equatable compares all fields")
    func equatableComparesAllFields() {
        let a = LawVerdict(lawID: "Law1", decision: .allow, reason: "OK")
        let b = LawVerdict(lawID: "Law1", decision: .allow, reason: "OK")
        let c = LawVerdict(lawID: "Law2", decision: .allow, reason: "OK")
        let d = LawVerdict(lawID: "Law1", decision: .deny, reason: "OK")
        let e = LawVerdict(lawID: "Law1", decision: .allow, reason: "Different")

        #expect(a == b, "Identical verdicts should be equal")
        #expect(a != c, "Different lawID should not be equal")
        #expect(a != d, "Different decision should not be equal")
        #expect(a != e, "Different reason should not be equal")
    }

    @Test("Sendable conformance compiles across actor boundary")
    func sendableConformance() async {
        let verdict = LawVerdict(lawID: "Test", decision: .allow, reason: "OK")

        let result = await Task.detached {
            return verdict
        }.value

        #expect(result == verdict)
    }
}
