# Governance Layer for SwiftVectorCore

## Context

The SwiftVector Codex (v1.2) defines 11 composable Laws as a constitutional framework for governed autonomy. These Laws exist only as specifications in the Codex document — no implementation exists in code. A collaboration with stackmint on ClawLaw surfaced a concrete gap: when a reducer has multiple guard-clause early-returns, only the first rejection is captured. All subsequent violations are invisible to the audit trail.

stackmint wrote `CompositionTrace.swift` which introduces a governance evaluation layer where multiple Laws evaluate an action independently, all verdicts are collected, and a composition rule produces the final decision with a complete trace. This is the right idea, but it needs determinism fixes and architectural integration before inclusion in SwiftVectorCore.

This plan adds the governance layer as a first-class concept in SwiftVectorCore (the Swift Enforcement Kernel). It sits between Agent proposals and Reducer application. The goal is to establish the vocabulary and machinery so that Domain Laws (ClawLaw, FlightLaw, ChronicleLaw) can compose concrete Laws against this framework. The NarrativeDemo is updated to demonstrate governance in action.

### Design Decisions

- **Governance is a pre-filter on the reducer.** If governance denies, the reducer never runs. If governance allows, the reducer still has final say on domain-specific validation.
- **Governance is opt-in.** `BaseOrchestrator` gains an optional `GovernancePolicy`. When nil, behavior is identical to today. No breaking changes.
- **No `Date.now` defaults.** All timestamps come from injected `Clock`. stackmint's `EvaluationContext` and `decidedAt` defaults are removed.
- **No `custom(name:)` composition rule.** Removed to avoid silent fallback behavior. Domain Laws can define custom rules in their own modules.
- **Escalate = deny (for now).** The `.escalate` decision is captured in the trace but treated as denial. An approval queue is future work.
- **CompositionTrace attaches to AuditEvent**, not to ReducerResult. The reducer stays simple; governance reasoning is audit metadata.

### Methodology: Test-Driven Development

Every ticket follows TDD. The workflow for each commit:
1. **Write tests first** — define expected behavior as failing tests
2. **Implement minimum code** to make tests pass
3. **Verify** — `swift build` + `swift test` green, determinism scans clean
4. **Commit** — tests and implementation together

Tests use Swift Testing framework (`@Suite`, `#expect`) matching the existing test patterns in `Tests/SwiftVectorCoreTests/`. Mocks use `SwiftVectorTesting` (MockClock, MockUUIDGenerator).

### Control Loop (before and after)

```
BEFORE:  Agent -> Action -> Reducer -> ReducerResult -> AuditEvent
AFTER:   Agent -> Action -> Laws evaluate -> CompositionTrace
                                              |
                              deny/escalate?  |  allow?
                                    |         |
                            AuditEvent    Reducer -> ReducerResult -> AuditEvent
                          (.governanceDenied)                    (with trace attached)
```

---

## Tickets

### SV-GOV-1: Governance Verdict Types

**Files to create:**
- `Tests/SwiftVectorCoreTests/Governance/GovernanceTypeTests.swift` (write first)
- `Sources/SwiftVectorCore/Governance/LawDecision.swift`
- `Sources/SwiftVectorCore/Governance/LawVerdict.swift`

**What:** Add `LawDecision` enum (allow/deny/escalate/abstain) and `LawVerdict` struct (lawID, decision, reason). Pure value types, no behavior. All conform to Sendable, Equatable, Codable.

Compared to stackmint's version: removes `EvaluationContext` (had `Date.now` violation). Context info lives on `AuditEvent`, not per-verdict.

**TDD sequence:**
1. Write tests: LawDecision has all four cases, Codable round-trip, Equatable
2. Write tests: LawVerdict stores properties, Codable round-trip, Equatable
3. Implement `LawDecision` — tests pass
4. Implement `LawVerdict` — tests pass

```
feat(core): add governance verdict and decision types for Law evaluation
```

---

### SV-GOV-2: Composition Engine

**Files to create:**
- `Tests/SwiftVectorCoreTests/Governance/CompositionEngineTests.swift` (write first)
- `Sources/SwiftVectorCore/Governance/CompositionRule.swift`
- `Sources/SwiftVectorCore/Governance/CompositionTrace.swift`
- `Sources/SwiftVectorCore/Governance/CompositionEngine.swift`

**What:** Add `CompositionRule` enum (denyWins, unanimousAllow, majorityAllow — all String-backed, no custom case). Add `CompositionTrace` struct (verdicts, rule, composedDecision, jurisdictionID, correlationID — no `decidedAt` timestamp). Add `CompositionEngine` with static `compose()` pure function.

**Key difference from stackmint:** No `Date` fields anywhere. No `custom(name:)`. Full Equatable/Codable. `CompositionTrace` has no timestamp — it gets one from the `AuditEvent` that wraps it.

**TDD sequence:**
1. Write tests: denyWins logic — deny overrides allow, escalate without deny, abstain ignored, empty verdicts = allow
2. Write tests: unanimousAllow, majorityAllow rules
3. Write tests: CompositionTrace Codable round-trip, Equatable
4. Write tests: determinism — same inputs produce same trace
5. Implement types and engine — all tests pass

```
feat(core): add governance composition engine with pure verdict composition
```

---

### SV-GOV-3: Law Protocol and AnyLaw

**Files to create:**
- `Tests/SwiftVectorCoreTests/Governance/LawProtocolTests.swift` (write first)
- `Sources/SwiftVectorCore/Governance/Law.swift`

**What:** Add `Law` protocol (generic over `<S: State, A: Action>`, with `lawID: String` and `evaluate(state:action:) -> LawVerdict`). Add `AnyLaw` type-erased wrapper following the exact pattern of `AnyReducer` in `Reducer.swift:168-189`.

**TDD sequence:**
1. Write tests: mock laws (always allow, always deny, conditional evaluation)
2. Write tests: AnyLaw wrapping preserves behavior and lawID
3. Write tests: AnyLaw closure initializer works
4. Write tests: determinism — same state+action = same verdict
5. Write tests: end-to-end — multiple laws -> compose via CompositionEngine -> correct trace
6. Implement Law protocol and AnyLaw — all tests pass

```
feat(core): add Law protocol and AnyLaw type-erased wrapper
```

---

### SV-GOV-4: Audit Trail Integration

**Files to modify:**
- `Sources/SwiftVectorCore/Audit/AuditEventType.swift` — add `.governanceDenied(A, agentID: String)` case
- `Sources/SwiftVectorCore/Audit/AuditEvent.swift` — add `governanceTrace: CompositionTrace?` field, new factory methods
- `Sources/SwiftVectorCore/Audit/EventLog.swift` — add `governanceDeniedActions()` query, handle in `verifyReplay`

**New test file:**
- `Tests/SwiftVectorCoreTests/Governance/GovernanceAuditTests.swift` (write first)

**What:** Extend the audit system so governance decisions are recorded. New `governanceDenied` event type distinguishes "governance blocked before reducer" from "reducer rejected." Optional `governanceTrace` on `AuditEvent` (nil default = backward compatible). Add `governanceDenied()` and `acceptedWithGovernance()` factory methods. All Codable extensions updated.

**Backward compatibility:** All new fields have nil defaults. Existing serialized logs decode identically. Existing tests must continue to pass.

**Risk:** This modifies existing types. Mitigation: all additions are optional/additive. `HashableContent` includes the trace (nil encodes as JSON null for hash stability).

**TDD sequence:**
1. Write tests: existing audit tests still pass (regression baseline — run first, should be green)
2. Write tests: AuditEvent with governanceTrace stores and retrieves correctly
3. Write tests: AuditEvent without governanceTrace (nil) still works identically
4. Write tests: `.governanceDenied` event type Codable round-trip
5. Write tests: EventLog.governanceDeniedActions() returns correct entries
6. Write tests: chain verification with governance events mixed in
7. Write tests: verifyReplay handles governanceDenied (state unchanged)
8. Write tests: entry hash changes when trace present vs absent (tamper detection)
9. Implement changes — all tests pass (new + existing)

```
feat(core): integrate governance trace into audit trail
```

---

### SV-GOV-5: Orchestrator Integration

**Files to create:**
- `Sources/SwiftVectorCore/Governance/GovernancePolicy.swift`
- `Sources/SwiftVectorTesting/Governance/MockLaw.swift`
- `Tests/SwiftVectorCoreTests/Governance/GovernanceIntegrationTests.swift` (write first)

**Files to modify:**
- `Sources/SwiftVectorCore/BaseOrchestrator.swift` — add optional `GovernancePolicy` param, governance evaluation in `apply()`

**What:** `GovernancePolicy<S, A>` holds `[AnyLaw<S, A>]`, a `CompositionRule`, and `jurisdictionID`. Its `evaluate(state:action:)` is a pure function. `BaseOrchestrator.init` gains optional `governancePolicy` (nil default). `apply()` evaluates governance before reducer — if denied/escalated, short-circuits with `.governanceDenied` audit event and returns `ReducerResult.rejected`. If allowed, proceeds to reducer as today.

**TDD sequence:**
1. Write MockLaw in SwiftVectorTesting (test infrastructure)
2. Write tests: no-policy regression — BaseOrchestrator without policy behaves identically to current
3. Write tests: all-allow policy — reducer still runs, trace recorded in audit
4. Write tests: deny policy — reducer never runs, state unchanged, `.governanceDenied` in audit
5. Write tests: escalate = denied, `.governanceDenied` in audit
6. Write tests: multiple laws with denyWins — one deny overrides allows
7. Write tests: governance allows + reducer rejects — both recorded
8. Write tests: governance allows + reducer accepts — trace attached
9. Write tests: hash chain integrity after governance events
10. Write tests: replay verification works with governance events
11. Write tests: determinism — same state + action + laws = same trace
12. Implement GovernancePolicy and BaseOrchestrator changes — all tests pass

```
feat(core): integrate governance evaluation into BaseOrchestrator control loop
```

---

### SV-GOV-6: NarrativeDemo Governance Update

**Files to create:**
- `examples/NarrativeDemo/NarrativeDemo/Core/StoryLaws.swift` — concrete Law implementations
- `examples/NarrativeDemo/NarrativeDemoTests/GovernanceDemoTests.swift` (write first)

**Files to modify:**
- `examples/NarrativeDemo/NarrativeDemo/Core/AdventureOrchestrator.swift` — pass GovernancePolicy to BaseOrchestrator
- `examples/NarrativeDemo/NarrativeDemo/Core/StoryReducer.swift` — simplify: remove guards that are now Laws
- `examples/NarrativeDemo/NarrativeDemo/View/ViewModel.swift` — surface governance traces in narrative log
- `examples/NarrativeDemo/NarrativeDemo/View/ContentView.swift` — display governance denial details in UI

**What:** Demonstrate the governance layer in the existing NarrativeDemo. Extract cross-cutting validation rules from `StoryReducer` into composable Laws, showing the "before/after" of the multi-rejection problem.

**StoryLaws to implement (ChronicleLaw-style governance):**
- `GameOverLaw` — denies all actions when `state.isGameOver` (was a guard in reducer)
- `GoldBudgetLaw` — denies `findGold` amounts > 100 (was a guard in reducer)
- `SafeLocationLaw` — denies `rest` in dangerous locations (was a guard in reducer)
- `InventoryLaw` — denies duplicate `findItem` (was a guard in reducer)

This directly demonstrates the motivating problem: if the character is dead AND tries to find 500 gold in a dangerous location with a duplicate item, ALL four violations are recorded in the CompositionTrace, not just "game over."

**StoryReducer changes:** Remove the guard clauses that are now Laws. The reducer keeps only the state mutation logic (moveTo changes location, findGold adds gold, etc.). This makes the reducer simpler and the validation more visible.

**UI changes:** `getNarrativeLog()` updated to show governance verdicts when a denial has multiple reasons. The narrative log shows something like:
- "Governance denied: GameOverLaw (character is dead), GoldBudgetLaw (500 exceeds limit of 100)"

**TDD sequence:**
1. Write tests: each StoryLaw evaluates correctly in isolation
2. Write tests: multiple laws compose — dead character + excessive gold = deny with two verdicts
3. Write tests: orchestrator with StoryLaws — governance denial recorded in audit
4. Write tests: governance allows, reducer accepts — normal flow still works
5. Write tests: replay with governance events produces same final state
6. Implement StoryLaws
7. Wire GovernancePolicy into AdventureOrchestrator
8. Simplify StoryReducer (remove moved guards)
9. Update ViewModel/ContentView for governance display
10. Verify: existing NarrativeDemo tests pass + new governance tests pass

```
feat(demo): add ChronicleLaw governance to NarrativeDemo with composable StoryLaws
```

---

## Critical Files Reference

| File | Role |
|------|------|
| `Sources/SwiftVectorCore/Reducer.swift:168-189` | Pattern reference for `AnyLaw` (mirrors `AnyReducer`) |
| `Sources/SwiftVectorCore/BaseOrchestrator.swift:75-107` | `apply()` method where governance inserts |
| `Sources/SwiftVectorCore/Audit/AuditEvent.swift` | Extended with `governanceTrace` field |
| `Sources/SwiftVectorCore/Audit/AuditEventType.swift` | Extended with `.governanceDenied` case |
| `Sources/SwiftVectorCore/Audit/EventLog.swift` | Extended with governance query methods |
| `Tests/SwiftVectorCoreTests/Orchestrator/BaseOrchestratorTests.swift` | Regression baseline and test patterns |
| `Tests/SwiftVectorCoreTests/Protocols/ProtocolTests.swift` | TestState/TestAction/TestReducer fixtures |
| `examples/NarrativeDemo/NarrativeDemo/Core/StoryReducer.swift` | Guards to extract into Laws |
| `examples/NarrativeDemo/NarrativeDemo/Core/AdventureOrchestrator.swift` | Wires GovernancePolicy |
| `examples/NarrativeDemo/NarrativeDemoTests/AdventureOrchestratorTests.swift` | Demo regression tests |

## Verification

After each commit:
1. `swift build` passes
2. `swift test` passes (all existing + new tests)
3. No `Date()` or `UUID()` direct calls: `grep -rn "Date()" --include="*.swift" Sources/ | grep -v "// deterministic:"` returns only `SystemClock.now()`
4. No forbidden imports: `grep -rn "^import " Sources/SwiftVectorCore/ | grep -Ev "(Foundation|os|CryptoKit)"` returns nothing

After SV-GOV-5:
5. NarrativeDemo builds: `cd examples/NarrativeDemo && xcodebuild -project NarrativeDemo.xcodeproj -scheme NarrativeDemo -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 15' build`

After SV-GOV-6:
6. NarrativeDemo tests pass: `cd examples/NarrativeDemo && xcodebuild -project NarrativeDemo.xcodeproj -scheme NarrativeDemo -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 15' test`
7. Demo runs and shows governance verdicts in narrative log
8. Multi-rejection scenario verifiable: trigger action that violates multiple Laws, confirm all reasons appear in trace

## Deferred (Not in Scope)

- Escalation approval queue (Authority Law implementation)
- Full governance replay (re-evaluating Laws during `verifyReplay`)
- Orchestrator protocol changes (governance is a `BaseOrchestrator` implementation detail)
- Concrete framework-level Law implementations (BoundaryLaw, ResourceLaw, etc. — these belong in Domain Laws, not Core)
- `ReducerResult` changes (trace stays on AuditEvent, not on ReducerResult)
