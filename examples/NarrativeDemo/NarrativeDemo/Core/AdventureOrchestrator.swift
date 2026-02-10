//
//  AdventureOrchestrator.swift
//  NarrativeDemo
//
//  Created by Stephen Sweeney on 1/3/26.
//

import Foundation
import SwiftVectorCore

// MARK: - Orchestrator (AsyncStream for safe broadcasting)
/// The Orchestrator implements the SwiftVector control loop:
/// 1. Agent observes immutable state snapshot
/// 2. Agent proposes action (stochastic—may hallucinate)
/// 3. Reducer validates and applies (deterministic—enforces rules)
/// 4. New state is broadcast via AsyncStream
///
/// This ensures:
/// - State is the single source of truth
/// - LLM hallucinations cannot corrupt state
/// - All changes are auditable
/// - System behavior is replayable from action log

actor AdventureOrchestrator: Orchestrator {
    typealias State = AdventureState
    typealias Action = StoryAction
    typealias ReducerType = StoryReducer

    private let base: BaseOrchestrator<State, Action, ReducerType>
    private let agent: StoryAgent
    private let agentID: String

    init(
        initialState: AdventureState = AdventureState(),
        reducer: StoryReducer = StoryReducer(),
        clock: any Clock = SystemClock(),
        uuidGenerator: any UUIDGenerator = SystemUUIDGenerator()
    ) {
        self.base = BaseOrchestrator(
            initialState: initialState,
            reducer: reducer,
            clock: clock,
            uuidGenerator: uuidGenerator
        )
        self.agent = StoryAgent()
        self.agentID = "StoryAgent-\(uuidGenerator.next())"
    }

    func stateStream() -> AsyncStream<AdventureState> {
        base.stateStream()
    }

    /// Executes one iteration of the control loop (protocol conformance).
    func advance() async {
        let action = await agent.propose(about: await base.currentState)
        _ = await base.submit(action, agentID: agentID)
    }

    /// Deprecated: Use `advance()` instead.
    @available(*, deprecated, renamed: "advance()")
    func advanceStory() async {
        await advance()
    }

    /// Replays a specific action without agent involvement (protocol conformance).
    func replay(_ action: StoryAction, agentID: String) async {
        _ = await base.replay(action, agentID: agentID)
    }

    /// Deprecated: Use `replay(_:)` instead.
    @available(*, deprecated, renamed: "replay(_:)")
    func replayAction(_ action: StoryAction) async {
        await replay(action, agentID: "REPLAY")
    }

    // MARK: - Audit Trail Access

    /// Returns the complete audit log as a snapshot (protocol conformance).
    func auditLog() async -> EventLog<StoryAction> {
        await base.auditLog()
    }

    /// Deprecated: Use `auditLog()` instead.
    @available(*, deprecated, renamed: "auditLog()")
    func getAuditLog() -> EventLog<StoryAction> async {
        await auditLog()
    }

    /// Returns narrative entries derived from the audit log for UI display.
    func getNarrativeLog() async -> [String] {
        let log = await base.auditLog()
        var narrative: [String] = ["🌲 You awaken in an ancient forest, birds singing overhead."]

        for entry in log {
            switch entry.eventType {
            case .initialization:
                continue
            case .actionProposed(let action, _):
                let icon = entry.applied ? "✅" : "❌"
                narrative.append("🤖 Agent proposed: \(action.actionDescription)")
                narrative.append("\(icon) \(entry.rationale)")
            case .stateRestored(let source):
                narrative.append("🔄 State restored from \(source)")
            case .systemEvent(let description):
                narrative.append("⚙️ \(description)")
            }
        }

        return narrative
    }

    /// The current state snapshot (protocol conformance).
    var currentState: AdventureState {
        get async {
            await base.currentState
        }
    }

    /// Deprecated: Use `currentState` instead.
    @available(*, deprecated, renamed: "currentState")
    func getCurrentState() async -> AdventureState {
        await currentState
    }
}
