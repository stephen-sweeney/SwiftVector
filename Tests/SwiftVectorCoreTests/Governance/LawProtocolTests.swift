//
//  LawProtocolTests.swift
//  SwiftVectorCoreTests
//
//  Copyright © 2026 Flightworks Aerial LLC. All rights reserved.
//

import Testing
import Foundation
import CryptoKit
@testable import SwiftVectorCore

// MARK: - Test Fixtures

/// Minimal State for Law testing
private struct LawTestState: State {
    var health: Int = 100
    var gold: Int = 0
    var location: String = "forest"
}

/// Minimal Action for Law testing
private enum LawTestAction: Action {
    case findGold(Int)
    case rest
    case move(String)

    var actionDescription: String {
        switch self {
        case .findGold(let n): return "Find \(n) gold"
        case .rest: return "Rest"
        case .move(let loc): return "Move to \(loc)"
        }
    }

    var correlationID: UUID {
        switch self {
        case .findGold(let n):
            return stableUUID(for: "findGold-\(n)")
        case .rest:
            return UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        case .move(let loc):
            return stableUUID(for: "move-\(loc)")
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

// MARK: - Concrete Test Laws

/// A Law that always allows.
private struct AlwaysAllowLaw: Law {
    let lawID = "AlwaysAllowLaw"

    func evaluate(state: LawTestState, action: LawTestAction) -> LawVerdict {
        LawVerdict(lawID: lawID, decision: .allow, reason: "No objection")
    }
}

/// A Law that always denies.
private struct AlwaysDenyLaw: Law {
    let lawID = "AlwaysDenyLaw"

    func evaluate(state: LawTestState, action: LawTestAction) -> LawVerdict {
        LawVerdict(lawID: lawID, decision: .deny, reason: "Denied by policy")
    }
}

/// A Law that denies findGold amounts over 100.
private struct GoldBudgetLaw: Law {
    let lawID = "GoldBudgetLaw"

    func evaluate(state: LawTestState, action: LawTestAction) -> LawVerdict {
        if case .findGold(let amount) = action, amount > 100 {
            return LawVerdict(lawID: lawID, decision: .deny, reason: "Gold amount \(amount) exceeds limit of 100")
        }
        return LawVerdict(lawID: lawID, decision: .allow, reason: "Within budget")
    }
}

/// A Law that denies rest when health is already full.
private struct RestLaw: Law {
    let lawID = "RestLaw"

    func evaluate(state: LawTestState, action: LawTestAction) -> LawVerdict {
        if case .rest = action, state.health >= 100 {
            return LawVerdict(lawID: lawID, decision: .deny, reason: "Health already full")
        }
        return LawVerdict(lawID: lawID, decision: .allow, reason: "OK")
    }
}

// MARK: - Law Protocol Tests

@Suite("Law Protocol")
struct LawProtocolTests {

    @Test("Law produces correct verdict for allow case")
    func lawProducesAllowVerdict() {
        let law = AlwaysAllowLaw()
        let state = LawTestState()
        let verdict = law.evaluate(state: state, action: .rest)

        #expect(verdict.lawID == "AlwaysAllowLaw")
        #expect(verdict.decision == .allow)
        #expect(verdict.reason == "No objection")
    }

    @Test("Law produces correct verdict for deny case")
    func lawProducesDenyVerdict() {
        let law = AlwaysDenyLaw()
        let state = LawTestState()
        let verdict = law.evaluate(state: state, action: .rest)

        #expect(verdict.lawID == "AlwaysDenyLaw")
        #expect(verdict.decision == .deny)
    }

    @Test("Conditional law evaluates based on state and action")
    func conditionalLawEvaluates() {
        let law = GoldBudgetLaw()
        let state = LawTestState()

        let allowVerdict = law.evaluate(state: state, action: .findGold(50))
        #expect(allowVerdict.decision == .allow)

        let denyVerdict = law.evaluate(state: state, action: .findGold(500))
        #expect(denyVerdict.decision == .deny)
        #expect(denyVerdict.reason.contains("500"))
    }

    @Test("Law evaluation is deterministic")
    func lawEvaluationIsDeterministic() {
        let law = GoldBudgetLaw()
        let state = LawTestState(health: 50, gold: 10, location: "cave")
        let action = LawTestAction.findGold(200)

        let verdict1 = law.evaluate(state: state, action: action)
        let verdict2 = law.evaluate(state: state, action: action)

        #expect(verdict1 == verdict2, "Same inputs must produce same verdict")
    }
}

// MARK: - AnyLaw Tests

@Suite("AnyLaw")
struct AnyLawTests {

    @Test("AnyLaw wrapping preserves behavior")
    func wrappingPreservesBehavior() {
        let concrete = GoldBudgetLaw()
        let erased = AnyLaw<LawTestState, LawTestAction>(concrete)
        let state = LawTestState()

        let concreteAllow = concrete.evaluate(state: state, action: .findGold(50))
        let erasedAllow = erased.evaluate(state: state, action: .findGold(50))
        #expect(concreteAllow == erasedAllow)

        let concreteDeny = concrete.evaluate(state: state, action: .findGold(500))
        let erasedDeny = erased.evaluate(state: state, action: .findGold(500))
        #expect(concreteDeny == erasedDeny)
    }

    @Test("AnyLaw preserves lawID")
    func wrappingPreservesLawID() {
        let concrete = GoldBudgetLaw()
        let erased = AnyLaw<LawTestState, LawTestAction>(concrete)

        #expect(erased.lawID == "GoldBudgetLaw")
    }

    @Test("AnyLaw closure initializer works")
    func closureInitializerWorks() {
        let law = AnyLaw<LawTestState, LawTestAction>(
            lawID: "InlineLaw"
        ) { _, action in
            if case .rest = action {
                return LawVerdict(lawID: "InlineLaw", decision: .deny, reason: "No resting")
            }
            return LawVerdict(lawID: "InlineLaw", decision: .allow, reason: "OK")
        }

        let state = LawTestState()
        #expect(law.evaluate(state: state, action: .rest).decision == .deny)
        #expect(law.evaluate(state: state, action: .move("town")).decision == .allow)
        #expect(law.lawID == "InlineLaw")
    }

    @Test("AnyLaw is deterministic")
    func anyLawIsDeterministic() {
        let law = AnyLaw<LawTestState, LawTestAction>(GoldBudgetLaw())
        let state = LawTestState()
        let action = LawTestAction.findGold(200)

        let v1 = law.evaluate(state: state, action: action)
        let v2 = law.evaluate(state: state, action: action)

        #expect(v1 == v2)
    }

    @Test("Heterogeneous AnyLaw array works")
    func heterogeneousArray() {
        let laws: [AnyLaw<LawTestState, LawTestAction>] = [
            AnyLaw(AlwaysAllowLaw()),
            AnyLaw(GoldBudgetLaw()),
            AnyLaw(RestLaw()),
        ]

        #expect(laws.count == 3)
        #expect(laws[0].lawID == "AlwaysAllowLaw")
        #expect(laws[1].lawID == "GoldBudgetLaw")
        #expect(laws[2].lawID == "RestLaw")
    }

    @Test("Sendable conformance compiles across actor boundary")
    func sendableConformance() async {
        let law = AnyLaw<LawTestState, LawTestAction>(GoldBudgetLaw())
        let state = LawTestState()

        let verdict = await Task.detached {
            return law.evaluate(state: state, action: .findGold(500))
        }.value

        #expect(verdict.decision == .deny)
    }

    // MARK: - End-to-end with CompositionEngine

    @Test("Multiple laws compose through CompositionEngine")
    func endToEndWithCompositionEngine() {
        let laws: [AnyLaw<LawTestState, LawTestAction>] = [
            AnyLaw(AlwaysAllowLaw()),
            AnyLaw(GoldBudgetLaw()),
        ]
        let state = LawTestState()

        // Action within budget — all allow
        let allowVerdicts = laws.map { $0.evaluate(state: state, action: .findGold(50)) }
        let allowTrace = CompositionEngine.compose(
            verdicts: allowVerdicts,
            rule: .denyWins,
            jurisdictionID: "TestLaw"
        )
        #expect(allowTrace.composedDecision == .allow)
        #expect(allowTrace.verdicts.count == 2)

        // Action over budget — GoldBudgetLaw denies
        let denyVerdicts = laws.map { $0.evaluate(state: state, action: .findGold(500)) }
        let denyTrace = CompositionEngine.compose(
            verdicts: denyVerdicts,
            rule: .denyWins,
            jurisdictionID: "TestLaw"
        )
        #expect(denyTrace.composedDecision == .deny)
        #expect(denyTrace.verdicts[0].decision == .allow, "AlwaysAllowLaw should still allow")
        #expect(denyTrace.verdicts[1].decision == .deny, "GoldBudgetLaw should deny")
    }

    @Test("Multiple violations are all captured")
    func multipleViolationsCaptured() {
        let laws: [AnyLaw<LawTestState, LawTestAction>] = [
            AnyLaw(GoldBudgetLaw()),
            AnyLaw(RestLaw()),
            AnyLaw(AlwaysDenyLaw()),
        ]

        // State with full health, action is rest — RestLaw and AlwaysDenyLaw both deny
        let state = LawTestState(health: 100, gold: 0, location: "forest")
        let verdicts = laws.map { $0.evaluate(state: state, action: .rest) }
        let trace = CompositionEngine.compose(
            verdicts: verdicts,
            rule: .denyWins,
            jurisdictionID: "TestLaw"
        )

        #expect(trace.composedDecision == .deny)

        // Verify ALL denials are captured, not just the first
        let denials = trace.verdicts.filter { $0.decision == .deny }
        #expect(denials.count == 2, "Both RestLaw and AlwaysDenyLaw should deny")
        #expect(denials.contains(where: { $0.lawID == "RestLaw" }))
        #expect(denials.contains(where: { $0.lawID == "AlwaysDenyLaw" }))
    }
}
