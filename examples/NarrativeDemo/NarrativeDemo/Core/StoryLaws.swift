//
//  StoryLaws.swift
//  NarrativeDemo
//
//  Copyright © 2026 Flightworks Aerial LLC. All rights reserved.
//

import SwiftVectorCore

// MARK: - ChronicleLaw Governance for NarrativeDemo
//
// These Laws implement the governance layer for the adventure game.
// Each Law is a pure function: same (state, action) → same LawVerdict, always.
//
// Previously, these validations were guard clauses in StoryReducer.
// As guard clauses, only the FIRST failure was captured — all subsequent
// violations were invisible to the audit trail. As Laws, ALL violations
// are evaluated independently and recorded in the CompositionTrace.
//
// Example: A dead character tries to find 500 gold in a dark cave.
// OLD (reducer guards): Only "Game over." is recorded.
// NEW (Laws): GameOverLaw + GoldBudgetLaw both deny, both reasons visible.

// MARK: - GameOverLaw

/// Denies all actions when the character is dead.
///
/// Extracted from the `guard !state.isGameOver` at the top of StoryReducer.
struct GameOverLaw: Law {
    let lawID = "GameOverLaw"

    func evaluate(state: AdventureState, action: StoryAction) -> LawVerdict {
        if state.isGameOver {
            return LawVerdict(
                lawID: lawID,
                decision: .deny,
                reason: "Character is dead (game over)"
            )
        }
        return LawVerdict(lawID: lawID, decision: .allow, reason: "Character is alive")
    }
}

// MARK: - GoldBudgetLaw

/// Denies `findGold` actions that exceed the world's gold limit of 100.
///
/// Extracted from the `guard amount <= 100` in StoryReducer's `.findGold` case.
struct GoldBudgetLaw: Law {
    let lawID = "GoldBudgetLaw"

    func evaluate(state: AdventureState, action: StoryAction) -> LawVerdict {
        if case .findGold(let amount) = action, amount > 100 {
            return LawVerdict(
                lawID: lawID,
                decision: .deny,
                reason: "Gold \(amount) exceeds limit of 100"
            )
        }
        return LawVerdict(lawID: lawID, decision: .allow, reason: "Within budget")
    }
}

// MARK: - SafeLocationLaw

/// Denies `rest` actions in dangerous locations.
///
/// Extracted from the `guard !dangerousLocations.contains(...)` in
/// StoryReducer's `.rest` case.
struct SafeLocationLaw: Law {
    let lawID = "SafeLocationLaw"

    private let dangerousLocations = ["dark cave", "ruined tower"]

    func evaluate(state: AdventureState, action: StoryAction) -> LawVerdict {
        if case .rest = action, dangerousLocations.contains(state.location) {
            return LawVerdict(
                lawID: lawID,
                decision: .deny,
                reason: "Cannot rest in \(state.location)"
            )
        }
        return LawVerdict(lawID: lawID, decision: .allow, reason: "Location is safe")
    }
}

// MARK: - InventoryLaw

/// Denies `findItem` actions for items already in the inventory.
///
/// Extracted from the `guard !newState.inventory.contains(item)` in
/// StoryReducer's `.findItem` case.
struct InventoryLaw: Law {
    let lawID = "InventoryLaw"

    func evaluate(state: AdventureState, action: StoryAction) -> LawVerdict {
        if case .findItem(let item) = action, state.inventory.contains(item) {
            return LawVerdict(
                lawID: lawID,
                decision: .deny,
                reason: "Already have \(item)"
            )
        }
        return LawVerdict(lawID: lawID, decision: .allow, reason: "Item is new")
    }
}

// MARK: - StoryLaws Namespace

/// Factory for the default ChronicleLaw governance policy.
///
/// Composes all four StoryLaws with `denyWins` — if any Law denies,
/// the action is blocked, but ALL verdicts are recorded in the trace.
enum StoryLaws {
    static func defaultPolicy() -> GovernancePolicy<AdventureState, StoryAction> {
        GovernancePolicy(
            laws: [
                AnyLaw(GameOverLaw()),
                AnyLaw(GoldBudgetLaw()),
                AnyLaw(SafeLocationLaw()),
                AnyLaw(InventoryLaw())
            ],
            compositionRule: .denyWins,
            jurisdictionID: "ChronicleLaw"
        )
    }
}
