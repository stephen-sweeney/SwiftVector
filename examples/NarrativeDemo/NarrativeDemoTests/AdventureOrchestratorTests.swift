//
//  AdventureOrchestratorTests.swift
//  NarrativeDemoTests
//
//  Created by Stephen Sweeney on 1/6/26.
//

import Testing
import Foundation
@testable import NarrativeDemo

// MARK: - Audit Trail Tests

@Suite("Adventure Orchestrator Audit Trail")
struct AdventureOrchestratorTests {
    
    @Test("Audit log captures initial state")
    func auditLogCapturesInitialState() async throws {
        let orchestrator = AdventureOrchestrator()
        
        let log = await orchestrator.getAuditLog()
        
        #expect(log.count == 1, "Should have initial state entry")
        #expect(log[0].eventType == .initialization, "First entry should be initialization")
        #expect(log[0].applied == true, "Initialization should be marked as applied")
        #expect(!log[0].stateHashAfter.isEmpty, "Should have initial state hash")
    }
    
    @Test("Audit log records proposed action")
    @MainActor
    func auditLogRecordsProposedAction() async throws {
        let orchestrator = AdventureOrchestrator()
        
        await orchestrator.advanceStory()
        
        let log = await orchestrator.getAuditLog()
        
        #expect(log.count == 2, "Should have initialization and one action entry")
        
        let actionEntry = log[1]
        if case .actionProposed(_, let agentID) = actionEntry.eventType {
            #expect(agentID.hasPrefix("StoryAgent-"), "Agent ID should identify the agent")
        } else {
            Issue.record("Second entry should be an action proposal")
        }
        
        #expect(actionEntry.timestamp <= Date(), "Timestamp should be in the past")
        #expect(!actionEntry.resultDescription.isEmpty, "Should have result description")
    }
    
    @Test("Audit log distinguishes accepted vs rejected actions")
    @MainActor
    func auditLogDistinguishesAcceptedVsRejected() async throws {
        let orchestrator = AdventureOrchestrator()
        
        // Use replayAction with known actions to control outcomes
        // Gold amount 500 exceeds limit (100) and will be rejected
        await orchestrator.replayAction(.findGold(amount: 50))   // Should be accepted
        await orchestrator.replayAction(.findGold(amount: 500))  // Should be rejected
        
        let log = await orchestrator.getAuditLog()
        
        // Filter to just the replay actions
        let replayEntries = log.filter { 
            if case .actionProposed(_, let agentID) = $0.eventType {
                return agentID == "REPLAY"
            }
            return false
        }
        
        #expect(replayEntries.count == 2, "Should have two replay entries")
        #expect(replayEntries[0].applied == true, "First action (50 gold) should be accepted")
        #expect(replayEntries[1].applied == false, "Second action (500 gold) should be rejected")
        #expect(replayEntries[1].resultDescription.contains("Rejected"), "Rejection should be described")
    }
    
    @Test("Audit log captures state hash for replay")
    func auditLogCapturesStateHash() async throws {
        let orchestrator = AdventureOrchestrator()
        
        await orchestrator.advanceStory()
        
        let log = await orchestrator.getAuditLog()
        let entry = log.last!
        
        #expect(!entry.stateHashBefore.isEmpty, "Should have before hash")
        #expect(!entry.stateHashAfter.isEmpty, "Should have after hash")
        #expect(entry.stateHashBefore.count == 64, "SHA256 hash should be 64 hex characters")
        #expect(entry.stateHashAfter.count == 64, "SHA256 hash should be 64 hex characters")
    }
    
    @Test("State hash changes when state changes")
    func stateHashChangesWithState() async throws {
        let orchestrator = AdventureOrchestrator()
        
        // Use a known action that will be accepted and change state
        await orchestrator.replayAction(.findGold(amount: 50))
        
        let log = await orchestrator.getAuditLog()
        let entry = log.last!
        
        #expect(entry.applied == true, "Action should be accepted")
        #expect(entry.stateHashBefore != entry.stateHashAfter, 
                "Hash should change when state changes")
    }
    
    @Test("State hash changes even when action rejected due to event log")
    func stateHashChangesEvenWhenRejected() async throws {
        let orchestrator = AdventureOrchestrator()
        
        await orchestrator.replayAction(.findGold(amount: 500))
        
        let log = await orchestrator.getAuditLog()
        let entry = log.last!
        
        #expect(entry.applied == false, "Action should be rejected")
        #expect(entry.stateHashBefore != entry.stateHashAfter,
                "Hash changes because eventLog records the rejection")
    }
    
    @Test("Audit log enables deterministic replay")
    func auditLogEnablesDeterministicReplay() async throws {
        let orchestrator = AdventureOrchestrator()
        
        // Use known actions for deterministic test
        let actions: [StoryAction] = [
            .findGold(amount: 20),
            .moveTo(location: "dark cave"),
            .findItem("rusty sword"),
            .takeDamage(amount: 15),
            .findGold(amount: 500),  // Will be rejected
            .rest(healing: 25),       // Will be rejected (dangerous location)
            .moveTo(location: "sunlit meadow"),
            .rest(healing: 25)        // Will be accepted now
        ]
        
        // Execute original sequence
        for action in actions {
            await orchestrator.replayAction(action)
        }
        
        let originalLog = await orchestrator.getAuditLog()
        let originalFinalHash = await originalLog.last!.stateHashAfter
        let originalState = await orchestrator.getCurrentState()
        
        // Create new orchestrator and replay the same actions
        let replayOrchestrator = AdventureOrchestrator()
        
        for action in actions {
            await replayOrchestrator.replayAction(action)
        }
        
        let replayLog = await replayOrchestrator.getAuditLog()
        let replayFinalHash = await replayLog.last!.stateHashAfter
        let replayState = await replayOrchestrator.getCurrentState()
        
        // Verify byte-identical replay
        #expect(originalFinalHash == replayFinalHash, 
                "Replaying same actions should produce identical state hash")
        
        // Verify actual state equality
        #expect(originalState.location == replayState.location, "Locations should match")
        #expect(originalState.health == replayState.health, "Health should match")
        #expect(originalState.gold == replayState.gold, "Gold should match")
        #expect(originalState.inventory == replayState.inventory, "Inventory should match")
    }
    
    @Test("Audit entries are immutable and Sendable")
    func auditEntriesAreImmutableAndSendable() async throws {
        let orchestrator = AdventureOrchestrator()
        
        await orchestrator.advanceStory()
        
        let log = await orchestrator.getAuditLog()
        let entry = log.first!
        
        // Verify Sendable by passing across actor boundary
        let capturedEntry = await Task.detached {
            // This compiles only if AuditEntry is Sendable
            return entry
        }.value
        
        #expect(capturedEntry.id == entry.id, "Entry should be safely passable across actors")
    }
    
    @Test("Hash includes full event log content")
    func hashIncludesFullEventLogContent() async throws {
        let orchestrator1 = AdventureOrchestrator()
        let orchestrator2 = AdventureOrchestrator()
        
        // Same gold action on both
        await orchestrator1.replayAction(.findGold(amount: 20))
        await orchestrator2.replayAction(.findGold(amount: 20))
        
        let state1 = await orchestrator1.getCurrentState()
        let state2 = await orchestrator2.getCurrentState()
        
        // States should be equal and hashes should match
        #expect(state1.hash() == state2.hash(), 
                "Identical states should produce identical hashes")
        
        // Now add different actions to diverge event logs
        await orchestrator1.replayAction(.moveTo(location: "dark cave"))
        await orchestrator2.replayAction(.moveTo(location: "sunlit meadow"))
        
        let divergedState1 = await orchestrator1.getCurrentState()
        let divergedState2 = await orchestrator2.getCurrentState()
        
        // Event logs are different, so hashes should differ
        #expect(divergedState1.hash() != divergedState2.hash(), 
                "Different event logs should produce different hashes")
    }
}
