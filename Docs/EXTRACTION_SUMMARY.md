# SwiftVectorCore Extraction: Commit 1 Summary

## Overview

This commit establishes SwiftVectorCore as an importable Swift package containing the foundational protocols for deterministic AI control systems.

## Extraction Mapping

| NarrativeDemo | SwiftVectorCore | Notes |
|---------------|-----------------|-------|
| `AdventureState` (struct) | `State` (protocol) | Protocol extracts shape; demo keeps domain fields |
| `AdventureState.hash()` | `State.stateHash()` | Default implementation via Codable + SHA256 |
| `StoryAction` (enum) | `Action` (protocol) | Protocol defines contract; demo keeps cases |
| `StoryReducer.reduce()` | `Reducer.reduce()` | Protocol defines signature; result type is now `ReducerResult<S>` |
| Return tuple | `ReducerResult<S>` | Proper type replaces `(newState, applied, description)` |
| — | `Effect` (protocol) | New; NarrativeDemo doesn't use effects yet |
| `AuditEntry.EventType` | (Commit 3) | Will become generic over Action |

## Protocol Definitions

### State
```swift
public protocol State: Sendable, Equatable, Codable {
    func stateHash() -> String
}
```

Default `stateHash()` uses JSON encoding with sorted keys → SHA256.

### Action
```swift
public protocol Action: Sendable, Equatable, Codable {
    var actionDescription: String { get }
    var correlationID: UUID { get }
}
```

`correlationID` has a default implementation generating ephemeral UUIDs.

### Reducer
```swift
public protocol Reducer<S, A>: Sendable {
    associatedtype S: State
    associatedtype A: Action
    func reduce(state: S, action: A) -> ReducerResult<S>
}
```

`ReducerResult<S>` provides `.accepted()` and `.rejected()` factory methods.

### Effect
```swift
public protocol Effect: Sendable, Equatable {
    associatedtype ResultAction: Action
    func execute() async throws -> ResultAction
}
```

Effects are descriptions of work; execution happens via `EffectRunner`.

## Package Structure

```
SwiftVector/
├── Package.swift
├── Sources/
│   ├── SwiftVectorCore/
│   │   ├── SwiftVectorCore.swift    # Module documentation
│   │   ├── State.swift              # State protocol + default hash
│   │   ├── Action.swift             # Action protocol + ActionProposal
│   │   ├── Reducer.swift            # Reducer protocol + ReducerResult + AnyReducer
│   │   └── Effect.swift             # Effect protocol + EffectRunner + NoEffect
│   └── SwiftVectorTesting/
│       └── SwiftVectorTesting.swift # Placeholder for Commit 2
└── Tests/
    └── SwiftVectorCoreTests/
        └── ProtocolTests.swift      # Contract verification tests
```

## Test Coverage

### State Protocol Tests
- `stateConformance`: Verifies Sendable, Equatable, Codable
- `stateHashDeterminism`: Same state → same hash
- `stateHashSensitivity`: Different state → different hash
- `stateHashFormat`: Valid 64-char lowercase hex

### Action Protocol Tests
- `actionConformance`: Verifies Sendable, Equatable, Codable
- `actionDescription`: Verifies human-readable descriptions
- `actionCorrelationID`: Verifies ID presence
- `actionProposalMetadata`: Verifies ActionProposal captures agent info

### Reducer Protocol Tests
- `reducerAcceptsValid`: Valid actions produce applied=true
- `reducerRejectsInvalid`: Invalid actions produce applied=false, unchanged state
- `reducerDeterminism`: Same inputs → same output
- `reducerResultFactories`: .accepted() and .rejected() work correctly
- `anyReducerTypeErasure`: AnyReducer preserves behavior

### Integration Tests
- `reduceCycleHashes`: State change changes hash; replay matches
- `rejectedActionHashPreservation`: Rejected actions don't change hash
- `actionSequenceDeterminism`: Same action sequence → same final state

## What's Not Extracted Yet

### Commit 2: Determinism Primitives
- `Clock` protocol + `SystemClock` + `MockClock`
- `UUIDGenerator` protocol + `SystemUUIDGenerator` + `MockUUIDGenerator`
- `RandomSource` protocol + `SystemRandomSource` + `MockRandomSource`

### Commit 3: Audit Infrastructure
- `AuditEvent<A: Action>` (generic version of `AuditEntry`)
- `EventLog` (append-only log with hash chain)
- Replay verification helpers

### Commit 4: NarrativeDemo Migration
- `AdventureState` conforms to `State`
- `StoryAction` conforms to `Action`
- `StoryReducer` conforms to `Reducer`
- Import `SwiftVectorCore` instead of local definitions

## Design Decisions

### Why `ReducerResult<S>` instead of tuple?
- **Type safety**: Named fields prevent position errors
- **Extensibility**: Can add fields without breaking callers
- **Factory methods**: `.accepted()` and `.rejected()` are clearer than tuple construction

### Why `correlationID` on Action?
- **Distributed tracing**: Links actions across system boundaries
- **Audit correlation**: Groups related events in logs
- **Default implementation**: Generates ephemeral UUIDs; override for persistence

### Why `Effect` protocol now?
- **Completeness**: The whitepaper defines Effects as part of the architecture
- **Forward compatibility**: ChronicleEngine and Flightworks GCS will need them
- **NoEffect placeholder**: Reducers that don't produce effects have a type to use

### Why separate `SwiftVectorTesting`?
- **Clean dependencies**: Production code doesn't ship test mocks
- **Explicit opt-in**: Consumers import testing utilities only in test targets
- **Matches ecosystem conventions**: XCTest, Swift Testing, Quick all do this

## ChronicleEngine Integration Path

After Commit 4, ChronicleEngine can:

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/.../SwiftVector", from: "0.1.0")
]

// GameState.swift
import SwiftVectorCore

struct GameState: State {
    var scene: Scene
    var characters: [Character]
    var flags: Set<String>
    // ... ChronicleEngine-specific fields
}

// GameAction.swift
enum GameAction: Action {
    case advanceScene(to: SceneID)
    case updateCharacter(id: CharacterID, change: CharacterChange)
    // ... ChronicleEngine-specific cases
    
    var actionDescription: String { /* ... */ }
}

// RulesEngine.swift
struct RulesEngine: Reducer {
    func reduce(state: GameState, action: GameAction) -> ReducerResult<GameState> {
        // Three-tier validation as per ChronicleEngine architecture
    }
}
```

## Next Steps

1. Review protocol definitions
2. Verify test coverage is sufficient
3. Proceed to Commit 2 (determinism primitives)
