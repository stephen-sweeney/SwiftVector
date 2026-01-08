# Audit Trail Architecture

## Before This Commit

```
┌─────────────────────────────────────────┐
│     AdventureOrchestrator (actor)       │
├─────────────────────────────────────────┤
│ - state: AdventureState                 │
│ - agent: StoryAgent                     │
│ - stream: AsyncStream<AdventureState>   │
├─────────────────────────────────────────┤
│ + advanceStory()                        │
│   ┌──────────────────────────────────┐  │
│   │ 1. agent.propose(state)          │  │
│   │ 2. StoryReducer.reduce()         │  │
│   │ 3. state = newState              │  │
│   │ 4. continuation.yield(state)     │  │
│   └──────────────────────────────────┘  │
└─────────────────────────────────────────┘
```

## After This Commit

```
┌─────────────────────────────────────────┐
│     AdventureOrchestrator (actor)       │
├─────────────────────────────────────────┤
│ - state: AdventureState                 │
│ - agent: StoryAgent                     │
│ - agentID: String                    ✨ │
│ - auditLog: [AuditEntry]             ✨ │
│ - stream: AsyncStream<AdventureState>   │
├─────────────────────────────────────────┤
│ + init()                                │
│   ┌──────────────────────────────────┐  │
│   │ Log initialization event      ✨ │  │
│   └──────────────────────────────────┘  │
│                                         │
│ + advanceStory()                        │
│   ┌──────────────────────────────────┐  │
│   │ 1. hashBefore = state.hash()  ✨ │  │
│   │ 2. agent.propose(state)          │  │
│   │ 3. StoryReducer.reduce()         │  │
│   │ 4. state = newState              │  │
│   │ 5. hashAfter = state.hash()   ✨ │  │
│   │ 6. auditLog.append(entry)     ✨ │  │
│   │ 7. continuation.yield(state)     │  │
│   └──────────────────────────────────┘  │
│                                         │
│ + replayAction(_ action)             ✨ │
│ + getAuditLog()                      ✨ │
│ + getCurrentState()                  ✨ │
└─────────────────────────────────────────┘
```

## New Data Structures

```swift
struct AuditEntry: Sendable, Identifiable {
    let id: UUID
    let timestamp: Date
    let eventType: EventType
    let stateHashBefore: String    // SHA256
    let stateHashAfter: String     // SHA256
    let applied: Bool              // Did reducer accept?
    let resultDescription: String  // Human-readable result
    
    enum EventType: Sendable, Equatable {
        case initialization
        case actionProposed(StoryAction, agentID: String)
    }
}
```

## Data Flow with Audit Trail

```
User Action
    ↓
┌───────────────────────────────────────────────┐
│ ViewModel.nextEvent()                         │
└───────────────────────────────────────────────┘
    ↓
┌───────────────────────────────────────────────┐
│ Orchestrator.advanceStory()                   │
│                                               │
│  State (Before)                               │
│      ↓                                        │
│  🔐 Hash State          ← Audit Point 1      │
│      ↓                                        │
│  Agent.propose()        ← Stochastic          │
│      ↓                                        │
│  Reducer.reduce()       ← Deterministic       │
│      ↓                                        │
│  State (After)                                │
│      ↓                                        │
│  🔐 Hash State          ← Audit Point 2      │
│      ↓                                        │
│  📝 AuditEntry {                              │
│      timestamp                                │
│      action                                   │
│      agentID                                  │
│      hashBefore                               │
│      hashAfter                                │
│      applied: true/false                      │
│      description                              │
│  }                                            │
│      ↓                                        │
│  auditLog.append(entry) ← Audit Point 3      │
└───────────────────────────────────────────────┘
    ↓
AsyncStream broadcasts new state
    ↓
ViewModel updates @Published state
    ↓
SwiftUI re-renders
```

## Deterministic Replay Flow

```
Original Session                 Replay Session
─────────────────               ──────────────

Init State                      Init State
   ↓                              ↓
Action 1: findGold(20)          Action 1: findGold(20)
   ↓                              ↓
Hash: abc123...                 Hash: abc123...  ✅ Match!
   ↓                              ↓
Action 2: moveTo("cave")        Action 2: moveTo("cave")
   ↓                              ↓
Hash: def456...                 Hash: def456...  ✅ Match!
   ↓                              ↓
Action 3: findGold(500)         Action 3: findGold(500)
   ↓                              ↓
❌ Rejected                      ❌ Rejected
Hash: def456... (unchanged)     Hash: def456...  ✅ Match!

Audit proves: Same actions → Same state
```

## Testing Architecture

```
AdventureOrchestratorTests.swift
├─ Test: auditLogCapturesInitialState
│  └─ Verifies: First entry is .initialization
│
├─ Test: auditLogRecordsProposedAction  
│  └─ Verifies: Actions are logged with timestamp
│
├─ Test: auditLogDistinguishesAcceptedVsRejected
│  └─ Verifies: applied flag correctly set
│
├─ Test: auditLogCapturesStateHash
│  └─ Verifies: SHA256 hash is 64 characters
│
├─ Test: auditLogEnablesDeterministicReplay
│  └─ Verifies: Replay produces identical hashes
│
└─ Test: auditEntriesAreImmutableAndSendable
   └─ Verifies: Compile-time safety guarantees
```

## Key Insights

1. **No change to control loop logic** - audit is observational
2. **Minimal performance impact** - single hash per action
3. **Type-safe by design** - Sendable + Equatable enforced by compiler
4. **Replay is a first-class operation** - replayAction() bypasses agent
5. **Tests verify the contract** - not just implementation details

## Whitepaper Mapping

| Whitepaper Requirement | Implementation |
|------------------------|----------------|
| "Every change is attributable" | `agentID` + `timestamp` |
| "Systems can be replayed exactly" | `replayAction()` + state hashing |
| "Failures can be debugged" | `applied` + `resultDescription` |
| "Auditable" | Complete `auditLog` |
| "Deterministic control" | Reducer validation still enforced |

