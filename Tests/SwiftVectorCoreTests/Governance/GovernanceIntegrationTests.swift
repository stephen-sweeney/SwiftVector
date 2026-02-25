//
//  GovernanceIntegrationTests.swift
//  SwiftVectorCoreTests
//
//  Copyright © 2026 Flightworks Aerial LLC. All rights reserved.
//

import Foundation
import Testing
@testable import SwiftVectorCore
@testable import SwiftVectorTesting

// MARK: - Governance Integration Tests

/// Tests for SV-GOV-5: Orchestrator Integration
///
/// Validates that `GovernancePolicy` evaluates Laws correctly and that
/// `BaseOrchestrator` integrates governance evaluation into its control loop.
///
/// TDD: These tests are written before the implementation.

// MARK: - GovernancePolicy Tests

@Suite("GovernancePolicy")
struct GovernancePolicyTests {

    @Test("GovernancePolicy evaluate returns allow trace when all laws allow")
    func evaluateAllAllow() {
        let allowLaw = AnyLaw<TestState, TestAction>(lawID: "AllowLaw") { _, _ in
            LawVerdict(lawID: "AllowLaw", decision: .allow, reason: "OK")
        }

        let policy = GovernancePolicy(
            laws: [allowLaw],
            compositionRule: .denyWins,
            jurisdictionID: "TestDomain"
        )

        let state = TestState()
        let trace = policy.evaluate(state: state, action: .increment)

        #expect(trace.composedDecision == .allow)
        #expect(trace.verdicts.count == 1)
        #expect(trace.compositionRule == .denyWins)
        #expect(trace.jurisdictionID == "TestDomain")
    }

    @Test("GovernancePolicy evaluate returns deny trace when law denies")
    func evaluateDeny() {
        let denyLaw = AnyLaw<TestState, TestAction>(lawID: "DenyLaw") { _, _ in
            LawVerdict(lawID: "DenyLaw", decision: .deny, reason: "Forbidden")
        }

        let policy = GovernancePolicy(
            laws: [denyLaw],
            compositionRule: .denyWins,
            jurisdictionID: "TestDomain"
        )

        let trace = policy.evaluate(state: TestState(), action: .increment)

        #expect(trace.composedDecision == .deny)
        #expect(trace.verdicts.count == 1)
        #expect(trace.verdicts[0].reason == "Forbidden")
    }

    @Test("GovernancePolicy composes multiple laws")
    func evaluateMultipleLaws() {
        let allowLaw = AnyLaw<TestState, TestAction>(lawID: "AllowLaw") { _, _ in
            LawVerdict(lawID: "AllowLaw", decision: .allow, reason: "OK")
        }
        let denyLaw = AnyLaw<TestState, TestAction>(lawID: "DenyLaw") { _, _ in
            LawVerdict(lawID: "DenyLaw", decision: .deny, reason: "Blocked")
        }

        let policy = GovernancePolicy(
            laws: [allowLaw, denyLaw],
            compositionRule: .denyWins,
            jurisdictionID: "TestDomain"
        )

        let trace = policy.evaluate(state: TestState(), action: .increment)

        #expect(trace.composedDecision == .deny)
        #expect(trace.verdicts.count == 2)
        #expect(trace.verdicts[0].lawID == "AllowLaw")
        #expect(trace.verdicts[1].lawID == "DenyLaw")
    }

    @Test("GovernancePolicy is deterministic")
    func evaluateDeterministic() {
        let law = AnyLaw<TestState, TestAction>(lawID: "TestLaw") { state, action in
            if case .decrement = action, state.counter == 0 {
                return LawVerdict(lawID: "TestLaw", decision: .deny, reason: "Cannot decrement at zero")
            }
            return LawVerdict(lawID: "TestLaw", decision: .allow, reason: "OK")
        }

        let policy = GovernancePolicy(
            laws: [law],
            compositionRule: .denyWins,
            jurisdictionID: "TestDomain"
        )

        let state = TestState(counter: 0)
        let trace1 = policy.evaluate(state: state, action: .decrement)
        let trace2 = policy.evaluate(state: state, action: .decrement)

        #expect(trace1 == trace2)
    }

    @Test("GovernancePolicy evaluate is a pure function")
    func evaluatePureFunction() {
        let law = AnyLaw<TestState, TestAction>(lawID: "CounterLaw") { state, _ in
            if state.counter > 5 {
                return LawVerdict(lawID: "CounterLaw", decision: .deny, reason: "Counter too high")
            }
            return LawVerdict(lawID: "CounterLaw", decision: .allow, reason: "OK")
        }

        let policy = GovernancePolicy(
            laws: [law],
            compositionRule: .denyWins,
            jurisdictionID: "TestDomain"
        )

        // Different states produce different results
        let lowState = TestState(counter: 3)
        let highState = TestState(counter: 10)

        let lowTrace = policy.evaluate(state: lowState, action: .increment)
        let highTrace = policy.evaluate(state: highState, action: .increment)

        #expect(lowTrace.composedDecision == .allow)
        #expect(highTrace.composedDecision == .deny)
    }

    @Test("GovernancePolicy with no laws allows all actions")
    func emptyPolicyAllows() {
        let policy = GovernancePolicy<TestState, TestAction>(
            laws: [],
            compositionRule: .denyWins,
            jurisdictionID: "EmptyDomain"
        )

        let trace = policy.evaluate(state: TestState(), action: .increment)

        #expect(trace.composedDecision == .allow)
        #expect(trace.verdicts.isEmpty)
    }

    @Test("GovernancePolicy passes correlationID to trace")
    func correlationIDPassedThrough() {
        let law = AnyLaw<TestState, TestAction>(lawID: "Law") { _, _ in
            LawVerdict(lawID: "Law", decision: .allow, reason: "OK")
        }

        let correlationID = UUID(uuidString: "12345678-1234-1234-1234-123456789012")!

        let policy = GovernancePolicy(
            laws: [law],
            compositionRule: .denyWins,
            jurisdictionID: "TestDomain"
        )

        let trace = policy.evaluate(
            state: TestState(),
            action: .increment,
            correlationID: correlationID
        )

        #expect(trace.correlationID == correlationID)
    }
}

// MARK: - BaseOrchestrator Governance Integration Tests

@Suite("BaseOrchestrator – Governance")
struct BaseOrchestratorGovernanceTests {

    // MARK: - No-Policy Regression

    @Test("No-policy regression: BaseOrchestrator without policy behaves identically")
    func noPolicyRegression() async {
        let clock = MockClock(fixed: Date(timeIntervalSince1970: 0))
        let uuids = MockUUIDGenerator(sequential: 1)

        let base = BaseOrchestrator(
            initialState: TestState(),
            reducer: TestAction.TestReducer(),
            clock: clock,
            uuidGenerator: uuids
        )

        let result = await base.submit(.increment, agentID: "agent-1")
        #expect(result.applied == true)

        let state = await base.currentState
        #expect(state.counter == 1)

        let log = await base.auditLog()
        #expect(log.count == 2)
        #expect(log.verify().isValid)
    }

    // MARK: - All-Allow Policy

    @Test("All-allow policy: reducer still runs, trace recorded in audit")
    func allAllowPolicyReducerRuns() async {
        let clock = MockClock(fixed: Date(timeIntervalSince1970: 0))
        let uuids = MockUUIDGenerator(sequential: 1)

        let allowLaw = AnyLaw<TestState, TestAction>(lawID: "AllowLaw") { _, _ in
            LawVerdict(lawID: "AllowLaw", decision: .allow, reason: "OK")
        }

        let policy = GovernancePolicy(
            laws: [allowLaw],
            compositionRule: .denyWins,
            jurisdictionID: "TestDomain"
        )

        let base = BaseOrchestrator(
            initialState: TestState(),
            reducer: TestAction.TestReducer(),
            clock: clock,
            uuidGenerator: uuids,
            governancePolicy: policy
        )

        let result = await base.submit(.increment, agentID: "agent-1")
        #expect(result.applied == true)

        let state = await base.currentState
        #expect(state.counter == 1)

        let log = await base.auditLog()
        #expect(log.count == 2)

        // The accepted event should have a governance trace
        let lastEntry = log[1]
        #expect(lastEntry.governanceTrace != nil)
        #expect(lastEntry.governanceTrace?.composedDecision == .allow)
        #expect(lastEntry.applied == true)
    }

    // MARK: - Deny Policy

    @Test("Deny policy: reducer never runs, state unchanged, governanceDenied in audit")
    func denyPolicyBlocksReducer() async {
        let clock = MockClock(fixed: Date(timeIntervalSince1970: 0))
        let uuids = MockUUIDGenerator(sequential: 1)

        let denyLaw = AnyLaw<TestState, TestAction>(lawID: "DenyLaw") { _, _ in
            LawVerdict(lawID: "DenyLaw", decision: .deny, reason: "All actions blocked")
        }

        let policy = GovernancePolicy(
            laws: [denyLaw],
            compositionRule: .denyWins,
            jurisdictionID: "TestDomain"
        )

        let base = BaseOrchestrator(
            initialState: TestState(),
            reducer: TestAction.TestReducer(),
            clock: clock,
            uuidGenerator: uuids,
            governancePolicy: policy
        )

        let result = await base.submit(.increment, agentID: "agent-1")
        #expect(result.applied == false)

        let state = await base.currentState
        #expect(state.counter == 0, "State should be unchanged when governance denies")

        let log = await base.auditLog()
        #expect(log.count == 2)

        let lastEntry = log[1]
        if case .governanceDenied(_, let agentID) = lastEntry.eventType {
            #expect(agentID == "agent-1")
        } else {
            Issue.record("Expected governanceDenied event type, got \(lastEntry.eventType)")
        }

        #expect(lastEntry.applied == false)
        #expect(lastEntry.stateHashBefore == lastEntry.stateHashAfter)
        #expect(lastEntry.governanceTrace != nil)
        #expect(lastEntry.governanceTrace?.composedDecision == .deny)
    }

    // MARK: - Escalate = Denied

    @Test("Escalate is treated as denied, governanceDenied in audit")
    func escalateTreatedAsDenied() async {
        let clock = MockClock(fixed: Date(timeIntervalSince1970: 0))
        let uuids = MockUUIDGenerator(sequential: 1)

        let escalateLaw = AnyLaw<TestState, TestAction>(lawID: "EscalateLaw") { _, _ in
            LawVerdict(lawID: "EscalateLaw", decision: .escalate, reason: "Needs approval")
        }

        let policy = GovernancePolicy(
            laws: [escalateLaw],
            compositionRule: .denyWins,
            jurisdictionID: "TestDomain"
        )

        let base = BaseOrchestrator(
            initialState: TestState(),
            reducer: TestAction.TestReducer(),
            clock: clock,
            uuidGenerator: uuids,
            governancePolicy: policy
        )

        let result = await base.submit(.increment, agentID: "agent-1")
        #expect(result.applied == false)

        let state = await base.currentState
        #expect(state.counter == 0)

        let log = await base.auditLog()
        let lastEntry = log.last!
        if case .governanceDenied = lastEntry.eventType {
            // correct
        } else {
            Issue.record("Escalate should produce governanceDenied event")
        }
        #expect(lastEntry.governanceTrace?.composedDecision == .escalate)
    }

    // MARK: - Multiple Laws with DenyWins

    @Test("Multiple laws with denyWins: one deny overrides allows")
    func multipleLawsDenyWins() async {
        let clock = MockClock(fixed: Date(timeIntervalSince1970: 0))
        let uuids = MockUUIDGenerator(sequential: 1)

        let allowLaw = AnyLaw<TestState, TestAction>(lawID: "AllowLaw") { _, _ in
            LawVerdict(lawID: "AllowLaw", decision: .allow, reason: "OK")
        }
        let denyLaw = AnyLaw<TestState, TestAction>(lawID: "DenyLaw") { _, _ in
            LawVerdict(lawID: "DenyLaw", decision: .deny, reason: "Blocked")
        }

        let policy = GovernancePolicy(
            laws: [allowLaw, denyLaw],
            compositionRule: .denyWins,
            jurisdictionID: "TestDomain"
        )

        let base = BaseOrchestrator(
            initialState: TestState(),
            reducer: TestAction.TestReducer(),
            clock: clock,
            uuidGenerator: uuids,
            governancePolicy: policy
        )

        let result = await base.submit(.increment, agentID: "agent-1")
        #expect(result.applied == false)

        let log = await base.auditLog()
        let denied = log.governanceDeniedActions()
        #expect(denied.count == 1)
        #expect(denied[0].trace.verdicts.count == 2)
    }

    // MARK: - Governance Allows + Reducer Rejects

    @Test("Governance allows + reducer rejects: both recorded correctly")
    func governanceAllowsReducerRejects() async {
        let clock = MockClock(fixed: Date(timeIntervalSince1970: 0))
        let uuids = MockUUIDGenerator(sequential: 1)

        let allowLaw = AnyLaw<TestState, TestAction>(lawID: "AllowLaw") { _, _ in
            LawVerdict(lawID: "AllowLaw", decision: .allow, reason: "OK")
        }

        let policy = GovernancePolicy(
            laws: [allowLaw],
            compositionRule: .denyWins,
            jurisdictionID: "TestDomain"
        )

        let base = BaseOrchestrator(
            initialState: TestState(counter: 0),
            reducer: TestAction.TestReducer(),
            clock: clock,
            uuidGenerator: uuids,
            governancePolicy: policy
        )

        // Decrement at zero — governance allows but reducer rejects
        let result = await base.submit(.decrement, agentID: "agent-1")
        #expect(result.applied == false)

        let log = await base.auditLog()
        let lastEntry = log.last!

        // Event type should be actionProposed (not governanceDenied), since governance allowed
        if case .actionProposed(_, let agentID) = lastEntry.eventType {
            #expect(agentID == "agent-1")
        } else {
            Issue.record("Expected actionProposed event type for governance-allowed reducer-rejected action")
        }

        #expect(lastEntry.applied == false)
        #expect(lastEntry.governanceTrace != nil)
        #expect(lastEntry.governanceTrace?.composedDecision == .allow)
    }

    // MARK: - Governance Allows + Reducer Accepts

    @Test("Governance allows + reducer accepts: trace attached to accepted event")
    func governanceAllowsReducerAccepts() async {
        let clock = MockClock(fixed: Date(timeIntervalSince1970: 0))
        let uuids = MockUUIDGenerator(sequential: 1)

        let allowLaw = AnyLaw<TestState, TestAction>(lawID: "AllowLaw") { _, _ in
            LawVerdict(lawID: "AllowLaw", decision: .allow, reason: "OK")
        }

        let policy = GovernancePolicy(
            laws: [allowLaw],
            compositionRule: .denyWins,
            jurisdictionID: "TestDomain"
        )

        let base = BaseOrchestrator(
            initialState: TestState(),
            reducer: TestAction.TestReducer(),
            clock: clock,
            uuidGenerator: uuids,
            governancePolicy: policy
        )

        let result = await base.submit(.increment, agentID: "agent-1")
        #expect(result.applied == true)

        let log = await base.auditLog()
        let lastEntry = log.last!
        #expect(lastEntry.applied == true)
        #expect(lastEntry.governanceTrace != nil)
        #expect(lastEntry.governanceTrace?.composedDecision == .allow)
    }

    // MARK: - Hash Chain Integrity

    @Test("Hash chain integrity after governance events")
    func hashChainIntegrityWithGovernance() async {
        let clock = MockClock(fixed: Date(timeIntervalSince1970: 0))
        let uuids = MockUUIDGenerator(sequential: 1)

        let conditionalLaw = AnyLaw<TestState, TestAction>(lawID: "ConditionalLaw") { state, action in
            if case .setLabel(let label) = action, label == "forbidden" {
                return LawVerdict(lawID: "ConditionalLaw", decision: .deny, reason: "Forbidden label")
            }
            return LawVerdict(lawID: "ConditionalLaw", decision: .allow, reason: "OK")
        }

        let policy = GovernancePolicy(
            laws: [conditionalLaw],
            compositionRule: .denyWins,
            jurisdictionID: "TestDomain"
        )

        let base = BaseOrchestrator(
            initialState: TestState(),
            reducer: TestAction.TestReducer(),
            clock: clock,
            uuidGenerator: uuids,
            governancePolicy: policy
        )

        // Mix of allowed and denied actions
        _ = await base.submit(.increment, agentID: "agent")
        _ = await base.submit(.setLabel("forbidden"), agentID: "agent")
        _ = await base.submit(.increment, agentID: "agent")
        _ = await base.submit(.setLabel("ok"), agentID: "agent")

        let log = await base.auditLog()
        #expect(log.count == 5) // 1 init + 4 actions
        #expect(log.verify().isValid, "Hash chain must verify with governance events mixed in")
    }

    // MARK: - Replay Verification

    @Test("Replay verification works with governance events")
    func replayVerificationWithGovernance() async {
        let clock = MockClock(fixed: Date(timeIntervalSince1970: 0))
        let uuids = MockUUIDGenerator(sequential: 1)

        let conditionalLaw = AnyLaw<TestState, TestAction>(lawID: "ConditionalLaw") { _, action in
            if case .setLabel(let label) = action, label == "blocked" {
                return LawVerdict(lawID: "ConditionalLaw", decision: .deny, reason: "Blocked label")
            }
            return LawVerdict(lawID: "ConditionalLaw", decision: .allow, reason: "OK")
        }

        let policy = GovernancePolicy(
            laws: [conditionalLaw],
            compositionRule: .denyWins,
            jurisdictionID: "TestDomain"
        )

        let initialState = TestState()
        let base = BaseOrchestrator(
            initialState: initialState,
            reducer: TestAction.TestReducer(),
            clock: clock,
            uuidGenerator: uuids,
            governancePolicy: policy
        )

        _ = await base.submit(.increment, agentID: "agent")
        _ = await base.submit(.setLabel("blocked"), agentID: "agent")
        _ = await base.submit(.increment, agentID: "agent")

        let log = await base.auditLog()
        let result = log.verifyReplay(initialState: initialState, reducer: TestAction.TestReducer())
        #expect(result.isValid, "Replay verification should pass with governance events")
    }

    // MARK: - Determinism

    @Test("Same state + action + laws produce same trace")
    func governanceDeterminism() async {
        let law = AnyLaw<TestState, TestAction>(lawID: "TestLaw") { state, _ in
            if state.counter > 5 {
                return LawVerdict(lawID: "TestLaw", decision: .deny, reason: "Too high")
            }
            return LawVerdict(lawID: "TestLaw", decision: .allow, reason: "OK")
        }

        let policy = GovernancePolicy(
            laws: [law],
            compositionRule: .denyWins,
            jurisdictionID: "TestDomain"
        )

        let state = TestState(counter: 10)
        let trace1 = policy.evaluate(state: state, action: .increment)
        let trace2 = policy.evaluate(state: state, action: .increment)

        #expect(trace1 == trace2, "Same inputs must produce same governance trace")
    }
}
