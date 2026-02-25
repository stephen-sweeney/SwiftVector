//
//  StoryReducer.swift
//  NarrativeDemo
//
//  Created by Stephen Sweeney on 1/3/26.
//

import SwiftVectorCore

/// MARK: - Reducer (Deterministic + Validation)
/// The Reducer is a pure function that validates and applies actions to state.
///
/// ## Governance Layer (Defense in Depth)
/// Cross-cutting validation rules are now ALSO enforced by composable Laws
/// in the governance layer (see `StoryLaws.swift`). When a `GovernancePolicy`
/// is active, Laws evaluate ALL proposed actions before the reducer runs:
/// - If governance denies, the reducer never executes and ALL deny reasons
///   are captured in the `CompositionTrace`.
/// - If governance allows, the reducer provides a second validation layer.
///
/// The reducer guards remain as defense-in-depth. Even without governance,
/// the reducer rejects invalid actions. With governance, the Laws provide
/// multi-rejection visibility (all violations, not just the first).
///
/// Same state + same action = same result. Auditable, testable, predictable.

struct StoryReducer: Reducer {
    func reduce(state: AdventureState, action: StoryAction) -> ReducerResult<AdventureState> {
        // Defense-in-depth: also enforced by GameOverLaw in governance layer
        guard !state.isGameOver else {
            return .rejected(state, rationale: "Game over.")
        }

        var newState = state

        switch action {
        case .moveTo(let location):
            newState.location = location
            return .accepted(newState, rationale: "Moved to \(location.indefiniteArticlePrefixed).")

        case .findGold(let amount):
            // Defense-in-depth: also enforced by GoldBudgetLaw in governance layer
            guard amount <= 100 else {
                return .rejected(state, rationale: "Gold amount \(amount) exceeds world rules.")
            }
            newState.gold += amount
            return .accepted(newState, rationale: "Found \(amount) gold!")

        case .takeDamage(let amount):
            newState.health = max(0, newState.health - amount)
            return .accepted(newState, rationale: "Took \(amount) damage. Health now \(newState.health).")

        case .findItem(let item):
            // Defense-in-depth: also enforced by InventoryLaw in governance layer
            guard !newState.inventory.contains(item) else {
                return .rejected(state, rationale: "Already have \(item).")
            }
            newState.inventory.append(item)
            return .accepted(newState, rationale: "Discovered a \(item).")

        case .rest(let healing):
            // Defense-in-depth: also enforced by SafeLocationLaw in governance layer
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
