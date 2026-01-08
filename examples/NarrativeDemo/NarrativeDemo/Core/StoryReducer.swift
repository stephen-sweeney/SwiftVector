//
//  StoryReducer.swift
//  NarrativeDemo
//
//  Created by Stephen Sweeney on 1/3/26.
//

/// MARK: - Reducer (Deterministic + Validation)
/// The Reducer demonstrates the "deterministic" component of SwiftVector.
/// It validates all proposed actions against world rules.
///
/// Key insight: The Reducer is a pure function. Same state + same action = same result.
/// This makes the system auditable, testable, and predictable despite LLM non-determinism.

enum StoryReducer {
    // LEARNING-DEBT(workaround): Swift 6 infers @MainActor even on static enum methods
    // See LEARNING.md for details.
    nonisolated static func reduce(state: AdventureState, proposed action: StoryAction) -> (newState: AdventureState, applied: Bool, description: String) {
        guard !state.isGameOver else {
            return (state, false, "⚠️ Action rejected: Game over.")
        }
        
        var newState = state
        
        switch action {
        case .moveTo(let location):
            newState.location = location
            newState.eventLog.append("🤖 Agent proposed: move to \(location)")
            newState.eventLog.append("✅ Moved to \(location.indefiniteArticlePrefixed).")
            return (newState, true, "Moved to \(location.indefiniteArticlePrefixed).")
            
        case .findGold(let amount):
            // Validate: reject unreasonable amounts (demonstrates catching invalid proposals)
            guard amount <= 100 else {
                newState.eventLog.append("🤖 Agent proposed: find \(amount) gold")
                newState.eventLog.append("❌ Rejected: Amount \(amount) exceeds world rules.")
                return (newState, false, "Rejected: Gold amount \(amount) exceeds world rules.")
            }
            newState.gold += amount
            newState.eventLog.append("🤖 Agent proposed: find \(amount) gold")
            newState.eventLog.append("✅ Found \(amount) gold!")
            return (newState, true, "Found \(amount) gold!")
            
        case .takeDamage(let amount):
            newState.health = max(0, newState.health - amount)
            newState.eventLog.append("🤖 Agent proposed: take \(amount) damage")
            newState.eventLog.append("✅ Ambushed! Took \(amount) damage.")
            return (newState, true, "Took \(amount) damage. Health now \(newState.health).")
            
        case .findItem(let item):
            // Validate: no duplicate items
            guard !newState.inventory.contains(item) else {
                newState.eventLog.append("🤖 Agent proposed: find \(item)")
                newState.eventLog.append("❌ Rejected: Already have \(item).")
                return (newState, false, "Rejected: Already have \(item).")
            }
            newState.inventory.append(item)
            newState.eventLog.append("🤖 Agent proposed: find \(item)")
            newState.eventLog.append("✅ Discovered a \(item).")
            return (newState, true, "Discovered a \(item).")
            
        case .rest(let healing):
            // Validate: can't rest in dangerous locations
            let dangerousLocations = ["dark cave", "ruined tower"]
            guard !dangerousLocations.contains(newState.location) else {
                newState.eventLog.append("🤖 Agent proposed: rest")
                newState.eventLog.append("❌ Rejected: Too dangerous to rest here.")
                return (newState, false, "Rejected: Cannot rest in \(newState.location).")
            }
            let actualHealing = min(100 - newState.health, healing)
            newState.health += actualHealing
            newState.eventLog.append("🤖 Agent proposed: rest")
            newState.eventLog.append("✅ Rested and recovered \(actualHealing) health.")
            return (newState, true, "Recovered \(actualHealing) health.")
        }
    }
}
