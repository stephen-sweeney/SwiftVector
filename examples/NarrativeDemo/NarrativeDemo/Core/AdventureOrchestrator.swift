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

actor AdventureOrchestrator {
    private var state: AdventureState
    private let agent = StoryAgent()
    private let agentID = "StoryAgent-\(UUID())"
    private let reducer: StoryReducer
    private let clock: any Clock
    private let uuidGenerator: any UUIDGenerator
    
    private let stream: AsyncStream<AdventureState>
    private let continuation: AsyncStream<AdventureState>.Continuation
    
    /// Audit log for deterministic replay and compliance.
    /// Satisfies SwiftVector whitepaper section 4.4:
    /// "Every change is attributable to a specific agent, model, and prompt version."
    private var auditLog: EventLog<StoryAction>
    
    init(
        initialState: AdventureState = AdventureState(),
        reducer: StoryReducer = StoryReducer(),
        clock: any Clock = SystemClock(),
        uuidGenerator: any UUIDGenerator = SystemUUIDGenerator()
    ) {
        (stream, continuation) = AsyncStream.makeStream()
        self.state = initialState
        self.reducer = reducer
        self.clock = clock
        self.uuidGenerator = uuidGenerator
        self.auditLog = EventLog()
        
        // Log initialization
        auditLog.append(.initialization(
            id: uuidGenerator.next(),
            timestamp: clock.now(),
            initialStateHash: state.stateHash()
        ))
        
        continuation.yield(state) // Initial state
    }
    
    func stateStream() -> AsyncStream<AdventureState> {
        stream
    }
    
    func advanceStory() async {
        let hashBefore = state.stateHash()
        let proposed = await agent.propose(about: state)
        let result = reducer.reduce(state: state, action: proposed)
        
        state = result.newState
        let hashAfter = state.stateHash()
        
        // Record audit entry
        if result.applied {
            auditLog.append(.accepted(
                id: uuidGenerator.next(),
                timestamp: clock.now(),
                action: proposed,
                agentID: agentID,
                stateHashBefore: hashBefore,
                stateHashAfter: hashAfter,
                rationale: result.rationale,
                previousEntryHash: ""
            ))
        } else {
            auditLog.append(
                .rejected(
                    id: uuidGenerator.next(),
                    timestamp: clock.now(),
                    action: proposed,
                    agentID: agentID,
                    stateHash: hashBefore,
                    rationale: result.rationale,
                    previousEntryHash: ""
                )
            )
        }
        
        continuation.yield(state)
    }
    
    /// Replays a specific action without agent involvement.
    /// Used for deterministic replay from audit log.
    func replayAction(_ action: StoryAction) async {
        let hashBefore = state.stateHash()
        let result = reducer.reduce(state: state, action: action)
        
        state = result.newState
        let hashAfter = state.stateHash()
        
        // Record replay entry (using special replay ID)
        if result.applied {
            auditLog.append(.accepted(
                id: uuidGenerator.next(),
                timestamp: clock.now(),
                action: action,
                agentID: "REPLAY",
                stateHashBefore: hashBefore,
                stateHashAfter: hashAfter,
                rationale: result.rationale,
                previousEntryHash: ""
            ))
        } else {
            auditLog.append(.rejected(
                id: uuidGenerator.next(),
                timestamp: clock.now(),
                action: action,
                agentID: "REPLAY",
                stateHash: hashBefore,
                rationale: result.rationale,
                previousEntryHash: ""
            ))
        }
        
        continuation.yield(state)
    }
    
    // MARK: - Audit Trail Access
    
    func getAuditLog() -> EventLog<StoryAction> {
        auditLog
    }

    /// Returns narrative entries derived from the audit log for UI display.
    func getNarrativeLog() -> [String] {
        var narrative: [String] = ["🌲 You awaken in an ancient forest, birds singing overhead."]
        
        for entry in auditLog {
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
    
    func getCurrentState() -> AdventureState {
        state
    }
    
    deinit {
        continuation.finish()
    }
}
