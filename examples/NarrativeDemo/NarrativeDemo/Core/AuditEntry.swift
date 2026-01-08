//
//  AuditEntry.swift
//  NarrativeDemo
//
//  Created by Stephen Sweeney on 1/6/26.
//

import Foundation
import CryptoKit

// MARK: - Audit Entry
/// Represents a single entry in the SwiftVector audit log.
/// This enables deterministic replay and satisfies the whitepaper's requirement:
/// "Every change is attributable to a specific agent, model, and prompt version."
///
/// Key properties for regulatory compliance:
/// - Immutable (struct)
/// - Sendable (safe across actors)
/// - State hash enables byte-identical replay verification
struct AuditEntry: Sendable, Identifiable {
    let id = UUID()
    let timestamp: Date
    let eventType: EventType
    let stateHashBefore: String
    let stateHashAfter: String
    let applied: Bool
    let resultDescription: String
    
    enum EventType: Sendable, Equatable {
        case initialization
        case actionProposed(StoryAction, agentID: String)
    }
}

// MARK: - State Hashing for Replay Verification

extension AdventureState {
    /// Generates a deterministic hash of the complete state for replay verification.
    /// Same state → same hash, enabling exact replay confirmation.
    ///
    /// All state properties are included to ensure byte-identical replay verification.
    /// The eventLog is fully hashed (not just count) to detect any divergence.
    nonisolated func hash() -> String {
        // Create deterministic string representation of ALL state
        // Using a delimiter that won't appear in normal content
        let eventLogHash = eventLog.joined(separator: "␞")  // Unit separator
        let inventoryHash = inventory.sorted().joined(separator: "␞")
        
        let representation = """
        location:␟\(location)␟
        health:␟\(health)␟
        gold:␟\(gold)␟
        inventory:␟\(inventoryHash)␟
        eventLog:␟\(eventLogHash)␟
        isGameOver:␟\(isGameOver)␟
        """
        
        let data = Data(representation.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}
