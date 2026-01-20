//
//  AdventureState.swift
//  NarrativeDemo
//
//  Created by Stephen Sweeney on 1/3/26.
//

import Foundation
import SwiftVectorCore

// MARK: - State
struct AdventureState: State {
    var location: String = "ancient forest"
    var health: Int = 100
    var gold: Int = 0
    var inventory: [String] = []
    
    // LEARNING-DEBT(workaround): Swift 6 actor isolation inference on computed properties
    // See LEARNING.md for details.
    nonisolated var isGameOver: Bool { health <= 0 }
    
    var currentScene: String {
        if isGameOver {
            return "💀 Game Over. You have perished in \(location.indefiniteArticlePrefixed)."
        }
        return """
        You are in \(location.indefiniteArticlePrefixed).
        Health: \(health) ❤️   Gold: \(gold) 💰
        Inventory: \(inventory.isEmpty ? "nothing" : inventory.joined(separator: ", "))
        """
    }
    
    // LEARNING-DEBT(workaround): Swift 6 synthesized initializer isolation inference
    // Explicit nonisolated required to prevent @MainActor inference.
    // See LEARNING.md for details.
    nonisolated init() { }
}

