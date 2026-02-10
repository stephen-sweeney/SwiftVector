//
//  BaseOrchestratorTests.swift
//  SwiftVectorCoreTests
//
//  Created by Stephen Sweeney
//  Copyright © 2026 Flightworks Aerial LLC. All rights reserved.
//

import Foundation
import Testing
import SwiftVectorTesting
@testable import SwiftVectorCore

@Suite("BaseOrchestrator")
struct BaseOrchestratorTests {

    private func makeBase(
        initialState: TestState = TestState(),
        clock: MockClock = MockClock(fixed: Date(timeIntervalSince1970: 0)),
        uuidGenerator: MockUUIDGenerator = MockUUIDGenerator(sequential: 1)
    ) -> BaseOrchestrator<TestState, TestAction, TestAction.TestReducer> {
        BaseOrchestrator(
            initialState: initialState,
            reducer: TestAction.TestReducer(),
            clock: clock,
            uuidGenerator: uuidGenerator
        )
    }

    @Test("Initialization records audit entry and yields initial state")
    func initializationRecordsAuditEntryAndYieldsInitialState() async throws {
        let clock = MockClock(fixed: Date(timeIntervalSince1970: 0))
        let base = makeBase(clock: clock)

        let log = await base.auditLog()
        #expect(log.count == 1, "Should have initialization entry")
        #expect(log[0].eventType == .initialization, "First entry should be initialization")
        #expect(log[0].timestamp == clock.now(), "Timestamp should be deterministic")
        #expect(log[0].previousEntryHash.isEmpty, "Initialization should have empty previous hash")

        let stream = base.stateStream()
        var iterator = stream.makeAsyncIterator()
        let first = await iterator.next()
        #expect(first == TestState(), "Stream should yield initial state immediately")
    }

    @Test("Submit applies reducer, updates state, emits stream, and appends audit entry")
    func submitAppliesReducerUpdatesStateEmitsStreamAndAppendsAuditEntry() async throws {
        let base = makeBase()

        let stream = base.stateStream()
        var iterator = stream.makeAsyncIterator()
        _ = await iterator.next()

        let result = await base.submit(.increment, agentID: "agent-1")
        #expect(result.applied == true, "Increment should be accepted")

        let next = await iterator.next()
        #expect(next?.counter == 1, "State should update after submit")

        let log = await base.auditLog()
        #expect(log.count == 2, "Should have initialization + action entry")
        if case .actionProposed(_, let agentID) = log[1].eventType {
            #expect(agentID == "agent-1", "Agent ID should be recorded")
        } else {
            Issue.record("Second entry should be actionProposed")
        }
    }

    @Test("Rejected actions leave state unchanged and hash unchanged")
    func rejectedActionsLeaveStateUnchangedAndHashUnchanged() async throws {
        let base = makeBase()

        let stream = base.stateStream()
        var iterator = stream.makeAsyncIterator()
        let first = await iterator.next()

        let result = await base.submit(.decrement, agentID: "agent-1")
        #expect(result.applied == false, "Decrement at zero should be rejected")

        let next = await iterator.next()
        #expect(next == first, "State should be unchanged after rejection")

        let log = await base.auditLog()
        let entry = log.last!
        #expect(entry.applied == false, "Audit entry should be rejected")
        #expect(entry.stateHashBefore == entry.stateHashAfter, "Hashes should match on rejection")
    }

    @Test("Replay uses caller-provided agent ID")
    func replayUsesCallerProvidedAgentID() async throws {
        let base = makeBase()

        _ = await base.replay(.increment, agentID: "REPLAY")

        let log = await base.auditLog()
        if case .actionProposed(_, let agentID) = log.last?.eventType {
            #expect(agentID == "REPLAY", "Replay should record provided agent ID")
        } else {
            Issue.record("Replay should record an actionProposed entry")
        }
    }

    @Test("Replay actions maintain hash chain integrity")
    func replayActionsMaintainHashChainIntegrity() async throws {
        let base = makeBase()

        _ = await base.replay(.increment, agentID: "REPLAY")
        _ = await base.replay(.setLabel("replayed"), agentID: "REPLAY")

        let log = await base.auditLog()
        let result = log.verify()
        #expect(result.isValid, "Hash chain should verify after replay")
    }

    @Test("Audit log verifies hash chain after multiple actions")
    func auditLogVerifiesHashChainAfterMultipleActions() async throws {
        let base = makeBase()

        _ = await base.submit(.increment, agentID: "agent-1")
        _ = await base.submit(.setLabel("updated"), agentID: "agent-1")
        _ = await base.submit(.decrement, agentID: "agent-1")

        let log = await base.auditLog()
        let result = log.verify()
        #expect(result.isValid, "Audit log should verify hash chain integrity")
    }

    @Test("Audit log verifies replay against reducer")
    func auditLogVerifiesReplayAgainstReducer() async throws {
        let initialState = TestState()
        let base = makeBase(initialState: initialState)

        _ = await base.submit(.increment, agentID: "agent-1")
        _ = await base.submit(.setLabel("updated"), agentID: "agent-1")

        let log = await base.auditLog()
        let result = log.verifyReplay(initialState: initialState, reducer: TestAction.TestReducer())
        #expect(result.isValid, "Replay verification should pass")
    }
}
