//
//  GovernanceAuditTests.swift
//  SwiftVectorCoreTests
//
//  Copyright © 2026 Flightworks Aerial LLC. All rights reserved.
//

import Testing
import Foundation
import CryptoKit
@testable import SwiftVectorCore
@testable import SwiftVectorTesting

// MARK: - Governance Audit Tests

/// Tests for SV-GOV-4: Audit Trail Integration
///
/// Validates that governance decisions are properly recorded in the audit trail,
/// including the new `.governanceDenied` event type, the optional `governanceTrace`
/// field on `AuditEvent`, and the `governanceDeniedActions()` query on `EventLog`.
///
/// TDD: These tests are written before the implementation.

// MARK: - AuditEventType Governance Tests

@Suite("AuditEventType – Governance")
struct AuditEventTypeGovernanceTests {

    @Test("governanceDenied stores action and agentID")
    func governanceDeniedStoresFields() {
        let eventType: AuditEventType<AuditTestAction> = .governanceDenied(.increment, agentID: "agent-1")

        if case .governanceDenied(let action, let agentID) = eventType {
            #expect(action == .increment)
            #expect(agentID == "agent-1")
        } else {
            Issue.record("Expected governanceDenied event type")
        }
    }

    @Test("governanceDenied is equatable")
    func governanceDeniedEquatable() {
        let a: AuditEventType<AuditTestAction> = .governanceDenied(.increment, agentID: "agent-1")
        let b: AuditEventType<AuditTestAction> = .governanceDenied(.increment, agentID: "agent-1")
        let c: AuditEventType<AuditTestAction> = .governanceDenied(.increment, agentID: "agent-2")
        let d: AuditEventType<AuditTestAction> = .governanceDenied(.decrement, agentID: "agent-1")

        #expect(a == b)
        #expect(a != c)
        #expect(a != d)
    }

    @Test("governanceDenied has description")
    func governanceDeniedDescription() {
        let eventType: AuditEventType<AuditTestAction> = .governanceDenied(.increment, agentID: "test-agent")
        #expect(eventType.description.contains("governanceDenied"))
        #expect(eventType.description.contains("Increment"))
        #expect(eventType.description.contains("test-agent"))
    }

    @Test("governanceDenied Codable round-trip")
    func governanceDeniedCodable() throws {
        let original: AuditEventType<AuditTestAction> = .governanceDenied(.setValue(42), agentID: "gov-agent")

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(AuditEventType<AuditTestAction>.self, from: data)

        #expect(original == decoded)
    }

    @Test("governanceDenied is distinct from actionProposed")
    func governanceDeniedDistinctFromActionProposed() {
        let denied: AuditEventType<AuditTestAction> = .governanceDenied(.increment, agentID: "agent-1")
        let proposed: AuditEventType<AuditTestAction> = .actionProposed(.increment, agentID: "agent-1")

        #expect(denied != proposed)
    }

    @Test("All event types still round-trip including governanceDenied")
    func allEventTypesRoundTripWithGovernance() throws {
        let variants: [AuditEventType<AuditTestAction>] = [
            .initialization,
            .actionProposed(.increment, agentID: "agent"),
            .governanceDenied(.decrement, agentID: "gov-agent"),
            .stateRestored(source: "backup"),
            .systemEvent(description: "test event")
        ]

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        for original in variants {
            let data = try encoder.encode(original)
            let decoded = try decoder.decode(AuditEventType<AuditTestAction>.self, from: data)
            #expect(original == decoded, "Failed round-trip for \(original)")
        }
    }
}

// MARK: - AuditEvent Governance Trace Tests

@Suite("AuditEvent – Governance Trace")
struct AuditEventGovernanceTraceTests {

    let fixedID = UUID(uuidString: "12345678-1234-1234-1234-123456789012")!
    let fixedDate = Date(timeIntervalSince1970: 1000)

    // MARK: - governanceTrace field

    @Test("AuditEvent without governanceTrace defaults to nil")
    func governanceTraceDefaultsToNil() {
        let event = AuditEvent<AuditTestAction>(
            id: fixedID,
            timestamp: fixedDate,
            eventType: .actionProposed(.increment, agentID: "agent"),
            stateHashBefore: "before",
            stateHashAfter: "after",
            applied: true,
            rationale: "OK"
        )

        #expect(event.governanceTrace == nil)
    }

    @Test("AuditEvent stores governanceTrace when provided")
    func governanceTraceStored() {
        let trace = CompositionTrace(
            verdicts: [
                LawVerdict(lawID: "BoundaryLaw", decision: .deny, reason: "Outside sandbox"),
                LawVerdict(lawID: "ResourceLaw", decision: .allow, reason: "Budget OK")
            ],
            compositionRule: .denyWins,
            composedDecision: .deny,
            jurisdictionID: "ClawLaw"
        )

        let event = AuditEvent<AuditTestAction>(
            id: fixedID,
            timestamp: fixedDate,
            eventType: .governanceDenied(.increment, agentID: "agent"),
            stateHashBefore: "hash",
            stateHashAfter: "hash",
            applied: false,
            rationale: "Governance denied: BoundaryLaw",
            previousEntryHash: "",
            governanceTrace: trace
        )

        #expect(event.governanceTrace != nil)
        #expect(event.governanceTrace?.composedDecision == .deny)
        #expect(event.governanceTrace?.verdicts.count == 2)
        #expect(event.governanceTrace?.jurisdictionID == "ClawLaw")
    }

    // MARK: - Factory methods

    @Test("governanceDenied factory creates correct event")
    func governanceDeniedFactory() {
        let trace = CompositionTrace(
            verdicts: [
                LawVerdict(lawID: "TestLaw", decision: .deny, reason: "Denied by test law")
            ],
            compositionRule: .denyWins,
            composedDecision: .deny,
            jurisdictionID: "TestJurisdiction"
        )

        let event = AuditEvent<AuditTestAction>.governanceDenied(
            id: fixedID,
            timestamp: fixedDate,
            action: .increment,
            agentID: "agent-1",
            stateHash: "unchanged-hash",
            trace: trace,
            previousEntryHash: "prev-hash"
        )

        #expect(event.applied == false)
        #expect(event.stateHashBefore == "unchanged-hash")
        #expect(event.stateHashAfter == "unchanged-hash")
        #expect(event.previousEntryHash == "prev-hash")
        #expect(event.governanceTrace == trace)

        if case .governanceDenied(let action, let agentID) = event.eventType {
            #expect(action == .increment)
            #expect(agentID == "agent-1")
        } else {
            Issue.record("Expected governanceDenied event type")
        }
    }

    @Test("acceptedWithGovernance factory creates correct event")
    func acceptedWithGovernanceFactory() {
        let trace = CompositionTrace(
            verdicts: [
                LawVerdict(lawID: "ResourceLaw", decision: .allow, reason: "Budget OK"),
                LawVerdict(lawID: "BoundaryLaw", decision: .allow, reason: "Within sandbox")
            ],
            compositionRule: .unanimousAllow,
            composedDecision: .allow,
            jurisdictionID: "FlightLaw"
        )

        let event = AuditEvent<AuditTestAction>.acceptedWithGovernance(
            id: fixedID,
            timestamp: fixedDate,
            action: .setValue(42),
            agentID: "agent-1",
            stateHashBefore: "before",
            stateHashAfter: "after",
            rationale: "Accepted with governance",
            trace: trace,
            previousEntryHash: "prev-hash"
        )

        #expect(event.applied == true)
        #expect(event.stateHashBefore == "before")
        #expect(event.stateHashAfter == "after")
        #expect(event.governanceTrace == trace)
        #expect(event.governanceTrace?.composedDecision == .allow)

        if case .actionProposed(let action, let agentID) = event.eventType {
            #expect(action == .setValue(42))
            #expect(agentID == "agent-1")
        } else {
            Issue.record("Expected actionProposed event type")
        }
    }

    // MARK: - Codable with governanceTrace

    @Test("AuditEvent with governanceTrace Codable round-trip")
    func auditEventWithTraceCodable() throws {
        let trace = CompositionTrace(
            verdicts: [
                LawVerdict(lawID: "Law1", decision: .deny, reason: "Reason 1"),
                LawVerdict(lawID: "Law2", decision: .allow, reason: "Reason 2")
            ],
            compositionRule: .denyWins,
            composedDecision: .deny,
            jurisdictionID: "TestDomain"
        )

        let original = AuditEvent<AuditTestAction>(
            id: fixedID,
            timestamp: fixedDate,
            eventType: .governanceDenied(.increment, agentID: "agent"),
            stateHashBefore: "hash",
            stateHashAfter: "hash",
            applied: false,
            rationale: "Denied",
            previousEntryHash: "prev",
            governanceTrace: trace
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(AuditEvent<AuditTestAction>.self, from: data)

        #expect(original == decoded)
        #expect(decoded.governanceTrace == trace)
    }

    @Test("AuditEvent without governanceTrace still Codable")
    func auditEventWithoutTraceCodable() throws {
        let original = AuditEvent<AuditTestAction>.accepted(
            id: fixedID,
            timestamp: fixedDate,
            action: .increment,
            agentID: "agent",
            stateHashBefore: "before",
            stateHashAfter: "after",
            rationale: "OK",
            previousEntryHash: "prev"
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(AuditEvent<AuditTestAction>.self, from: data)

        #expect(original == decoded)
        #expect(decoded.governanceTrace == nil)
    }

    // MARK: - Equatable with governanceTrace

    @Test("AuditEvent equality considers governanceTrace")
    func auditEventEqualityWithTrace() {
        let trace = CompositionTrace(
            verdicts: [LawVerdict(lawID: "Law1", decision: .deny, reason: "No")],
            compositionRule: .denyWins,
            composedDecision: .deny,
            jurisdictionID: "Test"
        )

        let eventWithTrace = AuditEvent<AuditTestAction>(
            id: fixedID,
            timestamp: fixedDate,
            eventType: .governanceDenied(.increment, agentID: "agent"),
            stateHashBefore: "hash",
            stateHashAfter: "hash",
            applied: false,
            rationale: "Denied",
            previousEntryHash: "",
            governanceTrace: trace
        )

        let eventWithoutTrace = AuditEvent<AuditTestAction>(
            id: fixedID,
            timestamp: fixedDate,
            eventType: .governanceDenied(.increment, agentID: "agent"),
            stateHashBefore: "hash",
            stateHashAfter: "hash",
            applied: false,
            rationale: "Denied",
            previousEntryHash: ""
        )

        #expect(eventWithTrace != eventWithoutTrace)
    }

    // MARK: - Hash includes governanceTrace

    @Test("Entry hash changes when governanceTrace present vs absent")
    func entryHashChangesWithTrace() {
        let trace = CompositionTrace(
            verdicts: [LawVerdict(lawID: "Law1", decision: .deny, reason: "No")],
            compositionRule: .denyWins,
            composedDecision: .deny,
            jurisdictionID: "Test"
        )

        let eventWithTrace = AuditEvent<AuditTestAction>(
            id: fixedID,
            timestamp: fixedDate,
            eventType: .governanceDenied(.increment, agentID: "agent"),
            stateHashBefore: "hash",
            stateHashAfter: "hash",
            applied: false,
            rationale: "Denied",
            previousEntryHash: "",
            governanceTrace: trace
        )

        let eventWithoutTrace = AuditEvent<AuditTestAction>(
            id: fixedID,
            timestamp: fixedDate,
            eventType: .governanceDenied(.increment, agentID: "agent"),
            stateHashBefore: "hash",
            stateHashAfter: "hash",
            applied: false,
            rationale: "Denied",
            previousEntryHash: ""
        )

        #expect(eventWithTrace.entryHash != eventWithoutTrace.entryHash,
                "Governance trace must affect entry hash for tamper detection")
    }

    @Test("Entry hash is deterministic with governanceTrace")
    func entryHashDeterministicWithTrace() {
        let trace = CompositionTrace(
            verdicts: [
                LawVerdict(lawID: "Law1", decision: .deny, reason: "Reason"),
                LawVerdict(lawID: "Law2", decision: .allow, reason: "OK")
            ],
            compositionRule: .denyWins,
            composedDecision: .deny,
            jurisdictionID: "Domain"
        )

        let event1 = AuditEvent<AuditTestAction>(
            id: fixedID,
            timestamp: fixedDate,
            eventType: .governanceDenied(.increment, agentID: "agent"),
            stateHashBefore: "hash",
            stateHashAfter: "hash",
            applied: false,
            rationale: "Denied",
            previousEntryHash: "",
            governanceTrace: trace
        )

        let event2 = AuditEvent<AuditTestAction>(
            id: fixedID,
            timestamp: fixedDate,
            eventType: .governanceDenied(.increment, agentID: "agent"),
            stateHashBefore: "hash",
            stateHashAfter: "hash",
            applied: false,
            rationale: "Denied",
            previousEntryHash: "",
            governanceTrace: trace
        )

        #expect(event1.entryHash == event2.entryHash,
                "Same content + same trace should produce same hash")
    }
}

// MARK: - EventLog Governance Query Tests

@Suite("EventLog – Governance Queries")
struct EventLogGovernanceQueryTests {

    let clock = MockClock(fixed: Date(timeIntervalSince1970: 0))
    let uuids = MockUUIDGenerator(sequential: 1)

    @Test("governanceDeniedActions returns only governance-denied events")
    func governanceDeniedActionsQuery() {
        let trace = CompositionTrace(
            verdicts: [LawVerdict(lawID: "TestLaw", decision: .deny, reason: "Denied")],
            compositionRule: .denyWins,
            composedDecision: .deny,
            jurisdictionID: "Test"
        )

        var log = EventLog<AuditTestAction>()

        // Initialization
        log.append(.initialization(
            id: uuids.next(),
            timestamp: clock.now(),
            initialStateHash: "h1"
        ))

        // Normal accepted action
        log.append(.accepted(
            id: uuids.next(),
            timestamp: clock.now(),
            action: .increment,
            agentID: "agent-1",
            stateHashBefore: "h1",
            stateHashAfter: "h2",
            rationale: "OK",
            previousEntryHash: ""
        ))

        // Governance denied action
        log.append(.governanceDenied(
            id: uuids.next(),
            timestamp: clock.now(),
            action: .decrement,
            agentID: "agent-2",
            stateHash: "h2",
            trace: trace,
            previousEntryHash: ""
        ))

        // Normal rejected action (reducer rejection, not governance)
        log.append(.rejected(
            id: uuids.next(),
            timestamp: clock.now(),
            action: .setValue(-1),
            agentID: "agent-1",
            stateHash: "h2",
            rationale: "Value must be non-negative",
            previousEntryHash: ""
        ))

        // Another governance denied action
        let trace2 = CompositionTrace(
            verdicts: [LawVerdict(lawID: "OtherLaw", decision: .deny, reason: "Nope")],
            compositionRule: .unanimousAllow,
            composedDecision: .deny,
            jurisdictionID: "Other"
        )
        log.append(.governanceDenied(
            id: uuids.next(),
            timestamp: clock.now(),
            action: .increment,
            agentID: "agent-3",
            stateHash: "h2",
            trace: trace2,
            previousEntryHash: ""
        ))

        let denied = log.governanceDeniedActions()
        #expect(denied.count == 2)
        #expect(denied[0].action == .decrement)
        #expect(denied[0].agentID == "agent-2")
        #expect(denied[0].trace.jurisdictionID == "Test")
        #expect(denied[1].action == .increment)
        #expect(denied[1].agentID == "agent-3")
        #expect(denied[1].trace.jurisdictionID == "Other")
    }

    @Test("governanceDeniedActions returns empty when no governance denials")
    func governanceDeniedActionsEmpty() {
        var log = EventLog<AuditTestAction>()

        log.append(.initialization(
            id: uuids.next(),
            timestamp: clock.now(),
            initialStateHash: "h1"
        ))

        log.append(.accepted(
            id: uuids.next(),
            timestamp: clock.now(),
            action: .increment,
            agentID: "agent",
            stateHashBefore: "h1",
            stateHashAfter: "h2",
            rationale: "OK",
            previousEntryHash: ""
        ))

        let denied = log.governanceDeniedActions()
        #expect(denied.isEmpty)
    }
}

// MARK: - EventLog Chain Verification with Governance Tests

@Suite("EventLog – Governance Chain Verification")
struct EventLogGovernanceChainTests {

    let clock = MockClock(fixed: Date(timeIntervalSince1970: 0))
    let uuids = MockUUIDGenerator(sequential: 1)

    @Test("Chain verification passes with governance events mixed in")
    func chainVerificationWithGovernanceEvents() {
        let trace = CompositionTrace(
            verdicts: [LawVerdict(lawID: "TestLaw", decision: .deny, reason: "Denied")],
            compositionRule: .denyWins,
            composedDecision: .deny,
            jurisdictionID: "Test"
        )

        var log = EventLog<AuditTestAction>()

        log.append(.initialization(
            id: uuids.next(),
            timestamp: clock.now(),
            initialStateHash: "h1"
        ))

        // Accepted action
        clock.advance(by: 1)
        log.append(.accepted(
            id: uuids.next(),
            timestamp: clock.now(),
            action: .increment,
            agentID: "agent",
            stateHashBefore: "h1",
            stateHashAfter: "h2",
            rationale: "OK",
            previousEntryHash: ""
        ))

        // Governance denied — state unchanged
        clock.advance(by: 1)
        log.append(.governanceDenied(
            id: uuids.next(),
            timestamp: clock.now(),
            action: .decrement,
            agentID: "agent",
            stateHash: "h2",
            trace: trace,
            previousEntryHash: ""
        ))

        // Another accepted action after governance denial
        clock.advance(by: 1)
        log.append(.accepted(
            id: uuids.next(),
            timestamp: clock.now(),
            action: .increment,
            agentID: "agent",
            stateHashBefore: "h2",
            stateHashAfter: "h3",
            rationale: "OK",
            previousEntryHash: ""
        ))

        let result = log.verify()
        #expect(result.isValid, "Chain with governance events should verify correctly")
    }

    @Test("EventLog append preserves governanceTrace through chain linking")
    func appendPreservesGovernanceTrace() {
        let trace = CompositionTrace(
            verdicts: [
                LawVerdict(lawID: "Law1", decision: .deny, reason: "No"),
                LawVerdict(lawID: "Law2", decision: .escalate, reason: "Maybe")
            ],
            compositionRule: .denyWins,
            composedDecision: .deny,
            jurisdictionID: "Domain"
        )

        var log = EventLog<AuditTestAction>()

        log.append(.initialization(
            id: uuids.next(),
            timestamp: clock.now(),
            initialStateHash: "h1"
        ))

        // Append governance denied event
        log.append(.governanceDenied(
            id: uuids.next(),
            timestamp: clock.now(),
            action: .increment,
            agentID: "agent",
            stateHash: "h1",
            trace: trace,
            previousEntryHash: ""
        ))

        // Verify the trace survived append's chain-linking reconstruction
        #expect(log[1].governanceTrace != nil)
        #expect(log[1].governanceTrace == trace)
        #expect(log[1].governanceTrace?.verdicts.count == 2)
    }
}

// MARK: - EventLog Replay with Governance Tests

@Suite("EventLog – Governance Replay")
struct EventLogGovernanceReplayTests {

    let clock = MockClock(fixed: Date(timeIntervalSince1970: 0))
    let uuids = MockUUIDGenerator(sequential: 1)

    @Test("verifyReplay handles governanceDenied events (state unchanged)")
    func verifyReplayWithGovernanceDenied() {
        let reducer = AuditTestReducer()
        var state = AuditTestState(value: 0)
        var log = EventLog<AuditTestAction>()

        let trace = CompositionTrace(
            verdicts: [LawVerdict(lawID: "TestLaw", decision: .deny, reason: "Denied")],
            compositionRule: .denyWins,
            composedDecision: .deny,
            jurisdictionID: "Test"
        )

        // Initialize
        log.append(.initialization(
            id: uuids.next(),
            timestamp: clock.now(),
            initialStateHash: state.stateHash()
        ))

        // Apply increment (accepted)
        clock.advance(by: 1)
        let hashBefore1 = state.stateHash()
        let result1 = reducer.reduce(state: state, action: .increment)
        state = result1.newState
        log.append(.accepted(
            id: uuids.next(),
            timestamp: clock.now(),
            action: .increment,
            agentID: "agent",
            stateHashBefore: hashBefore1,
            stateHashAfter: state.stateHash(),
            rationale: result1.rationale,
            previousEntryHash: ""
        ))

        // Governance denied — state stays the same
        clock.advance(by: 1)
        log.append(.governanceDenied(
            id: uuids.next(),
            timestamp: clock.now(),
            action: .decrement,
            agentID: "agent",
            stateHash: state.stateHash(),
            trace: trace,
            previousEntryHash: ""
        ))

        // Apply another increment (accepted)
        clock.advance(by: 1)
        let hashBefore3 = state.stateHash()
        let result3 = reducer.reduce(state: state, action: .increment)
        state = result3.newState
        log.append(.accepted(
            id: uuids.next(),
            timestamp: clock.now(),
            action: .increment,
            agentID: "agent",
            stateHashBefore: hashBefore3,
            stateHashAfter: state.stateHash(),
            rationale: result3.rationale,
            previousEntryHash: ""
        ))

        // Replay should pass — governance denied events don't change state
        let verification = log.verifyReplay(
            initialState: AuditTestState(value: 0),
            reducer: reducer
        )

        #expect(verification.isValid)
        #expect(state.value == 2)
    }

    @Test("verifyReplay validates governanceDenied state unchanged")
    func verifyReplayDetectsBadGovernanceDenied() {
        let state = AuditTestState(value: 0)
        var log = EventLog<AuditTestAction>()

        let trace = CompositionTrace(
            verdicts: [LawVerdict(lawID: "TestLaw", decision: .deny, reason: "No")],
            compositionRule: .denyWins,
            composedDecision: .deny,
            jurisdictionID: "Test"
        )

        // Initialize
        log.append(.initialization(
            id: uuids.next(),
            timestamp: clock.now(),
            initialStateHash: state.stateHash()
        ))

        // Governance denied but with wrong state hashes (claims state changed)
        let badEvent = AuditEvent<AuditTestAction>(
            id: uuids.next(),
            timestamp: clock.now(),
            eventType: .governanceDenied(.increment, agentID: "agent"),
            stateHashBefore: state.stateHash(),
            stateHashAfter: "WRONG_HASH",  // Should equal stateHashBefore
            applied: false,
            rationale: "Governance denied",
            previousEntryHash: log.lastEntryHash,
            governanceTrace: trace
        )

        let tamperedLog = EventLog<AuditTestAction>(entries: [log[0], badEvent])

        let result = tamperedLog.verifyReplay(
            initialState: state,
            reducer: AuditTestReducer()
        )

        #expect(!result.isValid)
    }
}

// MARK: - Backward Compatibility Tests

@Suite("Governance Audit – Backward Compatibility")
struct GovernanceAuditBackwardCompatibilityTests {

    let clock = MockClock(fixed: Date(timeIntervalSince1970: 0))
    let uuids = MockUUIDGenerator(sequential: 1)

    @Test("Existing AuditEvent init works without governanceTrace")
    func existingInitStillWorks() {
        // This tests that the default nil parameter doesn't break existing call sites
        let event = AuditEvent<AuditTestAction>(
            id: uuids.next(),
            timestamp: clock.now(),
            eventType: .actionProposed(.increment, agentID: "agent"),
            stateHashBefore: "before",
            stateHashAfter: "after",
            applied: true,
            rationale: "OK",
            previousEntryHash: ""
        )

        #expect(event.governanceTrace == nil)
        #expect(event.applied == true)
    }

    @Test("Existing factory methods work without governanceTrace")
    func existingFactoriesStillWork() {
        let accepted = AuditEvent<AuditTestAction>.accepted(
            id: uuids.next(),
            timestamp: clock.now(),
            action: .increment,
            agentID: "agent",
            stateHashBefore: "before",
            stateHashAfter: "after",
            rationale: "OK",
            previousEntryHash: ""
        )
        #expect(accepted.governanceTrace == nil)

        let rejected = AuditEvent<AuditTestAction>.rejected(
            id: uuids.next(),
            timestamp: clock.now(),
            action: .decrement,
            agentID: "agent",
            stateHash: "hash",
            rationale: "No",
            previousEntryHash: ""
        )
        #expect(rejected.governanceTrace == nil)

        let initEvent = AuditEvent<AuditTestAction>.initialization(
            id: uuids.next(),
            timestamp: clock.now(),
            initialStateHash: "hash"
        )
        #expect(initEvent.governanceTrace == nil)
    }

    @Test("Serialized log without governanceTrace still decodes correctly")
    func oldFormatDecodes() throws {
        // Build a log the "old way" (no governance trace)
        var log = EventLog<AuditTestAction>()

        log.append(.initialization(
            id: uuids.next(),
            timestamp: clock.now(),
            initialStateHash: "h1"
        ))

        log.append(.accepted(
            id: uuids.next(),
            timestamp: clock.now(),
            action: .increment,
            agentID: "agent",
            stateHashBefore: "h1",
            stateHashAfter: "h2",
            rationale: "OK",
            previousEntryHash: ""
        ))

        // Serialize
        let encoder = JSONEncoder()
        let data = try encoder.encode(log)

        // Decode — should work even though governanceTrace wasn't encoded
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(EventLog<AuditTestAction>.self, from: data)

        #expect(decoded.count == 2)
        #expect(decoded.verify().isValid)
        #expect(decoded[0].governanceTrace == nil)
        #expect(decoded[1].governanceTrace == nil)
    }
}

// MARK: - Integration: Full Governance Audit Cycle

@Suite("Governance Audit – Integration")
struct GovernanceAuditIntegrationTests {

    @Test("Full audit cycle with governance denials and acceptances")
    func fullGovernanceAuditCycle() {
        let clock = MockClock(fixed: Date(timeIntervalSince1970: 1000))
        let uuids = MockUUIDGenerator(sequential: 1)
        let reducer = AuditTestReducer()

        var state = AuditTestState(value: 0)
        var log = EventLog<AuditTestAction>()

        // Initialize
        log.append(.initialization(
            id: uuids.next(),
            timestamp: clock.now(),
            initialStateHash: state.stateHash()
        ))

        // Action 1: Governance allows, reducer accepts
        clock.advance(by: 1)
        let allowTrace = CompositionTrace(
            verdicts: [
                LawVerdict(lawID: "ResourceLaw", decision: .allow, reason: "Budget OK")
            ],
            compositionRule: .denyWins,
            composedDecision: .allow,
            jurisdictionID: "ChronicleLaw"
        )
        let hashBefore1 = state.stateHash()
        let result1 = reducer.reduce(state: state, action: .increment)
        state = result1.newState
        log.append(.acceptedWithGovernance(
            id: uuids.next(),
            timestamp: clock.now(),
            action: .increment,
            agentID: "agent-1",
            stateHashBefore: hashBefore1,
            stateHashAfter: state.stateHash(),
            rationale: result1.rationale,
            trace: allowTrace,
            previousEntryHash: ""
        ))

        // Action 2: Governance denies — multiple violations
        clock.advance(by: 1)
        let denyTrace = CompositionTrace(
            verdicts: [
                LawVerdict(lawID: "GameOverLaw", decision: .deny, reason: "Character is dead"),
                LawVerdict(lawID: "GoldBudgetLaw", decision: .deny, reason: "Amount exceeds limit")
            ],
            compositionRule: .denyWins,
            composedDecision: .deny,
            jurisdictionID: "ChronicleLaw"
        )
        log.append(.governanceDenied(
            id: uuids.next(),
            timestamp: clock.now(),
            action: .setValue(999),
            agentID: "agent-2",
            stateHash: state.stateHash(),
            trace: denyTrace,
            previousEntryHash: ""
        ))

        // Action 3: Normal action (no governance), accepted
        clock.advance(by: 1)
        let hashBefore3 = state.stateHash()
        let result3 = reducer.reduce(state: state, action: .increment)
        state = result3.newState
        log.append(.accepted(
            id: uuids.next(),
            timestamp: clock.now(),
            action: .increment,
            agentID: "agent-1",
            stateHashBefore: hashBefore3,
            stateHashAfter: state.stateHash(),
            rationale: result3.rationale,
            previousEntryHash: ""
        ))

        // Verify
        #expect(log.count == 4)
        #expect(log.verify().isValid)
        #expect(log.acceptedActions().count == 2)
        #expect(log.governanceDeniedActions().count == 1)

        let denied = log.governanceDeniedActions()
        #expect(denied[0].trace.verdicts.count == 2)
        #expect(denied[0].trace.verdicts[0].lawID == "GameOverLaw")
        #expect(denied[0].trace.verdicts[1].lawID == "GoldBudgetLaw")

        // Verify replay
        let replayResult = log.verifyReplay(
            initialState: AuditTestState(value: 0),
            reducer: reducer
        )
        #expect(replayResult.isValid)

        // Final state
        #expect(state.value == 2)
    }

    @Test("Serialization round-trip preserves governance traces in chain")
    func serializationPreservesGovernanceTraces() throws {
        let clock = MockClock(fixed: Date(timeIntervalSince1970: 0))
        let uuids = MockUUIDGenerator(sequential: 1)

        let trace = CompositionTrace(
            verdicts: [
                LawVerdict(lawID: "Law1", decision: .deny, reason: "Reason 1"),
                LawVerdict(lawID: "Law2", decision: .allow, reason: "Reason 2")
            ],
            compositionRule: .denyWins,
            composedDecision: .deny,
            jurisdictionID: "TestDomain"
        )

        var log = EventLog<AuditTestAction>()

        log.append(.initialization(
            id: uuids.next(),
            timestamp: clock.now(),
            initialStateHash: "h1"
        ))

        clock.advance(by: 1)
        log.append(.governanceDenied(
            id: uuids.next(),
            timestamp: clock.now(),
            action: .increment,
            agentID: "agent",
            stateHash: "h1",
            trace: trace,
            previousEntryHash: ""
        ))

        // Serialize and restore
        let encoder = JSONEncoder()
        let data = try encoder.encode(log)

        let decoder = JSONDecoder()
        let restored = try decoder.decode(EventLog<AuditTestAction>.self, from: data)

        // Chain integrity preserved
        #expect(restored.verify().isValid)

        // Governance trace preserved
        #expect(restored[1].governanceTrace == trace)

        // Entry hashes match
        for i in 0..<log.count {
            #expect(log[i].entryHash == restored[i].entryHash)
        }
    }
}
