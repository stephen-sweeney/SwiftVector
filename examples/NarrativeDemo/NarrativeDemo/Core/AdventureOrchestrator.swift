//
//  AdventureOrchestrator.swift
//  NarrativeDemo
//
//  Created by Stephen Sweeney on 1/3/26.
//

import Foundation

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
    private var state = AdventureState()
    private let agent = StoryAgent()
    private let agentID = "StoryAgent-\(UUID())"
    
    private let stream: AsyncStream<AdventureState>
    private let continuation: AsyncStream<AdventureState>.Continuation
    
    /// Audit log for deterministic replay and compliance.
    /// Satisfies SwiftVector whitepaper section 4.4:
    /// "Every change is attributable to a specific agent, model, and prompt version."
    private var auditLog: [AuditEntry] = []
    
    init() {
        (stream, continuation) = AsyncStream.makeStream()
        
        // Log initialization
        let initEntry = AuditEntry(
            timestamp: Date(),
            eventType: .initialization,
            stateHashBefore: "",
            stateHashAfter: state.hash(),
            applied: true,
            resultDescription: "System initialized"
        )
        auditLog.append(initEntry)
        
        continuation.yield(state) // Initial state
    }
    
    func stateStream() -> AsyncStream<AdventureState> {
        stream
    }
    
    func advanceStory() async {
        let hashBefore = state.hash()
        let proposed = await agent.propose(about: state)
        let result = StoryReducer.reduce(state: state, proposed: proposed)
        
        state = result.newState
        let hashAfter = state.hash()
        
        // Record audit entry
        let entry = AuditEntry(
            timestamp: Date(),
            eventType: .actionProposed(proposed, agentID: agentID),
            stateHashBefore: hashBefore,
            stateHashAfter: hashAfter,
            applied: result.applied,
            resultDescription: result.description
        )
        auditLog.append(entry)
        
        continuation.yield(state)
    }
    
    /// Replays a specific action without agent involvement.
    /// Used for deterministic replay from audit log.
    func replayAction(_ action: StoryAction) async {
        let hashBefore = state.hash()
        let result = StoryReducer.reduce(state: state, proposed: action)
        
        state = result.newState
        let hashAfter = state.hash()
        
        // Record replay entry (using special replay ID)
        let entry = AuditEntry(
            timestamp: Date(),
            eventType: .actionProposed(action, agentID: "REPLAY"),
            stateHashBefore: hashBefore,
            stateHashAfter: hashAfter,
            applied: result.applied,
            resultDescription: result.description
        )
        auditLog.append(entry)
        
        continuation.yield(state)
    }
    
    // MARK: - Audit Trail Access
    
    func getAuditLog() -> [AuditEntry] {
        auditLog
    }
    
    func getCurrentState() -> AdventureState {
        state
    }
    
    deinit {
        continuation.finish()
    }
}
