//
//  AuditTests.swift
//  SwiftVectorCoreTests
//
//  Created by Stephen Sweeney
//  Copyright © 2026 Flightworks Aerial LLC. All rights reserved.
//

import Testing
import Foundation
import CryptoKit
@testable import SwiftVectorCore
@testable import SwiftVectorTesting

// MARK: - Test Fixtures

/// Minimal State for audit testing
struct AuditTestState: State {
    var value: Int = 0
}

/// Minimal Action for audit testing
enum AuditTestAction: Action, Codable {
    case increment
    case decrement
    case setValue(Int)
    
    var actionDescription: String {
        switch self {
        case .increment: return "Increment"
        case .decrement: return "Decrement"
        case .setValue(let v): return "Set value to \(v)"
        }
    }
    
    var correlationID: UUID {
        switch self {
        case .increment:
            return UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        case .decrement:
            return UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        case .setValue(let v):
            return stableUUID(for: "setValue-\(v)")
        }
    }
    
    private func stableUUID(for string: String) -> UUID {
        let digest = SHA256.hash(data: Data(string.utf8))
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        let uuidString =
            "\(hex.prefix(8))-\(hex.dropFirst(8).prefix(4))-\(hex.dropFirst(12).prefix(4))-" +
            "\(hex.dropFirst(16).prefix(4))-\(hex.dropFirst(20).prefix(12))"
        return UUID(uuidString: String(uuidString))!
    }
}

/// Reducer for audit testing
struct AuditTestReducer: Reducer {
    func reduce(state: AuditTestState, action: AuditTestAction) -> ReducerResult<AuditTestState> {
        var newState = state
        
        switch action {
        case .increment:
            newState.value += 1
            return .accepted(newState, rationale: "Incremented to \(newState.value)")
            
        case .decrement:
            guard state.value > 0 else {
                return .rejected(state, rationale: "Cannot decrement below zero")
            }
            newState.value -= 1
            return .accepted(newState, rationale: "Decremented to \(newState.value)")
            
        case .setValue(let v):
            guard v >= 0 else {
                return .rejected(state, rationale: "Value must be non-negative")
            }
            newState.value = v
            return .accepted(newState, rationale: "Set value to \(v)")
        }
    }
}

// MARK: - AuditEventType Tests

@Suite("AuditEventType")
struct AuditEventTypeTests {
    
    @Test("Event types are equatable")
    func eventTypesEquatable() {
        let init1: AuditEventType<AuditTestAction> = .initialization
        let init2: AuditEventType<AuditTestAction> = .initialization
        #expect(init1 == init2)
        
        let action1: AuditEventType<AuditTestAction> = .actionProposed(.increment, agentID: "agent-1")
        let action2: AuditEventType<AuditTestAction> = .actionProposed(.increment, agentID: "agent-1")
        let action3: AuditEventType<AuditTestAction> = .actionProposed(.increment, agentID: "agent-2")
        
        #expect(action1 == action2)
        #expect(action1 != action3)
    }
    
    @Test("Event types have descriptions")
    func eventTypeDescriptions() {
        let initEvent: AuditEventType<AuditTestAction> = .initialization
        #expect(initEvent.description == "initialization")
        
        let action: AuditEventType<AuditTestAction> = .actionProposed(.increment, agentID: "test-agent")
        #expect(action.description.contains("Increment"))
        #expect(action.description.contains("test-agent"))
        
        let restored: AuditEventType<AuditTestAction> = .stateRestored(source: "snapshot-123")
        #expect(restored.description.contains("snapshot-123"))
        
        let system: AuditEventType<AuditTestAction> = .systemEvent(description: "Shutdown")
        #expect(system.description.contains("Shutdown"))
    }
    
    @Test("Event types are codable")
    func eventTypesCodable() throws {
        let original: AuditEventType<AuditTestAction> = .actionProposed(.setValue(42), agentID: "encoder-test")
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(original)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(AuditEventType<AuditTestAction>.self, from: data)
        
        #expect(original == decoded)
    }
    
    @Test("All event type variants encode/decode correctly")
    func allEventTypesRoundTrip() throws {
        let variants: [AuditEventType<AuditTestAction>] = [
            .initialization,
            .actionProposed(.increment, agentID: "agent"),
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

// MARK: - AuditEvent Tests

@Suite("AuditEvent")
struct AuditEventTests {
    
    let fixedID = UUID(uuidString: "12345678-1234-1234-1234-123456789012")!
    let fixedDate = Date(timeIntervalSince1970: 1000)
    
    @Test("AuditEvent stores all properties")
    func auditEventProperties() {
        let event = AuditEvent<AuditTestAction>(
            id: fixedID,
            timestamp: fixedDate,
            eventType: .actionProposed(.increment, agentID: "test-agent"),
            stateHashBefore: "hash-before",
            stateHashAfter: "hash-after",
            applied: true,
            rationale: "Test rationale",
            previousEntryHash: "previous-hash"
        )
        
        #expect(event.id == fixedID)
        #expect(event.timestamp == fixedDate)
        #expect(event.stateHashBefore == "hash-before")
        #expect(event.stateHashAfter == "hash-after")
        #expect(event.applied == true)
        #expect(event.rationale == "Test rationale")
        #expect(event.previousEntryHash == "previous-hash")
    }
    
    @Test("AuditEvent computes entryHash")
    func auditEventEntryHash() {
        let event = AuditEvent<AuditTestAction>(
            id: fixedID,
            timestamp: fixedDate,
            eventType: .initialization,
            stateHashBefore: "",
            stateHashAfter: "initial-hash",
            applied: true,
            rationale: "System initialized",
            previousEntryHash: ""
        )
        
        let hash = event.entryHash
        
        // SHA256 produces 64 hex characters
        #expect(hash.count == 64)
        
        // All characters should be valid hex
        let hexCharacters = CharacterSet(charactersIn: "0123456789abcdef")
        let allHex = hash.unicodeScalars.allSatisfy { hexCharacters.contains($0) }
        #expect(allHex, "Hash should contain only lowercase hex characters")
    }
    
    @Test("AuditEvent entryHash is deterministic")
    func auditEventEntryHashDeterministic() {
        let event1 = AuditEvent<AuditTestAction>(
            id: fixedID,
            timestamp: fixedDate,
            eventType: .initialization,
            stateHashBefore: "",
            stateHashAfter: "hash",
            applied: true,
            rationale: "init",
            previousEntryHash: ""
        )
        
        let event2 = AuditEvent<AuditTestAction>(
            id: fixedID,
            timestamp: fixedDate,
            eventType: .initialization,
            stateHashBefore: "",
            stateHashAfter: "hash",
            applied: true,
            rationale: "init",
            previousEntryHash: ""
        )
        
        #expect(event1.entryHash == event2.entryHash, "Same content should produce same hash")
    }
    
    @Test("AuditEvent initialization factory")
    func initializationFactory() {
        let event = AuditEvent<AuditTestAction>.initialization(
            id: fixedID,
            timestamp: fixedDate,
            initialStateHash: "initial-hash"
        )
        
        #expect(event.eventType == .initialization)
        #expect(event.stateHashBefore == "")
        #expect(event.stateHashAfter == "initial-hash")
        #expect(event.applied == true)
        #expect(event.previousEntryHash == "")
    }
    
    @Test("AuditEvent accepted factory")
    func acceptedFactory() {
        let event = AuditEvent<AuditTestAction>.accepted(
            id: fixedID,
            timestamp: fixedDate,
            action: .increment,
            agentID: "agent-1",
            stateHashBefore: "before",
            stateHashAfter: "after",
            rationale: "Accepted",
            previousEntryHash: "prev-hash"
        )
        
        #expect(event.applied == true)
        #expect(event.stateHashBefore == "before")
        #expect(event.stateHashAfter == "after")
        #expect(event.previousEntryHash == "prev-hash")
        
        if case .actionProposed(let action, let agentID) = event.eventType {
            #expect(action == .increment)
            #expect(agentID == "agent-1")
        } else {
            Issue.record("Expected actionProposed event type")
        }
    }
    
    @Test("AuditEvent rejected factory")
    func rejectedFactory() {
        let event = AuditEvent<AuditTestAction>.rejected(
            id: fixedID,
            timestamp: fixedDate,
            action: .decrement,
            agentID: "agent-1",
            stateHash: "unchanged",
            rationale: "Cannot decrement",
            previousEntryHash: "prev-hash"
        )
        
        #expect(event.applied == false)
        #expect(event.stateHashBefore == "unchanged")
        #expect(event.stateHashAfter == "unchanged")  // Same for rejected
        #expect(event.previousEntryHash == "prev-hash")
    }
    
    @Test("AuditEvent systemEvent factory")
    func systemEventFactory() {
        let event = AuditEvent<AuditTestAction>.systemEvent(
            id: fixedID,
            timestamp: fixedDate,
            description: "Checkpoint",
            stateHash: "current-hash",
            previousEntryHash: "prev-hash"
        )
        
        #expect(event.applied == true)
        #expect(event.stateHashBefore == "current-hash")
        #expect(event.stateHashAfter == "current-hash")  // Unchanged
        #expect(event.rationale == "Checkpoint")
        
        if case .systemEvent(let desc) = event.eventType {
            #expect(desc == "Checkpoint")
        } else {
            Issue.record("Expected systemEvent event type")
        }
    }
    
    @Test("AuditEvent stateRestored factory")
    func stateRestoredFactory() {
        let event = AuditEvent<AuditTestAction>.stateRestored(
            id: fixedID,
            timestamp: fixedDate,
            source: "snapshot-123",
            stateHashBefore: "old-hash",
            stateHashAfter: "restored-hash",
            previousEntryHash: "prev-hash"
        )
        
        #expect(event.applied == true)
        #expect(event.stateHashBefore == "old-hash")
        #expect(event.stateHashAfter == "restored-hash")
        
        if case .stateRestored(let source) = event.eventType {
            #expect(source == "snapshot-123")
        } else {
            Issue.record("Expected stateRestored event type")
        }
    }
    
    @Test("AuditEvent is equatable")
    func auditEventEquatable() {
        let event1 = AuditEvent<AuditTestAction>.initialization(
            id: fixedID,
            timestamp: fixedDate,
            initialStateHash: "hash"
        )
        
        let event2 = AuditEvent<AuditTestAction>.initialization(
            id: fixedID,
            timestamp: fixedDate,
            initialStateHash: "hash"
        )
        
        let event3 = AuditEvent<AuditTestAction>.initialization(
            id: UUID(),  // Different ID
            timestamp: fixedDate,
            initialStateHash: "hash"
        )
        
        #expect(event1 == event2)
        #expect(event1 != event3)
    }
    
    @Test("AuditEvent is codable")
    func auditEventCodable() throws {
        let original = AuditEvent<AuditTestAction>.accepted(
            id: fixedID,
            timestamp: fixedDate,
            action: .setValue(99),
            agentID: "coder-agent",
            stateHashBefore: "before",
            stateHashAfter: "after",
            rationale: "Set value",
            previousEntryHash: "prev"
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(original)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(AuditEvent<AuditTestAction>.self, from: data)
        
        #expect(original == decoded)
    }
}

// MARK: - EventLog Tests

@Suite("EventLog")
struct EventLogTests {
    
    let clock = MockClock(fixed: Date(timeIntervalSince1970: 0))
    let uuids = MockUUIDGenerator(sequential: 1)
    
    @Test("EventLog starts empty")
    func eventLogStartsEmpty() {
        let log = EventLog<AuditTestAction>()
        
        #expect(log.isEmpty)
        #expect(log.count == 0)
        #expect(log.first == nil)
        #expect(log.last == nil)
        #expect(log.currentStateHash == nil)
        #expect(log.lastEntryHash == "")
    }
    
    @Test("EventLog appends events and sets chain link")
    func eventLogAppendsWithChainLink() {
        var log = EventLog<AuditTestAction>()
        
        let event = AuditEvent<AuditTestAction>.initialization(
            id: uuids.next(),
            timestamp: clock.now(),
            initialStateHash: "initial"
        )
        
        log.append(event)
        
        #expect(log.count == 1)
        #expect(log.first?.previousEntryHash == "", "First entry should have empty previousEntryHash")
        #expect(log.currentStateHash == "initial")
        #expect(log.lastEntryHash.count == 64, "Should have computed entry hash")
    }
    
    @Test("EventLog chains multiple entries")
    func eventLogChainsEntries() {
        var log = EventLog<AuditTestAction>()
        
        log.append(.initialization(
            id: uuids.next(),
            timestamp: clock.now(),
            initialStateHash: "h1"
        ))
        
        let firstEntryHash = log[0].entryHash
        
        log.append(.accepted(
            id: uuids.next(),
            timestamp: clock.now(),
            action: .increment,
            agentID: "agent",
            stateHashBefore: "h1",
            stateHashAfter: "h2",
            rationale: "OK",
            previousEntryHash: ""  // Will be set by append()
        ))
        
        #expect(log[1].previousEntryHash == firstEntryHash,
                "Second entry should reference first entry's hash")
    }
    
    @Test("EventLog validates chain on appendValidating")
    func eventLogValidatesChain() throws {
        var log = EventLog<AuditTestAction>()
        
        // First event
        let initEvent = AuditEvent<AuditTestAction>.initialization(
            id: uuids.next(),
            timestamp: clock.now(),
            initialStateHash: "hash-1"
        )
        try log.appendValidating(initEvent)
        
        // Valid continuation
        let valid = AuditEvent<AuditTestAction>.accepted(
            id: uuids.next(),
            timestamp: clock.now(),
            action: .increment,
            agentID: "agent",
            stateHashBefore: "hash-1",  // Matches previous
            stateHashAfter: "hash-2",
            rationale: "OK",
            previousEntryHash: ""
        )
        try log.appendValidating(valid)
        
        #expect(log.count == 2)
        
        // Invalid continuation
        let invalid = AuditEvent<AuditTestAction>.accepted(
            id: uuids.next(),
            timestamp: clock.now(),
            action: .increment,
            agentID: "agent",
            stateHashBefore: "wrong-hash",  // Doesn't match
            stateHashAfter: "hash-3",
            rationale: "Bad",
            previousEntryHash: ""
        )
        
        #expect(throws: EventLogError.self) {
            try log.appendValidating(invalid)
        }
    }
    
    @Test("EventLog verify detects valid chain")
    func eventLogVerifyValid() {
        var log = EventLog<AuditTestAction>()
        
        log.append(.initialization(id: uuids.next(), timestamp: clock.now(), initialStateHash: "h1"))
        log.append(.accepted(id: uuids.next(), timestamp: clock.now(), action: .increment, agentID: "a", stateHashBefore: "h1", stateHashAfter: "h2", rationale: "ok", previousEntryHash: ""))
        log.append(.accepted(id: uuids.next(), timestamp: clock.now(), action: .increment, agentID: "a", stateHashBefore: "h2", stateHashAfter: "h3", rationale: "ok", previousEntryHash: ""))
        
        let result = log.verify()
        #expect(result.isValid)
        #expect(result.brokenAtIndex == nil)
    }
    
    @Test("EventLog verify detects broken state hash chain")
    func eventLogVerifyBrokenStateHash() {
        var log = EventLog<AuditTestAction>()
        
        log.append(.initialization(id: uuids.next(), timestamp: clock.now(), initialStateHash: "h1"))
        log.append(.accepted(id: uuids.next(), timestamp: clock.now(), action: .increment, agentID: "a", stateHashBefore: "h1", stateHashAfter: "h2", rationale: "ok", previousEntryHash: ""))
        
        // Manually construct entry with wrong stateHashBefore
        let badEntry = AuditEvent<AuditTestAction>(
            id: uuids.next(),
            timestamp: clock.now(),
            eventType: .actionProposed(.increment, agentID: "a"),
            stateHashBefore: "WRONG",  // Doesn't match previous stateHashAfter
            stateHashAfter: "h3",
            applied: true,
            rationale: "bad",
            previousEntryHash: log.lastEntryHash  // Correct chain hash
        )
        
        // Use init(entries:) to bypass append's chain linking
        let tamperedLog = EventLog<AuditTestAction>(entries: [log[0], log[1], badEntry])
        
        let result = tamperedLog.verify()
        #expect(!result.isValid)
        #expect(result.brokenAtIndex == 2)
        #expect(result.failureReason?.contains("State hash mismatch") == true)
    }
    
    @Test("EventLog verifyReplay confirms deterministic replay")
    func eventLogVerifyReplay() {
        let reducer = AuditTestReducer()
        var state = AuditTestState(value: 0)
        var log = EventLog<AuditTestAction>()
        
        // Build log from actual reducer execution
        log.append(.initialization(
            id: uuids.next(),
            timestamp: clock.now(),
            initialStateHash: state.stateHash()
        ))
        
        // Apply increment
        let hashBefore1 = state.stateHash()
        let result1 = reducer.reduce(state: state, action: .increment)
        state = result1.newState
        log.append(.accepted(
            id: uuids.next(),
            timestamp: clock.now(),
            action: .increment,
            agentID: "test",
            stateHashBefore: hashBefore1,
            stateHashAfter: state.stateHash(),
            rationale: result1.rationale,
            previousEntryHash: ""
        ))
        
        // Apply another increment
        let hashBefore2 = state.stateHash()
        let result2 = reducer.reduce(state: state, action: .increment)
        state = result2.newState
        log.append(.accepted(
            id: uuids.next(),
            timestamp: clock.now(),
            action: .increment,
            agentID: "test",
            stateHashBefore: hashBefore2,
            stateHashAfter: state.stateHash(),
            rationale: result2.rationale,
            previousEntryHash: ""
        ))
        
        // Verify replay from initial state
        let verification = log.verifyReplay(
            initialState: AuditTestState(value: 0),
            reducer: reducer
        )
        
        #expect(verification.isValid)
    }
    
    @Test("EventLog verifyReplay fails on stateRestored")
    func eventLogVerifyReplayFailsOnStateRestored() {
        let initialState = AuditTestState(value: 0)
        var log = EventLog<AuditTestAction>()
        
        log.append(.initialization(
            id: uuids.next(),
            timestamp: clock.now(),
            initialStateHash: initialState.stateHash()  // Use actual hash
        ))
        
        log.append(.stateRestored(
            id: uuids.next(),
            timestamp: clock.now(),
            source: "snapshot",
            stateHashBefore: initialState.stateHash(),  // Use actual hash
            stateHashAfter: "h2",
            previousEntryHash: ""
        ))
        
        let result = log.verifyReplay(
            initialState: initialState,
            reducer: AuditTestReducer()
        )
        
        #expect(!result.isValid)
        #expect(result.failureReason?.contains("stateRestored") == true)
    }
    
    @Test("EventLog verifyReplay validates systemEvent hashes")
    func eventLogVerifyReplayValidatesSystemEvent() {
        let state = AuditTestState(value: 0)
        var log = EventLog<AuditTestAction>()
        
        log.append(.initialization(
            id: uuids.next(),
            timestamp: clock.now(),
            initialStateHash: state.stateHash()
        ))
        
        // System event with correct hashes (unchanged)
        log.append(.systemEvent(
            id: uuids.next(),
            timestamp: clock.now(),
            description: "Checkpoint",
            stateHash: state.stateHash(),
            previousEntryHash: ""
        ))
        
        let result = log.verifyReplay(
            initialState: state,
            reducer: AuditTestReducer()
        )
        
        #expect(result.isValid)
    }
    
    @Test("EventLog verifyReplay detects systemEvent with mismatched hashes")
    func eventLogVerifyReplayDetectsBadSystemEvent() {
        let state = AuditTestState(value: 0)
        var log = EventLog<AuditTestAction>()
        
        log.append(.initialization(
            id: uuids.next(),
            timestamp: clock.now(),
            initialStateHash: state.stateHash()
        ))
        
        // Manually create bad system event with mismatched hashes
        let badEvent = AuditEvent<AuditTestAction>(
            id: uuids.next(),
            timestamp: clock.now(),
            eventType: .systemEvent(description: "Bad"),
            stateHashBefore: state.stateHash(),
            stateHashAfter: "DIFFERENT",  // Should equal stateHashBefore
            applied: true,
            rationale: "Bad",
            previousEntryHash: log.lastEntryHash
        )
        
        let tamperedLog = EventLog<AuditTestAction>(entries: [log[0], badEvent])
        
        let result = tamperedLog.verifyReplay(
            initialState: state,
            reducer: AuditTestReducer()
        )
        
        #expect(!result.isValid)
        #expect(result.failureReason?.contains("mismatched hashes") == true)
    }
    
    @Test("EventLog actions extracts action list")
    func eventLogActions() {
        var log = EventLog<AuditTestAction>()
        
        log.append(.initialization(id: uuids.next(), timestamp: clock.now(), initialStateHash: "h"))
        log.append(.accepted(id: uuids.next(), timestamp: clock.now(), action: .increment, agentID: "a1", stateHashBefore: "h", stateHashAfter: "h2", rationale: "ok", previousEntryHash: ""))
        log.append(.rejected(id: uuids.next(), timestamp: clock.now(), action: .decrement, agentID: "a2", stateHash: "h2", rationale: "no", previousEntryHash: ""))
        log.append(.accepted(id: uuids.next(), timestamp: clock.now(), action: .setValue(10), agentID: "a1", stateHashBefore: "h2", stateHashAfter: "h3", rationale: "ok", previousEntryHash: ""))
        
        let actions = log.actions()
        #expect(actions.count == 3)
        #expect(actions[0].action == .increment)
        #expect(actions[0].agentID == "a1")
        #expect(actions[1].action == .decrement)
        #expect(actions[2].action == .setValue(10))
    }
    
    @Test("EventLog acceptedActions filters correctly")
    func eventLogAcceptedActions() {
        var log = EventLog<AuditTestAction>()
        
        log.append(.initialization(id: uuids.next(), timestamp: clock.now(), initialStateHash: "h"))
        log.append(.accepted(id: uuids.next(), timestamp: clock.now(), action: .increment, agentID: "a", stateHashBefore: "h", stateHashAfter: "h2", rationale: "ok", previousEntryHash: ""))
        log.append(.rejected(id: uuids.next(), timestamp: clock.now(), action: .decrement, agentID: "a", stateHash: "h2", rationale: "no", previousEntryHash: ""))
        
        let accepted = log.acceptedActions()
        #expect(accepted.count == 1)
        #expect(accepted[0].action == .increment)
    }
    
    @Test("EventLog rejectedActions includes rationale")
    func eventLogRejectedActions() {
        var log = EventLog<AuditTestAction>()
        
        log.append(.initialization(id: uuids.next(), timestamp: clock.now(), initialStateHash: "h"))
        log.append(.rejected(id: uuids.next(), timestamp: clock.now(), action: .decrement, agentID: "a", stateHash: "h", rationale: "Cannot decrement below zero", previousEntryHash: ""))
        
        let rejected = log.rejectedActions()
        #expect(rejected.count == 1)
        #expect(rejected[0].rationale == "Cannot decrement below zero")
    }
    
    @Test("EventLog is codable")
    func eventLogCodable() throws {
        var log = EventLog<AuditTestAction>()
        
        log.append(.initialization(id: uuids.next(), timestamp: clock.now(), initialStateHash: "h1"))
        log.append(.accepted(id: uuids.next(), timestamp: clock.now(), action: .increment, agentID: "a", stateHashBefore: "h1", stateHashAfter: "h2", rationale: "ok", previousEntryHash: ""))
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(log)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(EventLog<AuditTestAction>.self, from: data)
        
        #expect(decoded.count == log.count)
        #expect(decoded.verify().isValid)
    }
    
    @Test("EventLog conforms to Collection")
    func eventLogCollection() {
        var log = EventLog<AuditTestAction>()
        
        log.append(.initialization(id: uuids.next(), timestamp: clock.now(), initialStateHash: "h1"))
        log.append(.accepted(id: uuids.next(), timestamp: clock.now(), action: .increment, agentID: "a", stateHashBefore: "h1", stateHashAfter: "h2", rationale: "ok", previousEntryHash: ""))
        log.append(.accepted(id: uuids.next(), timestamp: clock.now(), action: .increment, agentID: "a", stateHashBefore: "h2", stateHashAfter: "h3", rationale: "ok", previousEntryHash: ""))
        
        // Can iterate
        var count = 0
        for _ in log {
            count += 1
        }
        #expect(count == 3)
        
        // Can subscript
        #expect(log[0].eventType == .initialization)
        
        // Can use Collection methods
        #expect(log.filter { $0.applied }.count == 3)
    }
}

// MARK: - Hash Chain Tamper Detection Tests

@Suite("EventLog Hash Chain")
struct EventLogHashChainTests {
    
    let clock = MockClock(fixed: Date(timeIntervalSince1970: 0))
    let uuids = MockUUIDGenerator(sequential: 1)
    
    @Test("Entry hash changes when content changes")
    func entryHashSensitivity() {
        let id1 = uuids.next()
        let id2 = uuids.next()
        
        let event1 = AuditEvent<AuditTestAction>(
            id: id1,
            timestamp: clock.now(),
            eventType: .actionProposed(.increment, agentID: "agent"),
            stateHashBefore: "before",
            stateHashAfter: "after",
            applied: true,
            rationale: "OK",
            previousEntryHash: ""
        )
        
        let event2 = AuditEvent<AuditTestAction>(
            id: id2,  // Different ID
            timestamp: clock.now(),
            eventType: .actionProposed(.increment, agentID: "agent"),
            stateHashBefore: "before",
            stateHashAfter: "after",
            applied: true,
            rationale: "OK",
            previousEntryHash: ""
        )
        
        #expect(event1.entryHash != event2.entryHash,
                "Different content should produce different hash")
    }
    
    @Test("Chain links entries via previousEntryHash")
    func chainLinkage() {
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
            previousEntryHash: ""  // Will be set by append()
        ))
        
        #expect(log[1].previousEntryHash == log[0].entryHash,
                "Second entry should reference first entry's hash")
    }
    
    @Test("Verify detects modified stateHashAfter via hash chain")
    func detectModifiedStateHash() {
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
        
        // Tamper: reconstruct middle entry with modified stateHashAfter
        // but keep original previousEntryHash (which is now wrong for the content)
        let tamperedEntry = AuditEvent<AuditTestAction>(
            id: log[1].id,
            timestamp: log[1].timestamp,
            eventType: log[1].eventType,
            stateHashBefore: log[1].stateHashBefore,
            stateHashAfter: "TAMPERED",  // Modified
            applied: log[1].applied,
            rationale: log[1].rationale,
            previousEntryHash: log[1].previousEntryHash
        )
        
        let tamperedLog = EventLog<AuditTestAction>(entries: [
            log[0],
            tamperedEntry,
            log[2]
        ])
        
        let result = tamperedLog.verify()
        #expect(!result.isValid, "verify() must detect tampered entry via hash chain break")
        #expect(result.brokenAtIndex == 2, "Chain should break at entry following tampered one")
    }
    
    @Test("Verify detects modified rationale")
    func detectModifiedRationale() {
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
            rationale: "Original rationale",
            previousEntryHash: ""
        ))
        
        let originalSecondEntryHash = log[1].entryHash
        
        // Tamper: modify rationale only
        let tampered = AuditEvent<AuditTestAction>(
            id: log[1].id,
            timestamp: log[1].timestamp,
            eventType: log[1].eventType,
            stateHashBefore: log[1].stateHashBefore,
            stateHashAfter: log[1].stateHashAfter,
            applied: log[1].applied,
            rationale: "TAMPERED rationale",  // Changed
            previousEntryHash: log[0].entryHash
        )
        
        #expect(tampered.entryHash != originalSecondEntryHash,
                "Changing rationale should change entry hash")
    }
    
    @Test("Verify detects deleted entry")
    func detectDeletedEntry() {
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
        
        // Delete middle entry
        let tamperedLog = EventLog<AuditTestAction>(entries: [log[0], log[2]])
        
        let result = tamperedLog.verify()
        #expect(!result.isValid, "Should detect missing entry via hash chain break")
        #expect(result.brokenAtIndex == 1)
    }
    
    @Test("Verify detects inserted entry")
    func detectInsertedEntry() {
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
        
        // Create an entry to insert between existing entries
        let inserted = AuditEvent<AuditTestAction>(
            id: uuids.next(),
            timestamp: clock.now(),
            eventType: .systemEvent(description: "Injected"),
            stateHashBefore: "h1",
            stateHashAfter: "h1",
            applied: true,
            rationale: "Malicious insert",
            previousEntryHash: log[0].entryHash  // Points to first entry
        )
        
        // Insert between entries (second entry still points to first, not inserted)
        let tamperedLog = EventLog<AuditTestAction>(entries: [log[0], inserted, log[1]])
        
        let result = tamperedLog.verify()
        #expect(!result.isValid, "Should detect inserted entry via hash chain break")
    }
    
    @Test("Verify detects first entry with non-empty previousEntryHash")
    func detectBadFirstEntry() {
        let badFirst = AuditEvent<AuditTestAction>(
            id: uuids.next(),
            timestamp: clock.now(),
            eventType: .initialization,
            stateHashBefore: "",
            stateHashAfter: "h1",
            applied: true,
            rationale: "Init",
            previousEntryHash: "should-be-empty"  // Invalid for first entry
        )
        
        let log = EventLog<AuditTestAction>(entries: [badFirst])
        
        let result = log.verify()
        #expect(!result.isValid)
        #expect(result.brokenAtIndex == 0)
        #expect(result.failureReason?.contains("First entry") == true)
    }
    
    @Test("Valid chain passes verification")
    func validChainPasses() {
        var log = EventLog<AuditTestAction>()
        
        log.append(.initialization(
            id: uuids.next(),
            timestamp: clock.now(),
            initialStateHash: "h1"
        ))
        
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
        
        clock.advance(by: 1)
        log.append(.rejected(
            id: uuids.next(),
            timestamp: clock.now(),
            action: .decrement,
            agentID: "agent",
            stateHash: "h2",
            rationale: "Rejected",
            previousEntryHash: ""
        ))
        
        clock.advance(by: 1)
        log.append(.systemEvent(
            id: uuids.next(),
            timestamp: clock.now(),
            description: "Checkpoint",
            stateHash: "h2",
            previousEntryHash: ""
        ))
        
        clock.advance(by: 1)
        log.append(.accepted(
            id: uuids.next(),
            timestamp: clock.now(),
            action: .setValue(10),
            agentID: "agent",
            stateHashBefore: "h2",
            stateHashAfter: "h3",
            rationale: "OK",
            previousEntryHash: ""
        ))
        
        let result = log.verify()
        #expect(result.isValid, "Untampered chain should pass verification")
    }
}

// MARK: - Integration Tests

@Suite("Audit Integration")
struct AuditIntegrationTests {
    
    @Test("Full audit cycle with deterministic primitives")
    func fullAuditCycle() {
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
        
        // Process actions
        let actions: [AuditTestAction] = [.increment, .increment, .decrement, .setValue(-1), .setValue(10)]
        
        for action in actions {
            clock.advance(by: 1)
            let hashBefore = state.stateHash()
            let result = reducer.reduce(state: state, action: action)
            
            if result.applied {
                state = result.newState
                log.append(.accepted(
                    id: uuids.next(),
                    timestamp: clock.now(),
                    action: action,
                    agentID: "test-agent",
                    stateHashBefore: hashBefore,
                    stateHashAfter: state.stateHash(),
                    rationale: result.rationale,
                    previousEntryHash: ""
                ))
            } else {
                log.append(.rejected(
                    id: uuids.next(),
                    timestamp: clock.now(),
                    action: action,
                    agentID: "test-agent",
                    stateHash: hashBefore,
                    rationale: result.rationale,
                    previousEntryHash: ""
                ))
            }
        }
        
        // Verify
        #expect(log.count == 6)  // 1 init + 5 actions
        #expect(log.acceptedActions().count == 4)
        #expect(log.rejectedActions().count == 1)
        #expect(log.verify().isValid)
        
        // Verify replay
        let replayResult = log.verifyReplay(
            initialState: AuditTestState(value: 0),
            reducer: reducer
        )
        #expect(replayResult.isValid)
        
        // Final state should match
        #expect(state.value == 10)
    }
    
    @Test("Serialization preserves hash chain integrity")
    func serializationPreservesChain() throws {
        let clock = MockClock(fixed: Date(timeIntervalSince1970: 0))
        let uuids = MockUUIDGenerator(sequential: 1)
        
        var log = EventLog<AuditTestAction>()
        
        log.append(.initialization(
            id: uuids.next(),
            timestamp: clock.now(),
            initialStateHash: "h1"
        ))
        
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
        
        // Serialize
        let encoder = JSONEncoder()
        let data = try encoder.encode(log)
        
        // Deserialize
        let decoder = JSONDecoder()
        let restored = try decoder.decode(EventLog<AuditTestAction>.self, from: data)
        
        // Verify chain integrity preserved
        #expect(restored.verify().isValid)
        
        // Verify entry hashes match
        for i in 0..<log.count {
            #expect(log[i].entryHash == restored[i].entryHash,
                    "Entry hash should survive serialization round-trip")
        }
    }
}
