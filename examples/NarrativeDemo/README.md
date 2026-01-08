# NarrativeDemo

A minimal iOS application demonstrating the **SwiftVector** pattern for deterministic AI agent control.

## What This Is

NarrativeDemo is a simple text-based adventure game where an AI agent proposes story events and a deterministic reducer validates them. It serves as a reference implementation for the SwiftVector architectural pattern described in the accompanying whitepaper.

**The core insight:** AI can hallucinate, but your system doesn't have to accept it. State, not prompts, is the authority.

## The Pattern

SwiftVector separates AI systems into components with distinct responsibilities:

| Component | Role | Determinism | File |
|-----------|------|-------------|------|
| **State** | Immutable snapshot of world truth | Deterministic | `AdventureState.swift` |
| **Action** | Serializable description of proposed change | Deterministic | `StoryAction.swift` |
| **Agent** | Proposes actions based on current state | Stochastic | `StoryAgent.swift` |
| **Reducer** | Validates and applies actions | Deterministic | `StoryReducer.swift` |
| **Orchestrator** | Coordinates the control loop | Deterministic | `AdventureOrchestrator.swift` |

```
┌─────────────────────────────────────────────────────────────┐
│                    SwiftVector Control Loop                  │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│   State ──────► Agent ──────► Action ──────► Reducer ────┐  │
│     ▲           (LLM)        (proposal)    (validates)   │  │
│     │                                                     │  │
│     └─────────────────── New State ◄─────────────────────┘  │
│                                                              │
│   The Agent can propose anything.                           │
│   The Reducer decides what actually happens.                │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

## Why This Matters

Traditional AI agent architectures give the model too much authority. When an LLM hallucinates:
- Invalid actions corrupt state
- Debugging is non-deterministic
- Compliance is impossible

SwiftVector inverts the control:
- The LLM proposes; the system disposes
- Invalid proposals are rejected with full audit trail
- Same actions always produce same state (deterministic replay)

## Running the Demo

### Requirements
- Xcode 16+ (Xcode 26 for FoundationModels/Apple Intelligence)
- iOS 18+ deployment target (iOS 26 for on-device LLM)
- Swift 6 language mode

### Build and Run
1. Open `NarrativeDemo.xcodeproj` in Xcode
2. Select a simulator or device
3. Build and run (`Cmd+R`)
4. Tap "What happens next?" to advance the story

### Running Tests
1. Ensure you have a test target (`NarrativeDemoTests`)
2. Press `Cmd+U` to run all tests

## Key Features Demonstrated

### 1. Stochastic Agent with Deterministic Control
The `StoryAgent` uses Apple's on-device LLM (when available) to propose narrative events. The `StoryReducer` validates every proposal against world rules.

```swift
// Agent can propose anything—even hallucinated values
.findGold(amount: 5000)  // LLM might suggest this

// Reducer enforces rules
guard amount <= 100 else {
    return (state, false, "Rejected: Amount exceeds world rules.")
}
```

### 2. Visible Rejection
Watch the event log. You'll see both accepted (✅) and rejected (❌) actions:

```
🤖 Agent proposed: find 500 gold
❌ REJECTED: Amount 500 exceeds world rules (max 100).
```

This makes the "stochastic gap" visible—the space between what AI proposes and what the system allows.

### 3. Audit Trail for Compliance
Every action is logged with:
- Timestamp
- Agent ID
- State hash before and after
- Whether applied or rejected
- Human-readable description

```swift
let log = await orchestrator.getAuditLog()
for entry in log {
    print("[\(entry.timestamp)] Applied: \(entry.applied)")
    print("  Hash: \(entry.stateHashAfter)")
}
```

### 4. Deterministic Replay
Because all state transitions go through serialized actions, you can replay any session exactly:

```swift
// Original session produced this log
let originalLog = await orchestrator.getAuditLog()

// Replay on fresh orchestrator
let replay = AdventureOrchestrator()
for entry in originalLog {
    if case .actionProposed(let action, _) = entry.eventType {
        await replay.replayAction(action)
    }
}

// Hashes will match exactly
```

### 5. Graceful Degradation
On devices without Apple Intelligence, the agent falls back to heuristic-based proposals. The architecture remains identical—only the proposal source changes.

## Whitepaper Alignment

This demo implements concepts from the SwiftVector whitepaper:

| Section | Concept | Implementation |
|---------|---------|----------------|
| §2.1 | State as immutable snapshot | `AdventureState` is a `Sendable` struct |
| §2.2 | Actions as serializable intents | `StoryAction` enum with associated values |
| §2.3 | Agent as stochastic proposer | `StoryAgent` uses LLM or random fallback |
| §3.1 | Reducer as pure function | `StoryReducer.reduce()` is deterministic |
| §4.1 | Orchestrator control loop | `AdventureOrchestrator.advanceStory()` |
| §4.4 | Audit trail for replay | `AuditEntry` with state hashing |
| §4.5 | Regulatory compliance | SHA256 hashes enable verification |

## Validation Rules

The reducer enforces these world rules:

| Rule | Validation | Whitepaper Principle |
|------|------------|---------------------|
| Gold limit | `amount <= 100` | Constrain authority, not intelligence |
| No duplicates | `!inventory.contains(item)` | State consistency |
| Safe rest | Location not in danger zones | Domain-specific rules |
| Game over | No actions after death | State-based guards |

## Project Structure

```
NarrativeDemo/
├── App/
│   └── NarrativeDemoApp.swift
├── Core/
│   ├── AdventureState.swift      # State + computed properties
│   ├── StoryAction.swift         # Action enum
│   ├── StoryAgent.swift          # LLM-powered proposer
│   ├── StoryReducer.swift        # Deterministic validator
│   ├── AdventureOrchestrator.swift  # Control loop coordinator
│   └── AuditEntry.swift          # Audit trail structure
├── View/
│   ├── ContentView.swift         # SwiftUI interface
│   └── ViewModel.swift           # UI state management
├── docs/
│   └── AUDIT_ARCHITECTURE.md     # Detailed architecture diagrams
└── README.md
```

## Swift 6 Concurrency

This project uses Swift 6 strict concurrency. Key patterns:

- `actor` for `StoryAgent` and `AdventureOrchestrator` (isolation)
- `Sendable` conformance on `AdventureState`, `StoryAction`, `AuditEntry`
- `nonisolated` on computed properties and pure functions
- `AsyncStream` for reactive state broadcasting

See `LEARNING.md` for notes on Swift 6 actor isolation inference.

## Further Reading

- [SwiftVector Whitepaper](https://agentincommand.ai/whitepaper) — Full architectural specification
- [Agent in Command](https://agentincommand.ai) — Deterministic AI architecture for safety-critical systems
- [Apple FoundationModels](https://developer.apple.com/documentation/FoundationModels) — On-device LLM framework

## Related Projects

- **Chronicle Quest** — Full narrative RPG using SwiftVector (private, coming soon)
- **Flightworks GCS** — Drone ground control system with safety-critical AI (public, coming soon)

## License

MIT

---

*Built by [Stephen Sweeney](https://agentincommand.ai) as a reference implementation of the SwiftVector pattern.*
