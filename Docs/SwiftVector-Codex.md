# The SwiftVector Codex

**A Constitutional Framework for Governed Autonomy**

**Version:** 1.0  
**Date:** February 2026  
**Author:** Stephen Sweeney  
**Status:** Published

---

## Preamble

We do not build prisons out of water.

Every autonomous agent operates across a **Stochastic Gap**—the distance between human intent and probabilistic completion. Large language models reason in probability distributions. They generate plausible outputs, not guaranteed ones. Yet the systems we build around them—the ones that control file access, spend money, move machines—cannot be probabilistic. They must be deterministic, auditable, and lawful.

The SwiftVector Codex is our constitutional response: a framework of **Composable Laws** that provide rigid boundaries around fluid intelligence. These Laws do not lobotomize capability. They govern it. An agent operating under the Codex remains free to reason, explore, and propose. It is never free to redefine truth or exceed its authority.

This document establishes the foundational philosophy, the constitutional architecture, and the composable governance modules that comprise the SwiftVector system.

---

## I. The Constitutional Core

At the heart of SwiftVector is a simple premise:

> **Intelligence may be probabilistic. Authority must be deterministic.**

The framework provides the enforcement kernel that bridges the Stochastic Gap. It does not attempt to make models deterministic—it makes *systems* deterministic by constraining where and how model outputs can affect state.

### The Three Pillars

**1. State as Authority**

Authority resides in deterministic state machines, not in natural language prompts. The system's truth is explicit, typed, and immutable. Agents observe state; they do not define it. Prompts may influence reasoning, but state determines what is real and what is permitted.

```
Truth lives in State, not in language.
```

**2. The Reducer Pattern**

All state mutations must pass through a pure-function Reducer:

$$
(CurrentState, Action) \to NewState \mid Rejection
$$

The Reducer is the constitutional gatekeeper. It validates every proposed change against the system's Laws. Invalid actions are rejected—not crashed, not ignored, but explicitly denied with cause. This creates a complete audit trail where every state transition is attributable and every rejection is explainable.

**3. Actor Isolation**

Governance state is protected by Swift Actors to ensure concurrent agent operations cannot corrupt safety logic. Each agent operates in isolation. The Reducer alone has authority to mutate the source of truth. This is not a convention—it is enforced by the compiler.

### The Control Loop

```
┌─────────────────────────────────────────────────────────────────────┐
│                                                                     │
│    State ──▶ Agent ──▶ Action ──▶ Reducer ──▶ New State            │
│   (Truth)   (Propose)  (Typed)    (Pure)     (Truth)               │
│      ▲                              │                               │
│      │                              │                               │
│      │         Audit Log ◀──────────┘                               │
│      │        (Replayable)                                          │
│      │                                                              │
│      └──────────────────────────────────────────────────────────────┘
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

The agent proposes. The Law governs. The Reducer enforces. The State records. This loop is deterministic, replayable, and auditable—even though the agent reasoning within it is not.

---

## II. The Composable Laws

A **Law** is a standalone, deterministic governance module. Laws are the safety kernels that define the boundaries of agent capability. They are:

- **Composable**: Laws can be combined to create domain-specific governance
- **Deterministic**: Law enforcement produces identical results for identical inputs
- **Auditable**: Every Law application is logged and replayable
- **Extensible**: New Laws can be added without modifying the constitutional core

### The Law Registry

Laws are organized into four functional groups. Gaps in numbering are intentional—reserved for Laws that will emerge as agent capabilities evolve.

#### Group I: The Foundational Laws (Boundaries)

These Laws protect the host system and define the fundamental constraints on agent reach.

| Law | Name | Governance Domain |
|-----|------|-------------------|
| **Law 0** | The Boundary Law | Filesystem and network containment |
| **Law 1** | The Context Law | Information retrieval scope (Governed RAG) |
| **Law 2** | The Delegation Law | Authority handoff in multi-agent systems |
| **Law 3** | The Observation Law | Telemetry, readiness validation, and deterministic logging |

**Law 0: The Boundary Law** *(Containment)*

Governs the agent's reach across filesystems and networks. Enforces isolation through type-safe constructs like `SandboxedPath` that make unauthorized access a compile-time error, not a runtime hope. The Boundary Law is the "First Amendment" of the Codex—the non-negotiable right of the host to remain secure.

**Law 1: The Context Law** *(Governed RAG)*

Governs the information boundary and retrieval scope. Ensures that retrieval requests match the agent's current authorization state. An agent authorized for public documentation cannot retrieve private credentials, regardless of how cleverly it phrases the request.

**Law 2: The Delegation Law** *(Orchestration)*

Governs authority handoff in multi-agent systems. Prevents "Authority Creep" by restricting child agent permissions to a subset of the parent's current authorization. A sub-agent cannot acquire capabilities its spawner does not possess.

**Law 3: The Observation Law** *(Telemetry & Readiness)*

Governs deterministic telemetry, logging, and system readiness validation. Provides the audit infrastructure that Law 8 (Authority) and Law 9 (Lifecycle) depend upon. Every observation is timestamped, attributed, and replayable. In physical systems, Law 3 also governs pre-operation checks—ensuring hardware readiness before allowing state transitions to operational modes.

#### Group II: The Sustainability Laws (Resources)

These Laws ensure agents operate within physical, financial, and regulatory limits.

| Law | Name | Governance Domain |
|-----|------|-------------------|
| **Law 4** | The Resource Law | Token spend, energy, and thermal pressure |
| **Law 5** | The Sovereignty Law | Data residency and regulatory compliance |

**Law 4: The Resource Law** *(Budget & Thermals)*

Governs physical and financial sustainability. Acts as a circuit breaker for token spend and energy pressure. When budgets exhaust or thermals exceed thresholds, the Law triggers state transitions to `.degraded` or `.halted` modes. The agent cannot override these transitions—they are constitutional.

**Law 5: The Sovereignty Law** *(Compliance)*

Governs data residency and regulatory compliance (GDPR, CCPA, HIPAA). Hard-codes residency requirements into state transitions to prevent illegal data transmission. A European user's data cannot flow to non-compliant jurisdictions, regardless of agent intent.

#### Group III: The World State Laws (Persistence & Space)

These Laws govern how agents interact with memory and physical environments.

| Law | Name | Governance Domain |
|-----|------|-------------------|
| **Law 6** | The Persistence Law | Memory integrity and state mutation |
| **Law 7** | The Spatial Law | Geometric boundaries for robotics |

**Law 6: The Persistence Law** *(Governed Memory)*

Governs memory integrity by enforcing invariants on world facts. Protects established truth from hallucinatory mutation. In a narrative system, a character's death cannot be un-died by a forgetful model. In a business system, a closed contract cannot be reopened by wishful inference.

**Law 7: The Spatial Law** *(Physical Safety)*

Governs geometric boundaries for robotics and spatial computing. Validates movement against a deterministic Safety Envelope. A drone governed by Law 7 cannot fly outside its geofence, cannot descend below minimum altitude, cannot approach restricted airspace—not because it chooses not to, but because the Law makes such actions unrepresentable.

#### Group IV: The Operational Laws (Lifecycle)

These Laws manage the human-agent relationship and system evolution.

| Law | Name | Governance Domain |
|-----|------|-------------------|
| **Law 8** | The Authority Law | Risk-tiered approval and human command |
| **Law 9** | The Lifecycle Law | Model versioning and deployment |
| **Law 10** | The Protocol Law | Standards for building new Laws |

**Law 8: The Authority Law** *(Verification & Approval)*

Governs the risk-tiered approval queue and human command. Suspends high-risk actions until the Steward provides explicit authorization. Low-risk actions may proceed autonomously; medium-risk actions require notification; high-risk actions require approval. The thresholds are deterministic. The agent cannot self-promote to higher authority.

**Law 9: The Lifecycle Law** *(Model Promotion)*

Governs model versioning, deployment, and rollback. Prevents activation of new intelligence models until they pass deterministic safety benchmarks. A new model cannot enter production until it demonstrates compliance with all active Laws under test conditions.

**Law 10: The Protocol Law** *(Developer Experience)*

Governs the standards for building new Laws. Provides the CLI, templates, and validation tooling that ensures community-built Laws are compliant with the SwiftVector architecture. A Law that cannot be tested deterministically is not a Law.

---

## III. Law Implementation

Laws define **what** is governed. Jurisdictions define **how** that governance manifests in a specific domain.

A Law specification establishes:
- The governance domain (what category of risk it addresses)
- The authority mechanism (how violations are prevented)
- The state requirements (what must be tracked)
- The action constraints (what proposals are valid)

A Jurisdictional implementation specifies:
- The concrete types that embody the Law's abstractions
- The thresholds and limits appropriate to the domain
- The integration points with domain-specific systems
- The audit format for domain-specific compliance

### Example: Law 3 Across Jurisdictions

**Law 3 (Observation)** governs telemetry, readiness, and logging. Its implementation varies by domain:

| Jurisdiction | Law 3 Implementation |
|--------------|----------------------|
| **FlightLaw** | GPS fix validation (3D lock required), battery health, motor status, IMU calibration, pre-flight checklist enforcement |
| **ClawLaw** | System resource monitoring, process isolation verification, network state logging |
| **ChronicleLaw** | Session state capture, narrative branch logging, authorship attribution |

The Law is the same. The implementation is domain-specific. This separation allows the Codex to remain stable while Jurisdictions evolve.

### Complete Law Reference

| Law | Name | Governance Domain | Authority Mechanism |
|-----|------|-------------------|---------------------|
| **0** | Boundary | Filesystem and network containment | Type-safe `SandboxedPath`; unauthorized I/O is unrepresentable |
| **1** | Context | Information retrieval scope | Authorization tier validation; prevents data exposure via RAG |
| **2** | Delegation | Multi-agent authority handoff | Permission inheritance constraints; child ≤ parent authority |
| **3** | Observation | Telemetry and readiness | Deterministic logging; readiness gates on state transitions |
| **4** | Resource | Budget, tokens, power, thermals | Circuit breaker pattern; forces `.degraded` or `.halted` states |
| **5** | Sovereignty | Data residency and compliance | Geographic state constraints; blocks illegal transmission |
| **6** | Persistence | Memory integrity | Fact locking; prevents hallucinatory mutation of world state |
| **7** | Spatial | Geometric boundaries | Safety envelope validation; movement outside bounds is rejected |
| **8** | Authority | Human command and approval | Risk-tiered queue; high-risk actions suspended until authorized |
| **9** | Lifecycle | Model versioning and deployment | Benchmark gates; new models require safety validation |
| **10** | Protocol | Law composition standards | CLI validation; ensures new Laws meet constitutional requirements |

---

## IV. The Jurisdictions

A **Jurisdiction** is a specific composition of Laws tailored for a target domain. Jurisdictions are not separate products—they are configurations of the Codex for particular contexts.

The metaphor is apt: just as legal jurisdictions compose constitutional principles, statutory law, and local ordinances into a coherent governance framework, SwiftVector Jurisdictions compose Laws into domain-specific safety envelopes.

### Jurisdictional Composition Summary

| Jurisdiction | Laws | Primary Purpose |
|--------------|------|-----------------|
| **FlightLaw** (Avionics) | 3, 4, 7, 8 | Deterministic safety for autonomous flight operations |
| **ChronicleLaw** (Narrative) | 6, 8 | Human authorship verification in AI-assisted storytelling |
| **ClawLaw** (Desktop) | 0, 4, 8 | Governed autonomy for desktop agents with tool access |

### Reference Jurisdictions

#### ClawLaw: The Desktop Jurisdiction

**Governing Domain:** Autonomous agents with shell and browser access

**Composed Laws:**
- Law 0 (Boundary): Sandboxed filesystem and network access
- Law 4 (Resource): Token budget and thermal management
- Law 8 (Authority): Approval queue for destructive operations

**Purpose:** Makes the "monster playable." Desktop agents with tool access are extraordinarily capable and extraordinarily dangerous. ClawLaw provides the rules for natural weapons—the agent can use the terminal, but only within boundaries it cannot subvert.

#### ChronicleLaw: The Narrative Jurisdiction

**Governing Domain:** AI-assisted storytelling and game narrative

**Composed Laws:**
- Law 6 (Persistence): World fact protection and narrative coherence
- Law 8 (Authority): Human authorship verification

**Purpose:** Solves the Agency Paradox in literary applications. When AI assists in storytelling, who is the author? ChronicleLaw protects "Character Motivation" and "Plot Decisions" as human-only state transitions, providing a verifiable audit trail of human authorship. The AI may draft prose; it cannot decide fate.

#### FlightLaw: The Avionics Jurisdiction

**Governing Domain:** Safety-critical drone and aviation operations

**Composed Laws:**
- Law 3 (Observation): Flight telemetry, hardware readiness, and pre-flight validation
- Law 4 (Resource): Battery management and thermal limits
- Law 7 (Spatial): Geofencing and flight envelope enforcement
- Law 8 (Authority): Risk-tiered approval for high-consequence maneuvers

**Purpose:** Enables certification-ready autonomous aviation. FlightLaw enforces hard boundaries that satisfy regulatory requirements. A drone under FlightLaw cannot violate its geofence, cannot ignore low-battery warnings, cannot exceed altitude limits. These are not suggestions—they are constitutional constraints compiled into the binary.

**The Digital Black Box:** FlightLaw provides a tamper-evident, replayable record of every decision the autonomous system made. Any incident can be reconstructed exactly. Every state transition is attributable. The system can demonstrate—not merely claim—that it *could not* have violated safety constraints. This transforms compliance from documentation exercise to architectural proof.

---

## V. The Role of the Steward

In every Jurisdiction, the human engineer is the **Steward**—the legislator who defines the Laws and the Pilot in Command who oversees their execution.

The Steward does not:
- Write prompts and hope for compliance
- Monitor logs and react to violations
- Trust the model to self-regulate

The Steward does:
- Define the Laws that govern agent capability
- Configure the Jurisdiction for the operational context
- Maintain authority over state transitions the agent cannot access
- Review audit trails to verify lawful operation

### The Paradox Resolved

The Agency Paradox asks: in a world of autonomous AI, who is truly in command?

The Codex answers: **The Steward writes the Laws. The agent proposes within them. The Reducer enforces. The audit trail proves.**

This is not a hierarchy of trust—it is a separation of concerns. The agent is trusted to reason well. It is not trusted to define its own boundaries. That authority belongs to the Steward, exercised through the Laws, enforced by the Constitution.

---

## VI. Implementation Notes

### Why Swift?

The Codex's principles are language-agnostic. The guarantees are not.

For research and prototyping, implement SwiftVector in whatever language your team knows. For production systems where correctness is a requirement—where regulators review your code, where incidents must be reconstructed exactly, where safety depends on deterministic behavior—Swift provides the foundation that makes the Codex's promises achievable:

- **Compile-time type safety**: Invalid state transitions are caught before deployment
- **Actor isolation**: Concurrent access cannot corrupt governance state
- **Deterministic memory**: No garbage collection pauses affecting execution timing
- **Reproducible execution**: Same binary, same inputs → identical outputs

### The Audit Imperative

Every Law application is logged. Every state transition is attributed. Every rejection is explained.

This is not optional observability—it is constitutional requirement. A system operating under the Codex must be able to answer:

- What state transitions occurred?
- What actions were proposed?
- What actions were rejected, and why?
- Can this sequence be replayed to produce identical results?

If these questions cannot be answered, the system is not governed. It is merely hopeful.

### Extensibility

The Codex is designed for extension. The numbered gaps in the Law registry are not accidents—they are reserved space for governance modules that will emerge as agent capabilities evolve.

New Laws must:
- Be deterministic (same inputs → same outputs)
- Be composable (can combine with existing Laws)
- Be auditable (all applications logged)
- Pass the Protocol Law validation (Law 10)

---

## VII. Conclusion

The Stochastic Gap will not close. Models will remain probabilistic. Agents will remain capable of proposing actions their operators never intended.

The question is not whether to constrain intelligence—it is how to govern it without destroying it.

The SwiftVector Codex offers one answer: define the Laws clearly, enforce them deterministically, audit them completely, and reserve final authority for the Steward who bears responsibility.

Intelligence may be fluid. Authority must be rigid. Between them, the Codex provides the constitutional framework that makes autonomous systems not merely capable, but lawful.

---

## Appendices

### A. Document Hierarchy

| Document | Purpose | Stability |
|----------|---------|-----------|
| **The Codex** (this document) | Constitutional philosophy and Law overview | Stable |
| **SwiftVector Whitepaper** | Technical specification of the enforcement kernel | Stable |
| **Law Specifications** (per-Law) | Detailed technical specification of each Law | Evolving |
| **Jurisdiction Guides** (per-domain) | Implementation guidance for specific domains | Evolving |

### B. Related Reading

- [The Agency Paradox](./manifestos/Agency-Paradox.md) — The philosophical foundation
- [Swift at the Edge](./manifestos/Swift-at-the-Edge.md) — The platform rationale
- [SwiftVector Whitepaper](./whitepaper/SwiftVector-Whitepaper.md) — The technical specification

### C. Glossary

**Agent**: A reasoning component that observes state and proposes actions. Agents may be probabilistic.

**Codex**: The complete constitutional framework comprising the enforcement kernel, the Laws, and the governance philosophy.

**Jurisdiction**: A composition of Laws tailored for a specific domain.

**Law**: A deterministic governance module that constrains agent capability within defined boundaries.

**Reducer**: The pure function that validates and applies state transitions. The constitutional enforcer.

**State**: The single source of truth. Explicit, typed, immutable, auditable.

**Steward**: The human engineer who defines Laws, configures Jurisdictions, and maintains ultimate authority over the system.

**Stochastic Gap**: The distance between human intent and probabilistic model output. The problem the Codex exists to solve.

---

**License:** CC BY 4.0  
**Repository:** [github.com/stephen-sweeney/SwiftVector](https://github.com/stephen-sweeney/SwiftVector)  
**Website:** [agentincommand.ai](https://agentincommand.ai)  
**Contact:** stephen@agentincommand.ai
