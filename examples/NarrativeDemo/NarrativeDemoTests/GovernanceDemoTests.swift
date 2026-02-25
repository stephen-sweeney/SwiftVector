//
//  GovernanceDemoTests.swift
//  NarrativeDemoTests
//
//  Copyright © 2026 Flightworks Aerial LLC. All rights reserved.
//

import Foundation
import SwiftVectorCore
import SwiftVectorTesting
import Testing
@testable import NarrativeDemo

// MARK: - StoryLaw Isolation Tests

@Suite("StoryLaw Isolation", .serialized)
struct StoryLawIsolationTests {

    // MARK: GameOverLaw

    @Test("GameOverLaw denies all actions when character is dead")
    func gameOverLawDeniesWhenDead() {
        let law = GameOverLaw()
        var state = AdventureState()
        state.health = 0

        let actions: [StoryAction] = [
            .moveTo(location: "dark cave"),
            .findGold(amount: 50),
            .takeDamage(amount: 10),
            .findItem("sword"),
            .rest(healing: 25)
        ]

        for action in actions {
            let verdict = law.evaluate(state: state, action: action)
            #expect(verdict.decision == .deny,
                    "GameOverLaw should deny \(action.actionDescription) when dead")
            #expect(verdict.lawID == "GameOverLaw")
        }
    }

    @Test("GameOverLaw allows actions when character is alive")
    func gameOverLawAllowsWhenAlive() {
        let law = GameOverLaw()
        let state = AdventureState() // health = 100

        let verdict = law.evaluate(state: state, action: .moveTo(location: "dark cave"))

        #expect(verdict.decision == .allow)
        #expect(verdict.lawID == "GameOverLaw")
    }

    // MARK: GoldBudgetLaw

    @Test("GoldBudgetLaw denies gold exceeding limit of 100")
    func goldBudgetLawDeniesExcessive() {
        let law = GoldBudgetLaw()
        let state = AdventureState()

        let verdict = law.evaluate(state: state, action: .findGold(amount: 500))

        #expect(verdict.decision == .deny)
        #expect(verdict.lawID == "GoldBudgetLaw")
        #expect(verdict.reason.contains("500"))
        #expect(verdict.reason.contains("100"))
    }

    @Test("GoldBudgetLaw allows gold within budget")
    func goldBudgetLawAllowsWithinBudget() {
        let law = GoldBudgetLaw()
        let state = AdventureState()

        // At the boundary
        let verdict100 = law.evaluate(state: state, action: .findGold(amount: 100))
        #expect(verdict100.decision == .allow, "100 is within budget")

        // Below boundary
        let verdict50 = law.evaluate(state: state, action: .findGold(amount: 50))
        #expect(verdict50.decision == .allow, "50 is within budget")
    }

    @Test("GoldBudgetLaw allows non-gold actions regardless")
    func goldBudgetLawAllowsNonGold() {
        let law = GoldBudgetLaw()
        let state = AdventureState()

        let verdict = law.evaluate(state: state, action: .moveTo(location: "dark cave"))
        #expect(verdict.decision == .allow)
    }

    // MARK: SafeLocationLaw

    @Test("SafeLocationLaw denies rest in dangerous locations")
    func safeLocationLawDeniesRestInDanger() {
        let law = SafeLocationLaw()

        for location in ["dark cave", "ruined tower"] {
            var state = AdventureState()
            state.location = location

            let verdict = law.evaluate(state: state, action: .rest(healing: 25))

            #expect(verdict.decision == .deny,
                    "Should deny rest in \(location)")
            #expect(verdict.lawID == "SafeLocationLaw")
            #expect(verdict.reason.contains(location))
        }
    }

    @Test("SafeLocationLaw allows rest in safe locations")
    func safeLocationLawAllowsRestInSafe() {
        let law = SafeLocationLaw()
        let state = AdventureState() // Default: "ancient forest"

        let verdict = law.evaluate(state: state, action: .rest(healing: 25))

        #expect(verdict.decision == .allow)
    }

    @Test("SafeLocationLaw allows non-rest actions in dangerous locations")
    func safeLocationLawAllowsNonRestInDanger() {
        let law = SafeLocationLaw()
        var state = AdventureState()
        state.location = "dark cave"

        let verdict = law.evaluate(state: state, action: .findGold(amount: 50))

        #expect(verdict.decision == .allow,
                "Non-rest actions should be allowed anywhere")
    }

    // MARK: InventoryLaw

    @Test("InventoryLaw denies duplicate items")
    func inventoryLawDeniesDuplicate() {
        let law = InventoryLaw()
        var state = AdventureState()
        state.inventory = ["rusty sword"]

        let verdict = law.evaluate(state: state, action: .findItem("rusty sword"))

        #expect(verdict.decision == .deny)
        #expect(verdict.lawID == "InventoryLaw")
        #expect(verdict.reason.contains("rusty sword"))
    }

    @Test("InventoryLaw allows new items")
    func inventoryLawAllowsNewItem() {
        let law = InventoryLaw()
        let state = AdventureState() // Empty inventory

        let verdict = law.evaluate(state: state, action: .findItem("rusty sword"))

        #expect(verdict.decision == .allow)
    }

    @Test("InventoryLaw allows non-item actions regardless of inventory")
    func inventoryLawAllowsNonItem() {
        let law = InventoryLaw()
        var state = AdventureState()
        state.inventory = ["rusty sword"]

        let verdict = law.evaluate(state: state, action: .findGold(amount: 50))

        #expect(verdict.decision == .allow)
    }

    // MARK: Determinism

    @Test("All StoryLaws are deterministic — same inputs produce same verdicts")
    func storyLawsDeterministic() {
        var state = AdventureState()
        state.health = 0
        state.location = "dark cave"
        state.inventory = ["rusty sword"]

        for _ in 0..<3 {
            let go1 = GameOverLaw().evaluate(state: state, action: .findGold(amount: 500))
            let go2 = GameOverLaw().evaluate(state: state, action: .findGold(amount: 500))
            #expect(go1 == go2, "GameOverLaw must be deterministic")

            let gb1 = GoldBudgetLaw().evaluate(state: state, action: .findGold(amount: 500))
            let gb2 = GoldBudgetLaw().evaluate(state: state, action: .findGold(amount: 500))
            #expect(gb1 == gb2, "GoldBudgetLaw must be deterministic")

            let sl1 = SafeLocationLaw().evaluate(state: state, action: .rest(healing: 25))
            let sl2 = SafeLocationLaw().evaluate(state: state, action: .rest(healing: 25))
            #expect(sl1 == sl2, "SafeLocationLaw must be deterministic")

            let il1 = InventoryLaw().evaluate(state: state, action: .findItem("rusty sword"))
            let il2 = InventoryLaw().evaluate(state: state, action: .findItem("rusty sword"))
            #expect(il1 == il2, "InventoryLaw must be deterministic")
        }
    }

    @Test("StoryLaw IDs are stable")
    func storyLawIDsStable() {
        #expect(GameOverLaw().lawID == "GameOverLaw")
        #expect(GoldBudgetLaw().lawID == "GoldBudgetLaw")
        #expect(SafeLocationLaw().lawID == "SafeLocationLaw")
        #expect(InventoryLaw().lawID == "InventoryLaw")
    }
}

// MARK: - StoryLaw Composition Tests

@Suite("StoryLaw Composition", .serialized)
struct StoryLawCompositionTests {

    @Test("Multiple violations produce deny with ALL verdicts captured")
    func multipleViolationsAllCaptured() {
        // Motivating scenario: dead character tries to find 500 gold.
        // OLD: Reducer's first guard (game over) catches it, gold violation invisible.
        // NEW: All Laws evaluate independently, both deny reasons visible.

        var state = AdventureState()
        state.health = 0 // GameOverLaw: deny

        let policy = StoryLaws.defaultPolicy()

        // findGold(500) violates: GameOverLaw + GoldBudgetLaw
        let trace = policy.evaluate(
            state: state,
            action: .findGold(amount: 500)
        )

        #expect(trace.composedDecision == .deny)
        let denyVerdicts = trace.verdicts.filter { $0.decision == .deny }
        #expect(denyVerdicts.count >= 2,
                "Should capture GameOverLaw AND GoldBudgetLaw denials")

        let denyLawIDs = Set(denyVerdicts.map(\.lawID))
        #expect(denyLawIDs.contains("GameOverLaw"))
        #expect(denyLawIDs.contains("GoldBudgetLaw"))
    }

    @Test("Dead character resting in danger captures GameOverLaw and SafeLocationLaw")
    func deadCharacterRestingInDanger() {
        var state = AdventureState()
        state.health = 0
        state.location = "dark cave"

        let policy = StoryLaws.defaultPolicy()
        let trace = policy.evaluate(state: state, action: .rest(healing: 25))

        #expect(trace.composedDecision == .deny)
        let denyLawIDs = Set(trace.verdicts.filter { $0.decision == .deny }.map(\.lawID))
        #expect(denyLawIDs.contains("GameOverLaw"))
        #expect(denyLawIDs.contains("SafeLocationLaw"))
    }

    @Test("All laws allow normal action — composed decision is allow")
    func allLawsAllowNormal() {
        let state = AdventureState() // Alive, safe location, empty inventory
        let policy = StoryLaws.defaultPolicy()

        let trace = policy.evaluate(state: state, action: .findGold(amount: 50))

        #expect(trace.composedDecision == .allow)
        #expect(trace.verdicts.allSatisfy { $0.decision == .allow })
    }

    @Test("Default policy uses denyWins composition rule and ChronicleLaw jurisdiction")
    func defaultPolicyConfiguration() {
        let policy = StoryLaws.defaultPolicy()

        #expect(policy.compositionRule == .denyWins)
        #expect(policy.jurisdictionID == "ChronicleLaw")
        #expect(policy.laws.count == 4, "Should have four StoryLaws")
    }
}

// MARK: - Orchestrator Governance Integration Tests

@Suite("Governance Demo Integration", .serialized)
struct GovernanceDemoIntegrationTests {

    private func makeOrchestrator(
        clock: MockClock = MockClock(fixed: Date(timeIntervalSince1970: 0)),
        uuidGenerator: MockUUIDGenerator = MockUUIDGenerator(sequential: 1),
        governancePolicy: GovernancePolicy<AdventureState, StoryAction>? = StoryLaws.defaultPolicy()
    ) -> AdventureOrchestrator {
        AdventureOrchestrator(
            initialState: AdventureState(),
            clock: clock,
            uuidGenerator: uuidGenerator,
            governancePolicy: governancePolicy
        )
    }

    @Test("Governance denial recorded as .governanceDenied in audit log")
    func governanceDenialInAudit() async {
        let orchestrator = makeOrchestrator()

        // Gold 500 exceeds GoldBudgetLaw limit
        await orchestrator.replay(.findGold(amount: 500))

        let log = await orchestrator.auditLog()
        let lastEntry = log.last!

        if case .governanceDenied(let action, _) = lastEntry.eventType {
            if case .findGold(let amount) = action {
                #expect(amount == 500)
            } else {
                Issue.record("Expected findGold action in governance denied event")
            }
        } else {
            Issue.record("Expected .governanceDenied event type, got \(lastEntry.eventType)")
        }

        #expect(lastEntry.applied == false)
        #expect(lastEntry.governanceTrace != nil,
                "Should have governance trace attached")
    }

    @Test("Governance allows, reducer accepts — normal flow with trace")
    func governanceAllowsReducerAccepts() async {
        let orchestrator = makeOrchestrator()

        await orchestrator.replay(.findGold(amount: 50))

        let log = await orchestrator.auditLog()
        let lastEntry = log.last!

        if case .actionProposed(let action, _) = lastEntry.eventType {
            if case .findGold(let amount) = action {
                #expect(amount == 50)
            } else {
                Issue.record("Expected findGold action")
            }
        } else {
            Issue.record("Expected .actionProposed event type, got \(lastEntry.eventType)")
        }

        #expect(lastEntry.applied == true)
        #expect(lastEntry.governanceTrace != nil,
                "Governance trace should be attached even when allowed")

        let state = await orchestrator.currentState
        #expect(state.gold == 50, "Gold should be added")
    }

    @Test("Multi-rejection scenario captures ALL violation reasons in trace")
    func multiRejectionCapturesAllViolations() async {
        let orchestrator = makeOrchestrator()

        // Kill the character
        await orchestrator.replay(.takeDamage(amount: 100))

        // Dead character tries findGold(500) — violates GameOverLaw AND GoldBudgetLaw
        await orchestrator.replay(.findGold(amount: 500))

        let log = await orchestrator.auditLog()
        let lastEntry = log.last!

        #expect(lastEntry.applied == false)

        guard let trace = lastEntry.governanceTrace else {
            Issue.record("Expected governance trace on denial")
            return
        }

        let denyVerdicts = trace.verdicts.filter { $0.decision == .deny }
        #expect(denyVerdicts.count >= 2,
                "Should have at least GameOverLaw + GoldBudgetLaw denials")

        let denyLawIDs = Set(denyVerdicts.map(\.lawID))
        #expect(denyLawIDs.contains("GameOverLaw"),
                "GameOverLaw should deny (character is dead)")
        #expect(denyLawIDs.contains("GoldBudgetLaw"),
                "GoldBudgetLaw should deny (500 > 100)")
    }

    @Test("Governance denial preserves state — hashes match")
    func governanceDenialPreservesState() async {
        let orchestrator = makeOrchestrator()

        let stateBefore = await orchestrator.currentState
        let hashBefore = stateBefore.stateHash()

        await orchestrator.replay(.findGold(amount: 500))

        let stateAfter = await orchestrator.currentState
        #expect(hashBefore == stateAfter.stateHash(),
                "State should be unchanged after governance denial")
    }

    @Test("Replay with governance events produces deterministic results")
    func replayWithGovernanceDeterministic() async {
        let actions: [StoryAction] = [
            .findGold(amount: 20),              // Allowed, accepted
            .moveTo(location: "dark cave"),      // Allowed, accepted
            .findItem("rusty sword"),            // Allowed, accepted
            .findGold(amount: 500),              // Governance denied (GoldBudgetLaw)
            .rest(healing: 25),                  // Governance denied (SafeLocationLaw)
            .moveTo(location: "sunlit meadow"),  // Allowed, accepted
            .rest(healing: 25)                   // Allowed, accepted
        ]

        // First run
        let orch1 = makeOrchestrator()
        for action in actions {
            await orch1.replay(action)
        }
        let state1 = await orch1.currentState
        let log1 = await orch1.auditLog()

        // Second run — identical
        let orch2 = makeOrchestrator()
        for action in actions {
            await orch2.replay(action)
        }
        let state2 = await orch2.currentState
        let log2 = await orch2.auditLog()

        // States must match
        #expect(state1.stateHash() == state2.stateHash(),
                "Replay should produce identical state hash")
        #expect(state1.location == state2.location)
        #expect(state1.health == state2.health)
        #expect(state1.gold == state2.gold)
        #expect(state1.inventory == state2.inventory)

        // Log lengths must match
        #expect(log1.count == log2.count,
                "Replay should produce identical log length")
    }

    @Test("Narrative log shows governance denial with law details")
    func narrativeLogShowsGovernanceDenials() async {
        let orchestrator = makeOrchestrator()

        // Governance denied action
        await orchestrator.replay(.findGold(amount: 500))

        let narrative = await orchestrator.getNarrativeLog()

        // Should contain governance denial indicator
        let hasGovernanceLine = narrative.contains { $0.contains("Governance") || $0.contains("🛡️") }
        #expect(hasGovernanceLine,
                "Narrative log should mention governance denial")

        // Should mention the law that denied
        let hasLawDetail = narrative.contains { $0.contains("GoldBudgetLaw") }
        #expect(hasLawDetail,
                "Narrative log should show which law denied")
    }

    @Test("No-governance regression — orchestrator without policy behaves as before")
    func noGovernanceRegression() async {
        let orchestrator = makeOrchestrator(governancePolicy: nil)

        // Without governance, valid action goes straight to reducer
        await orchestrator.replay(.findGold(amount: 50))

        let state = await orchestrator.currentState
        #expect(state.gold == 50, "Reducer should accept valid action without governance")

        let log = await orchestrator.auditLog()
        let lastEntry = log.last!

        if case .actionProposed = lastEntry.eventType {
            // Expected
        } else {
            Issue.record("Without governance, should use .actionProposed event type")
        }

        #expect(lastEntry.governanceTrace == nil,
                "Without governance policy, no trace should be attached")
        #expect(lastEntry.applied == true)
    }
}
