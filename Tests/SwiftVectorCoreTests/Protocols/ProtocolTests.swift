//
//  ProtocolTests.swift
//  SwiftVectorCoreTests
//
//  Created by Stephen Sweeney
//  Copyright © 2026 Flightworks Aerial LLC. All rights reserved.
//

import Testing
import Foundation
import CryptoKit
@testable import SwiftVectorCore

// MARK: - Test Fixtures

/// Minimal State implementation for testing
struct TestState: State {
    var counter: Int = 0
    var label: String = "initial"
}

/// Minimal Action implementation for testing
enum TestAction: Action {
    case increment
    case decrement
    case setLabel(String)
    
    var actionDescription: String {
        switch self {
        case .increment: return "Increment counter"
        case .decrement: return "Decrement counter"
        case .setLabel(let s): return "Set label to '\(s)'"
        }
    }
    
    /// Stable correlation ID derived from action identity.
    /// In production code, this would typically be stored explicitly.
    /// For tests, deriving from action type ensures stability.
    var correlationID: UUID {
        switch self {
        case .increment:
            return UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        case .decrement:
            return UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        case .setLabel(let s):
            return TestAction.stableUUID(for: s)
        }
    }
    
    /// Generates a deterministic UUID from a string using SHA256.
    /// - Uses a standardized, cryptographically stable hash (not Swift's random-seeded hashValue).
    /// - Collision-resistant compared to naive sums.
    /// - Reusable across test fixtures, and consistent with core state hashing.
    private static func stableUUID(for string: String) -> UUID {
        let digest = SHA256.hash(data: Data(string.utf8))
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        let uuidString =
        "\(hex.prefix(8))-\(hex.dropFirst(8).prefix(4))-\(hex.dropFirst(12).prefix(4))-" +
        "\(hex.dropFirst(16).prefix(4))-\(hex.dropFirst(20).prefix(12))"
        return UUID(uuidString: String(uuidString))!
    }
    
    /// Minimal Reducer implementation for testing
    struct TestReducer: Reducer {
        func reduce(state: TestState, action: TestAction) -> ReducerResult<TestState> {
            var newState = state
            
            switch action {
            case .increment:
                newState.counter += 1
                return .accepted(newState, rationale: "Incremented to \(newState.counter)")
                
            case .decrement:
                guard state.counter > 0 else {
                    return .rejected(state, rationale: "Cannot decrement below zero")
                }
                newState.counter -= 1
                return .accepted(newState, rationale: "Decremented to \(newState.counter)")
                
            case .setLabel(let label):
                guard !label.isEmpty else {
                    return .rejected(state, rationale: "Label cannot be empty")
                }
                newState.label = label
                return .accepted(newState, rationale: "Label set to '\(label)'")
            }
        }
    }
    
    // MARK: - State Protocol Tests
    
    @Suite("State Protocol")
    struct StateProtocolTests {
        
        @Test("State conforms to required protocols")
        func stateConformance() {
            // Verify TestState satisfies all State requirements
            let state = TestState()
            
            // Sendable - compiles if conformant
            let _: any Sendable = state
            
            // Equatable
            let state2 = TestState()
            #expect(state == state2)
            
            // Codable
            let encoder = JSONEncoder()
            let data = try? encoder.encode(state)
            #expect(data != nil)
        }
        
        @Test("State hash is deterministic")
        func stateHashDeterminism() {
            let state1 = TestState(counter: 42, label: "test")
            let state2 = TestState(counter: 42, label: "test")
            
            let hash1 = state1.stateHash()
            let hash2 = state2.stateHash()
            
            #expect(hash1 == hash2, "Same state must produce same hash")
        }
        
        @Test("State hash changes with state")
        func stateHashSensitivity() {
            let state1 = TestState(counter: 1, label: "a")
            let state2 = TestState(counter: 2, label: "a")
            let state3 = TestState(counter: 1, label: "b")
            
            let hash1 = state1.stateHash()
            let hash2 = state2.stateHash()
            let hash3 = state3.stateHash()
            
            #expect(hash1 != hash2, "Different counter should produce different hash")
            #expect(hash1 != hash3, "Different label should produce different hash")
            #expect(hash2 != hash3, "Different states should produce different hashes")
        }
        
        @Test("State hash is valid SHA256 format")
        func stateHashFormat() {
            let state = TestState()
            let hash = state.stateHash()
            
            // SHA256 produces 64 hex characters
            #expect(hash.count == 64)
            
            // All characters should be valid hex
            let hexCharacters = CharacterSet(charactersIn: "0123456789abcdef")
            let allHex = hash.unicodeScalars.allSatisfy { hexCharacters.contains($0) }
            #expect(allHex, "Hash should contain only lowercase hex characters")
        }
    }
    
    // MARK: - Action Protocol Tests
    
    @Suite("Action Protocol")
    struct ActionProtocolTests {
        
        @Test("Action conforms to required protocols")
        func actionConformance() {
            let action = TestAction.increment
            
            // Sendable
            let _: any Sendable = action
            
            // Equatable
            #expect(action == TestAction.increment)
            #expect(action != TestAction.decrement)
            
            // Codable
            let encoder = JSONEncoder()
            let data = try? encoder.encode(action)
            #expect(data != nil)
        }
        
        @Test("Action provides description")
        func actionDescription() {
            #expect(TestAction.increment.actionDescription == "Increment counter")
            #expect(TestAction.decrement.actionDescription == "Decrement counter")
            #expect(TestAction.setLabel("hello").actionDescription == "Set label to 'hello'")
        }
        
        @Test("Action correlationID is stable across accesses")
        func actionCorrelationIDStability() {
            let action = TestAction.increment
            
            let id1 = action.correlationID
            let id2 = action.correlationID
            
            #expect(id1 == id2, "correlationID must return same value on repeated access")
        }
        
        @Test("Different actions have distinct correlationIDs")
        func actionCorrelationIDDistinctness() {
            let increment = TestAction.increment
            let decrement = TestAction.decrement
            
            #expect(increment.correlationID != decrement.correlationID,
                    "Different actions should have distinct correlation IDs")
        }
        
        @Test("ActionProposal captures metadata")
        func actionProposalMetadata() {
            let action = TestAction.increment
            let timestamp = Date(timeIntervalSince1970: 1000)  // Explicit, deterministic
            let proposal = ActionProposal(
                action: action,
                agentID: "test-agent",
                timestamp: timestamp
            )
            
            #expect(proposal.action == action)
            #expect(proposal.agentID == "test-agent")
            #expect(proposal.timestamp == timestamp)
        }
    }
    
    // MARK: - Reducer Protocol Tests
    
    @Suite("Reducer Protocol")
    struct ReducerProtocolTests {
        
        let reducer = TestReducer()
        
        @Test("Reducer accepts valid actions")
        func reducerAcceptsValid() {
            let state = TestState(counter: 0)
            let result = reducer.reduce(state: state, action: .increment)
            
            #expect(result.applied == true)
            #expect(result.newState.counter == 1)
            #expect(result.rationale.contains("Incremented"))
        }
        
        @Test("Reducer rejects invalid actions")
        func reducerRejectsInvalid() {
            let state = TestState(counter: 0)
            let result = reducer.reduce(state: state, action: .decrement)
            
            #expect(result.applied == false)
            #expect(result.newState == state, "State should be unchanged on rejection")
            #expect(result.rationale.contains("Cannot decrement"))
        }
        
        @Test("Reducer is deterministic")
        func reducerDeterminism() {
            let state = TestState(counter: 5)
            let action = TestAction.increment
            
            let result1 = reducer.reduce(state: state, action: action)
            let result2 = reducer.reduce(state: state, action: action)
            
            #expect(result1.newState == result2.newState)
            #expect(result1.applied == result2.applied)
            #expect(result1.rationale == result2.rationale)
        }
        
        @Test("ReducerResult factory methods work correctly")
        func reducerResultFactories() {
            let state = TestState()
            
            let accepted = ReducerResult.accepted(state, rationale: "OK")
            #expect(accepted.applied == true)
            #expect(accepted.rationale == "OK")
            
            let rejected = ReducerResult.rejected(state, rationale: "No")
            #expect(rejected.applied == false)
            #expect(rejected.rationale == "No")
        }
        
        @Test("AnyReducer type erasure works")
        func anyReducerTypeErasure() {
            let concreteReducer = TestReducer()
            let anyReducer = AnyReducer(concreteReducer)
            
            let state = TestState(counter: 10)
            let action = TestAction.increment
            
            let concreteResult = concreteReducer.reduce(state: state, action: action)
            let anyResult = anyReducer.reduce(state: state, action: action)
            
            #expect(concreteResult.newState == anyResult.newState)
            #expect(concreteResult.applied == anyResult.applied)
        }
    }
    
    // MARK: - Integration Tests
    
    @Suite("Protocol Integration")
    struct ProtocolIntegrationTests {
        
        @Test("Full reduce cycle produces consistent hashes")
        func reduceCycleHashes() {
            let reducer = TestReducer()
            var state = TestState()
            
            let hashBefore = state.stateHash()
            
            let result = reducer.reduce(state: state, action: .increment)
            state = result.newState
            
            let hashAfter = state.stateHash()
            
            #expect(hashBefore != hashAfter, "State change should change hash")
            
            // Replaying same action from same initial state should produce same hash
            let replayState = TestState()
            let replayResult = reducer.reduce(state: replayState, action: .increment)
            let replayHash = replayResult.newState.stateHash()
            
            #expect(hashAfter == replayHash, "Replay should produce identical hash")
        }
        
        @Test("Rejected actions preserve state hash")
        func rejectedActionHashPreservation() {
            let reducer = TestReducer()
            let state = TestState(counter: 0)
            
            let hashBefore = state.stateHash()
            
            let result = reducer.reduce(state: state, action: .decrement)
            
            #expect(result.applied == false)
            #expect(result.newState.stateHash() == hashBefore,
                    "Rejected action should not change state hash")
        }
        
        @Test("Action sequence produces deterministic final state")
        func actionSequenceDeterminism() {
            let reducer = TestReducer()
            let actions: [TestAction] = [
                .increment,
                .increment,
                .setLabel("testing"),
                .decrement,
                .increment
            ]
            
            // First run
            var state1 = TestState()
            for action in actions {
                let result = reducer.reduce(state: state1, action: action)
                if result.applied {
                    state1 = result.newState
                }
            }
            
            // Second run
            var state2 = TestState()
            for action in actions {
                let result = reducer.reduce(state: state2, action: action)
                if result.applied {
                    state2 = result.newState
                }
            }
            
            #expect(state1 == state2, "Same action sequence should produce same final state")
            #expect(state1.stateHash() == state2.stateHash(), "Final hashes should match")
        }
    }
}
