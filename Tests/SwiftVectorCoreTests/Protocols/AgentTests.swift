//
//  AgentTests.swift
//  SwiftVectorCoreTests
//
//  Copyright © 2026 Flightworks Aerial LLC. All rights reserved.
//

import Testing
import Foundation
@testable import SwiftVectorCore

// MARK: - Agent Protocol Tests

@Suite("Agent Protocol")
struct AgentProtocolTests {

    // MARK: - Inline Mock (no SwiftVectorTesting dependency)

    /// A deterministic agent that returns actions from a predefined script.
    /// Used to prove agent determinism without external dependencies.
    private final class ScriptedMockAgent: Agent, @unchecked Sendable {
        private var script: [TestAction]
        private var index = 0
        private let lock = NSLock()

        init(script: [TestAction]) {
            self.script = script
        }

        func propose(about state: TestState) async -> TestAction {
            lock.withLock {
                let action = script[index]
                index += 1
                return action
            }
        }

        func reset() {
            lock.withLock { index = 0 }
        }
    }

    // MARK: - Tests

    @Test("Scripted agent proposes actions in order")
    func scriptedAgentProposesInOrder() async {
        let script: [TestAction] = [.increment, .decrement, .setLabel("test")]
        let agent = ScriptedMockAgent(script: script)
        let state = TestState()

        let action1 = await agent.propose(about: state)
        let action2 = await agent.propose(about: state)
        let action3 = await agent.propose(about: state)

        #expect(action1 == .increment)
        #expect(action2 == .decrement)
        #expect(action3 == .setLabel("test"))
    }

    @Test("Scripted agent is deterministic across reset")
    func scriptedAgentDeterministicAcrossReset() async {
        let script: [TestAction] = [.increment, .setLabel("a"), .decrement]
        let agent = ScriptedMockAgent(script: script)
        let state = TestState()

        // First run
        var firstRun: [TestAction] = []
        for _ in 0..<3 {
            firstRun.append(await agent.propose(about: state))
        }

        agent.reset()

        // Second run after reset
        var secondRun: [TestAction] = []
        for _ in 0..<3 {
            secondRun.append(await agent.propose(about: state))
        }

        #expect(firstRun == secondRun, "Same script must produce identical actions after reset")
        #expect(firstRun == [.increment, .setLabel("a"), .decrement])
    }
}
