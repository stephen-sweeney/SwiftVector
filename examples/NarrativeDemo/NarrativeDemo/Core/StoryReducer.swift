//
//  StoryReducer.swift
//  NarrativeDemo
//
//  Created by Stephen Sweeney on 1/3/26.
//

import SwiftVectorCore

/// MARK: - Reducer (Deterministic + Validation)
/// The Reducer demonstrates the "deterministic" component of SwiftVector.
/// It validates all proposed actions against world rules.
///
/// Key insight: The Reducer is a pure function. Same state + same action = same result.
/// This makes the system auditable, testable, and predictable despite LLM non-determinism.

struct StoryReducer: Reducer {
    func reduce(state: AdventureState, action: StoryAction) -> ReducerResult<AdventureState> {
        guard !state.isGameOver else {
            return .rejected(state, rationale: "Game over.")
        }
        
        var newState = state
        
        switch action {
        case .moveTo(let location):
            newState.location = location
            return .accepted(newState, rationale: "Moved to \(location.indefiniteArticlePrefixed).")
            
        case .findGold(let amount):
            // Validate: reject unreasonable amounts (demonstrates catching invalid proposals)
            guard amount <= 100 else {
                return .rejected(state, rationale: "Gold amount \(amount) exceeds world rules.")
            }
            newState.gold += amount
            return .accepted(newState, rationale: "Found \(amount) gold!")
            
        case .takeDamage(let amount):
            newState.health = max(0, newState.health - amount)
            return .accepted(newState, rationale: "Took \(amount) damage. Health now \(newState.health).")
            
        case .findItem(let item):
            // Validate: no duplicate items
            guard !newState.inventory.contains(item) else {
                return .rejected(state, rationale: "Already have \(item).")
            }
            newState.inventory.append(item)
            return .accepted(newState, rationale: "Discovered a \(item).")
            
        case .rest(let healing):
            // Validate: can't rest in dangerous locations
            let dangerousLocations = ["dark cave", "ruined tower"]
            guard !dangerousLocations.contains(newState.location) else {
                return .rejected(state, rationale: "Cannot rest in \(newState.location).")
            }
            let actualHealing = min(100 - newState.health, healing)
            newState.health += actualHealing
            return .accepted(newState, rationale: "Recovered \(actualHealing) health.")
        }
    }
}
