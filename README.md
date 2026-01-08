# SwiftVector

Deterministic control of probabilistic agents — an architecture for building **reproducible, auditable, safety-minded** AI systems.

**Core principle:** *State, not prompts, must be the authority.*

> SwiftVector is a control loop: agents propose, a deterministic reducer decides, state is the source of truth, audits enable replay.

---

## If You're Evaluating This Repository

**5 minutes to understand the pattern:**

1. **Read the core loop** (below) — this is the entire idea
2. **Skim the Whitepaper** — formal specification and rationale  
   → [`whitepaper/SwiftVector-Whitepaper.md`](./whitepaper/SwiftVector-Whitepaper.md)
3. **Run the demo** — see the pattern in action  
   → [`examples/NarrativeDemo`](./examples/NarrativeDemo) *(Xcode project)*

The point isn't clever prompts. The point is **governance + reproducibility**: you can explain what happened, reproduce it, and prove what was allowed or denied.

---

## The Problem SwiftVector Solves

Most multi-agent systems fail the same way:

- Prompts become the source of truth
- Memory becomes an append-only text log
- Agents mutate state implicitly
- Failures cannot be replayed or explained

This creates what SwiftVector calls the **Stochastic Gap** — the divergence between user intent and model output. Frameworks like LangChain attempt to manage this gap through increasingly complex prompt engineering. That approach scales poorly.

SwiftVector takes a different position: **constrain authority, not intelligence.**

Agents remain free to reason, explore, and generate ideas. They are never allowed to redefine truth. Truth lives in state, not in language.

---

## Architecture

```
┌─────────────────┐
│  Agent (LLM/AI) │
└────────┬────────┘
         │ propose
         ▼
┌─────────────────┐
│ Reducer / Policy│  ◄── deterministic gatekeeper
│   (pure func)   │
└────────┬────────┘
         │ accept / reject
         ▼
┌─────────────────┐      ┌─────────────────┐
│   State Store   │─────►│   Audit Log     │
│ (source of truth)│      │  (replayable)   │
└─────────────────┘      └─────────────────┘
```

**The Deterministic Control Loop:**

```
State → Agent → Action → Reducer → New State
```

- **State** is the single source of truth
- **Agents** reason about state and propose Actions
- **Reducers** validate and apply state transitions (deterministic, pure functions)
- **Effects** perform I/O after transitions, never during

The reducer is the gatekeeper. You can change models, prompts, and agent strategies without changing the rules of state.

---

## What's in This Repository

### Core Documentation

| Document | Description |
|----------|-------------|
| [**SwiftVector Whitepaper**](./whitepaper/SwiftVector-Whitepaper.md) | Formal specification, design rationale, and implementation guidance |

### Manifestos (Vision Documents)

| Document | Description |
|----------|-------------|
| [**Swift at the Edge**](./manifestos/Swift-at-the-Edge.md) | Why Swift is the natural foundation for edge-deployed AI systems |
| [**The Agency Paradox**](./manifestos/Agency-Paradox.md) | Human command and governance in AI-driven development |

### Reference Implementation

| Project | Description |
|---------|-------------|
| [**NarrativeDemo**](./examples/NarrativeDemo) | Xcode project demonstrating the full pattern: agent proposals, reducer validation, state transitions, and audit replay |

> **Why a narrative demo?** Long-running narrative systems expose every failure mode of agent architectures — state drift, hallucinated facts, non-replayable failures. If the pattern works here, it works anywhere.

---

## Related Projects

### Flightworks GCS (Open Source, In Development)

Ground Control Station applying SwiftVector to operator-in-the-loop drone workflows: decision support, safety gates, and replayable audits.

- Repository: *(coming Q2 2026)*

### Chronicle Quest (Commercial, Private)

A narrative system built on SwiftVector. Public materials focus on architecture patterns and non-proprietary examples, not the proprietary implementation.

---

## Design Constraints

SwiftVector is designed to be:

- **Deterministic at decision points** — reducers and policies are pure functions
- **Model-agnostic** — works with any LLM, local or cloud
- **Auditable by construction** — every state change is logged and replayable
- **Edge-ready** — optimized for on-device deployment with Swift

SwiftVector is **not**:

- A promise of "perfect AI"
- A flight-certified autopilot
- A replacement for formal safety certification processes

The pattern enables certification. It does not replace it.

---

## Why Swift?

SwiftVector's architectural principles apply to any language. The *guarantees* depend on the implementation.

| Context | Any Language | Swift Required |
|---------|--------------|----------------|
| Research & prototyping | ✓ | |
| Production cloud systems | ✓ | |
| **Edge deployment** | | ✓ Performance matters |
| **Safety-critical systems** | | ✓ Certification required |
| **Regulated industries** | | ✓ Compile-time proof required |

Swift provides:

- **Compile-time type safety** — no runtime type errors
- **Actor isolation** — compiler-enforced concurrency safety
- **Deterministic memory** — no GC pauses, stable iteration order
- **Reproducible execution** — same binary, same inputs → identical outputs

For systems where correctness is a *preference*, use whatever language your team knows. For systems where correctness is a *requirement*, Swift's compile-time guarantees are the foundation that makes certification achievable.

---

## Roadmap

**Current Focus**
- Public reference implementation (NarrativeDemo)
- Documentation and examples

**Near Term**
- Stable replay format with schema versioning
- Additional policy module examples (geofencing, risk scoring)
- CI pipeline and test coverage

**Future**
- Replay viewer / inspector tooling
- Distributed SwiftVector patterns
- Community contributions welcome once examples stabilize

---

## Contributing

Questions, suggestions, or discussion about applications? Open an issue.

Pull requests welcome for documentation improvements or bug fixes.

---

## License

- **Code:** MIT
- **Documentation:** CC BY 4.0

---

## Author

**Stephen Sweeney**

- Website: [agentincommand.ai](https://agentincommand.ai)
- GitHub: [github.com/stephen-sweeney](https://github.com/stephen-sweeney)
- LinkedIn: [linkedin.com/in/macsweeney](https://linkedin.com/in/macsweeney)
- Email: stephen@agentincommand.ai
