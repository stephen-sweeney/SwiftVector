# CLAUDE.md: Source of Truth for Multi-Agent Workflows in SwiftVector

**Version:** 1.2 (Updated Jan 26, 2026)

This file defines the repo structure, invariants, commands, and definitions of done for AI-assisted development. All subagents must reference this to ensure deterministic, auditable changes. Align with SwiftVector whitepaper (SwiftVector-Whitepaper.md) and goals: deterministic control over stochastic agents for edge AI (iOS/Apple Silicon), certification alignment (e.g., DO-178C), and reusability (e.g., Flightworks GCS, ChronicleQuest).

## Current Module Map
- **SwiftVectorCore**: Core library
  - Key sources:
    - `Sources/SwiftVectorCore/State.swift`
    - `Sources/SwiftVectorCore/Action.swift`
    - `Sources/SwiftVectorCore/Reducer.swift`
    - `Sources/SwiftVectorCore/Effect.swift`
    - `Sources/SwiftVectorCore/Audit/AuditEvent.swift`
    - `Sources/SwiftVectorCore/Audit/EventLog.swift` (hash chain, verify, verifyReplay)
    - Determinism DI:
      - `Sources/SwiftVectorCore/Determinism/Clock/`
      - `Sources/SwiftVectorCore/Determinism/UUIDGenerator/`
      - `Sources/SwiftVectorCore/Determinism/RandomSource/`
- **NarrativeDemo**: Xcode app at `examples/NarrativeDemo`
  - Imports SwiftVectorCore
  - Key files: `StoryAgent.swift` (proposes actions), orchestrator loop logic, `StoryState`/`Action` types
- **SwiftVectorTesting** (Phase 2 target): new module for mocks (MockClock/UUID/Random, Mock/ScriptedAgent) + helpers (EventLog verification)
- Other: Whitepaper in repo docs; GitHub repo: https://github.com/stephen-sweeney/SwiftVector

## Build/Test Commands (Expect Green)
- Toolchain target: **Swift 6 / Xcode 16.x**
- Commands assume **repo root** unless noted.

### SwiftPM (Core)
```bash
swift build
swift test
```
Agent Verification Policy
	•	Agents may simulate likely build/test outcomes for planning when local execution is unavailable.
	•	Agents must not claim “tests passing / build green” without real command output from:
	•	swift test and/or the golden xcodebuild ... test commands.

NarrativeDemo (Xcode)

Authoritative project file: examples/NarrativeDemo/NarrativeDemo.xcodeproj
Known schemes (from xcodebuild -list): NarrativeDemo, SwiftVectorCore, SwiftVectorTesting

List schemes (authoritative)

```bash
cd examples/NarrativeDemo
xcodebuild -list -project NarrativeDemo.xcodeproj
```

Build NarrativeDemo (simulator)

```bash
cd examples/NarrativeDemo
xcodebuild -project NarrativeDemo.xcodeproj \
  -scheme NarrativeDemo \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  build
```

Test NarrativeDemo (includes NarrativeDemoTests)

```bash
cd examples/NarrativeDemo
xcodebuild -project NarrativeDemo.xcodeproj \
  -scheme NarrativeDemo \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  test
```

Test SwiftVectorCore (via Xcode scheme)

```bash
cd examples/NarrativeDemo
xcodebuild -project NarrativeDemo.xcodeproj \
  -scheme SwiftVectorCore \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  test
```

Test SwiftVectorTesting (via Xcode scheme)

```bash
cd examples/NarrativeDemo
xcodebuild -project NarrativeDemo.xcodeproj \
  -scheme SwiftVectorTesting \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  test
```

If “iPhone 15” isn’t installed, use any available simulator:
xcrun simctl list devices available | head

Invariants (Enforce in All Changes)

- Determinism/Replayability
- Reducers are pure (no side effects).
- Actions are serializable and include correlationID.
- No direct Date(), UUID(), or SystemRandomNumberGenerator in Core logic; use Clock / UUIDGenerator / RandomSource.
- Agent-Reducer Separation: Agents propose only (no mutations); reducers authorize (validate invariants like state machine guards).
- Audit Chain: Every transition logs AuditEvent; hash chains enable tamper-evident replay.
- Proposal ordering determinism: If proposals are gathered concurrently, ordering must be made deterministic (e.g., stable order by agent.id then correlationID) before reducing/logging.
- Edge Optimization: Value types for State; actors for isolation (recommended but not enforced in protocols for test flexibility).
- Certification Alignment: Compile-time safety (no runtime variability); type-erasure (e.g., AnyReducer) permitted where needed for heterogeneous use without breaking audits.
- API Stability
- Minimal public additions; match existing demo call sites; generics for State/Action.
- New protocols must be public only if used by NarrativeDemo or required by the whitepaper contract.
- Default implementations go in public extension only when they don’t introduce determinism/audit ambiguity.
- Prefer “protocol + small structs” over new class hierarchies.
- Doc Sync
- If a commit changes public API, behavior, or Phase 2 protocols, include doc diffs (README + SwiftVector-Whitepaper.md) in the same commit.
- Doc Updater agent should provide a patch/diff (not just prose).

Non-negotiables
- No breaking changes to public APIs unless explicitly requested.
- No new dependencies without approval.
- No changes to audit hashing semantics without adding replay/verify tests.

Allowed refactors
- Move types into SwiftVectorCore with no behavior change.
- Rename internal symbols only if tests updated and NarrativeDemo still builds.

Multi-Agent Procedure
- One worktree/branch per checklist item (Commit 1/2/3).
- Commit discipline:
- One commit per checklist item.
- Each commit includes tests and doc updates only if impacted.
- Review gate: no merge unless relevant tests are green (swift test and/or appropriate xcodebuild ... test).

Definition of Done for Phase 2 (Extraction to SwiftVectorCore)

Commit 1: Extract Agent protocol
- NarrativeDemo compiles with the extracted protocol.
- One unit test proving a mock/scripted agent can propose deterministically.
- Docs: if public API/behavior changed, README + whitepaper updated in this commit (diff included).

Commit 2: Extract Orchestrator protocol
- Demo uses protocol or DefaultOrchestrator with same behavior.
- One test for orchestrator-step determinism (same inputs → same proposals order/result).
- Docs: if public API/behavior changed, README + whitepaper updated in this commit (diff included).

Commit 3: Add SwiftVectorTesting target
- MockClock/UUID/Random exist and are used by at least one test.
- EventLog verify() + verifyReplay() exercised in tests.
- Docs: if public API/behavior changed, README + whitepaper updated in this commit (diff included).

Overall
- examples/NarrativeDemo refactored to use extractions.
- All tests green.
- Whitepaper/README updated where applicable.
- No new architecture unless demo/whitepaper requires it (e.g., type-erasure if heterogeneous agents).

Risk List (Mitigate in Plans)
- Context rot: keep subagent tasks narrow and scoped.
- Hallucinations: never claim green without real command output; run swift test and/or golden xcodebuild ... test.
- Regressions: run hooks/checks after edits; watch actor/Sendable issues.
- Over-invention: stick to whitepaper/demo; default to minimalism.
- Xcode/Swift toolchain drift: local environment differs from Swift 6 / Xcode 16.x assumptions.
- Mitigation: record xcodebuild -version in PR/issue notes; pin expectations in prompts; optionally add .swift-version (and/or .tool-versions) to signal intended toolchain.

This enables repeatable multi-agent sprints: inject into prompts for Planner/Architect/Implementer/Reviewer/Doc Updater.

If you don’t want to replace the whole file, the *minimum* must-fix lines are:
1) change the “Authoritative project file” line to `examples/NarrativeDemo/NarrativeDemo.xcodeproj`, and  
2) nest “Mitigation” under the toolchain drift risk (it’s currently a top-level bullet).