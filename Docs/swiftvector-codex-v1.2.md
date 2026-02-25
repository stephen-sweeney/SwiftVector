---
layout: ../../layouts/PaperLayout.astro
title: SwiftVector Codex
description: "The constitutional layer: composable Laws, Enforcement Kernels, and domain-specific Governance for governed autonomy."
keywords: SwiftVector Codex, Swift AI governance, deterministic agents, governed autonomy, constitutional AI, MLX on Apple Silicon
datePublished: 2026-02
---

# The SwiftVector Codex

**A Constitutional Framework for Governed Autonomy**

**Version:** 1.2  
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

The Codex does not attempt to make models deterministic—it makes *systems* deterministic by constraining where and how model outputs can affect state. The Laws define what is governed. The Enforcement Kernels compile those Laws into language-specific guarantees. Together, they bridge the Stochastic Gap.

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

Governance state is protected by language-level concurrency guarantees to ensure concurrent agent operations cannot corrupt safety logic. Each agent operates in isolation. The Reducer alone has authority to mutate the source of truth. In SwiftVector, this is enforced by the Swift compiler through Actor isolation. In RustVector, it is enforced through the ownership model. The mechanism varies by Enforcement Kernel; the guarantee does not.

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

A **Law** is a standalone, deterministic governance module. Laws are language-agnostic specifications—they define what must be governed without prescribing how any particular language enforces it. They are:

- **Composable**: Laws combine into domain-specific bodies of law
- **Deterministic**: Law enforcement produces identical results for identical inputs
- **Auditable**: Every Law application is logged and replayable
- **Extensible**: New Laws can be added without modifying the constitutional core

### The Law Registry

Laws are organized into four functional groups. Each Law is identified by name; registry numbers serve as reference indices.

#### Group I: The Foundational Laws (Boundaries)

These Laws protect the host system and define the fundamental constraints on agent reach.

| # | Name | Governance Domain |
|---|------|-------------------|
| 0 | **The Boundary Law** | Filesystem and network containment |
| 1 | **The Context Law** | Information retrieval scope (Governed RAG) |
| 2 | **The Delegation Law** | Authority handoff in multi-agent systems |
| 3 | **The Observation Law** | Telemetry, readiness validation, and deterministic logging |

**The Boundary Law** *(Containment)*

Governs the agent's reach across filesystems and networks. Enforces isolation through type-safe constructs like `SandboxedPath` that make unauthorized access a compile-time error, not a runtime hope. The Boundary Law is the "First Amendment" of the Codex—the non-negotiable right of the host to remain secure.

**The Context Law** *(Governed RAG)*

Governs the information boundary and retrieval scope. Ensures that retrieval requests match the agent's current authorization state. An agent authorized for public documentation cannot retrieve private credentials, regardless of how cleverly it phrases the request.

**The Delegation Law** *(Orchestration)*

Governs authority handoff in multi-agent systems. Prevents "Authority Creep" by restricting child agent permissions to a subset of the parent's current authorization. A sub-agent cannot acquire capabilities its spawner does not possess.

**The Observation Law** *(Telemetry & Readiness)*

Governs deterministic telemetry, logging, and system readiness validation. Provides the audit infrastructure that the Authority Law and the Lifecycle Law depend upon. Every observation is timestamped, attributed, and replayable. In physical systems, the Observation Law also governs pre-operation checks—ensuring hardware readiness before allowing state transitions to operational modes.

#### Group II: The Sustainability Laws (Resources)

These Laws ensure agents operate within physical, financial, and regulatory limits.

| # | Name | Governance Domain |
|---|------|-------------------|
| 4 | **The Resource Law** | Token spend, energy, and thermal pressure |
| 5 | **The Sovereignty Law** | Data residency and regulatory compliance |

**The Resource Law** *(Budget & Thermals)*

Governs physical and financial sustainability. Acts as a circuit breaker for token spend and energy pressure. When budgets exhaust or thermals exceed thresholds, the Law triggers state transitions to `.degraded` or `.halted` modes. The agent cannot override these transitions—they are constitutional.

**The Sovereignty Law** *(Compliance)*

Governs data residency and regulatory compliance (GDPR, CCPA, HIPAA). Hard-codes residency requirements into state transitions to prevent illegal data transmission. A European user's data cannot flow to non-compliant regions, regardless of agent intent.

#### Group III: The World State Laws (Persistence & Space)

These Laws govern how agents interact with memory and physical environments.

| # | Name | Governance Domain |
|---|------|-------------------|
| 6 | **The Persistence Law** | Memory integrity and state mutation |
| 7 | **The Spatial Law** | Geometric boundaries for robotics |

**The Persistence Law** *(Governed Memory)*

Governs memory integrity by enforcing invariants on world facts. Protects established truth from hallucinatory mutation. In a narrative system, a character's death cannot be un-died by a forgetful model. In a business system, a closed contract cannot be reopened by wishful inference.

**The Spatial Law** *(Physical Safety)*

Governs geometric boundaries for robotics and spatial computing. Validates movement against a deterministic Safety Envelope. A drone governed by the Spatial Law cannot fly outside its geofence, cannot descend below minimum altitude, cannot approach restricted airspace—not because it chooses not to, but because the Law makes such actions unrepresentable.

#### Group IV: The Operational Laws (Lifecycle)

These Laws manage the human-agent relationship and system evolution.

| # | Name | Governance Domain |
|---|------|-------------------|
| 8 | **The Authority Law** | Risk-tiered approval and human command |
| 9 | **The Lifecycle Law** | Model versioning and deployment |
| 10 | **The Protocol Law** | Standards for building new Laws and Governance modules |

**The Authority Law** *(Verification & Approval)*

Governs the risk-tiered approval queue and human command. Suspends high-risk actions until the Steward provides explicit authorization. Low-risk actions may proceed autonomously; medium-risk actions require notification; high-risk actions require approval. The thresholds are deterministic. The agent cannot self-promote to higher authority.

**The Lifecycle Law** *(Model Promotion)*

Governs model versioning, deployment, and rollback. Prevents activation of new intelligence models until they pass deterministic safety benchmarks. A new model cannot enter production until it demonstrates compliance with all active Laws under test conditions.

**The Protocol Law** *(Developer Experience)*

Governs the standards for building new Laws and new Governance modules. Provides the CLI, templates, and validation tooling that ensures community-built components are compliant with the SwiftVector architecture. A Law that cannot be tested deterministically is not a Law. A Governance module that cannot trace its authority to a composed Law is not governed.

### Complete Law Reference

| # | Name | Governance Domain | Authority Mechanism |
|---|------|-------------------|---------------------|
| 0 | Boundary | Filesystem and network containment | Type-safe `SandboxedPath`; unauthorized I/O is unrepresentable |
| 1 | Context | Information retrieval scope | Authorization tier validation; prevents data exposure via RAG |
| 2 | Delegation | Multi-agent authority handoff | Permission inheritance constraints; child ≤ parent authority |
| 3 | Observation | Telemetry and readiness | Deterministic logging; readiness gates on state transitions |
| 4 | Resource | Budget, tokens, power, thermals | Circuit breaker pattern; forces `.degraded` or `.halted` states |
| 5 | Sovereignty | Data residency and compliance | Geographic state constraints; blocks illegal transmission |
| 6 | Persistence | Memory integrity | Fact locking; prevents hallucinatory mutation of world state |
| 7 | Spatial | Geometric boundaries | Safety envelope validation; movement outside bounds is rejected |
| 8 | Authority | Human command and approval | Risk-tiered queue; high-risk actions suspended until authorized |
| 9 | Lifecycle | Model versioning and deployment | Benchmark gates; new models require safety validation |
| 10 | Protocol | Law and Governance composition standards | CLI validation; ensures new components meet constitutional requirements |

---

## III. The Architecture

The Codex is the constitution. The language is the jurisdiction.

The Laws are language-agnostic specifications. Enforcement Kernels implement them in specific languages. Domain Laws compose Laws using whichever Kernel fits their platform. This separation creates two critical boundaries: the **Compilation Boundary** between specification and enforcement, and the **Deployment Boundary** between composition and running code.

```
┌─────────────────────────────────────────────────────────────────────┐
│  THE CODEX                                                          │
│  Constitutional framework. Philosophy. The Laws themselves.         │
│  Language-agnostic. Universal across all domains.                   │
├─────────────────────────────────────────────────────────────────────┤
│  THE LAWS (0–10)                                                    │
│  Composable governance modules. Deterministic specifications.       │
│  Language-agnostic. Domain-agnostic. Immutable once ratified.       │
╞═════════════════════════════════════════════════════════════════════╡
│  ▼ THE COMPILATION BOUNDARY ▼                                       │
│  Above: specification · Below: compiled enforcement                 │
╞═════════════════════════════════════════════════════════════════════╡
│  ENFORCEMENT KERNELS                                                │
│  Language-specific implementations. Where the compiler matters.     │
│  ┌──────────────────────┐  ┌──────────────────────┐                │
│  │  SwiftVector (Swift)  │  │  RustVector (Rust)   │                │
│  │  Actor isolation      │  │  Ownership model     │                │
│  │  Apple Silicon native │  │  Cross-platform      │                │
│  │  5MB, zero startup    │  │  no_std bare-metal   │                │
│  └──────────────────────┘  └──────────────────────┘                │
├──────────────┬──────────────┬───────────────────────────────────────┤
│  DOMAIN LAWS                                                        │
│  Domain-specific compositions of Laws through an Enforcement Kernel │
│  ┌──────────────┬──────────────┬──────────────┐                    │
│  │  ClawLaw     │  FlightLaw   │  ChronicleLaw│                    │
│  │  Swift       │  Rust        │  Swift       │                    │
│  │  Boundary    │  Observation  │  Persistence │                    │
│  │  Resource    │  Resource    │  Authority   │                    │
│  │  Authority   │  Spatial     │              │                    │
│  │              │  Authority   │              │                    │
│  └──────────────┴──────────────┴──────────────┘                    │
│                                                                     │
│  GOVERNANCE MODULES                                                 │
│  Context-specific implementations within a Domain Law               │
│  ┌──────────────┬──────────────┬──────────────┐                    │
│  │ Shell        │ Thermal      │ Character    │                    │
│  │ Browser      │ Fire         │ Combat       │                    │
│  │ FileSystem   │ Survey       │ Narrative    │                    │
│  │              │ LawEnforcement│ World       │                    │
│  │              │ SearchAndRescue│ Module     │                    │
│  └──────────────┴──────────────┴──────────────┘                    │
╞═════════════════════════════════════════════════════════════════════╡
│  ▼ THE DEPLOYMENT BOUNDARY ▼                                        │
│  Above: composition · Below: running code                           │
╞═════════════════════════════════════════════════════════════════════╡
│  REFERENCE IMPLEMENTATIONS                                          │
│  Where the Law compiles and runs.                                   │
└─────────────────────────────────────────────────────────────────────┘
```

### Above the Compilation Boundary: Specification

**The Codex** is the constitutional framework itself—the philosophy, the architecture, the complete system of governance. It defines what Laws are, how they compose, and what principles are non-negotiable. It is the document you are reading.

**The Laws** are universal, abstract governance principles. The Boundary Law through the Protocol Law define the categories of risk and the mechanisms for enforcement. They are domain-agnostic—the Spatial Law says "geometric boundaries must be enforced" without specifying whether those boundaries are geofences for drones or room layouts for robots. They are language-agnostic—the Persistence Law says "world facts must be protected from hallucinatory mutation" without specifying whether that protection comes from Swift's Actor isolation or Rust's ownership model.

Everything above the Compilation Boundary is pure specification. It can be read, debated, and ratified without a compiler.

### The Compilation Boundary: Enforcement Kernels

An **Enforcement Kernel** is a language-specific implementation of the Codex's constitutional primitives—the Reducer, the state machine, the audit trail, the type-safe action system. The Kernel is where the compiler matters. It transforms abstract Law specifications into compile-time guarantees.

**SwiftVector** is the Swift Enforcement Kernel. It leverages Actor isolation for concurrency safety, the Swift type system for compile-time state validation, and Apple Silicon optimization for on-device inference. SwiftVector produces a 5MB binary with zero startup cost, native CoreML and Neural Engine access, and compiler-enforced governance state protection.

**RustVector** is the proposed Rust Enforcement Kernel. It would leverage Rust's ownership model for compile-time memory safety, `no_std` support for bare-metal and RTOS targets, and cross-platform compilation from embedded systems to cloud infrastructure. RustVector is under evaluation for domains requiring DO-178C certification or deployment beyond the Apple ecosystem.

**Constitutional equivalence**: Both Kernels implement the same Codex. A `GovernanceReducer` in Swift and a `governance_reducer` in Rust are the same pure function—same inputs, same decisions. The language provides the safety guarantees; the Codex provides the constitutional logic.

### Below the Compilation Boundary: Composition

**Domain Laws** are domain-specific compositions of Laws, compiled through an Enforcement Kernel. FlightLaw, ChronicleLaw, and ClawLaw are the three reference Domain Laws. Each selects the Laws relevant to its domain, compiles them through a specific Kernel, and provides the shared types, infrastructure, and conflict resolution rules for its Governance modules.

A Domain Law establishes:

- **Law composition**: Which Laws apply, and how they are configured for the domain
- **Kernel selection**: Which Enforcement Kernel compiles the Laws for this domain
- **Shared types**: The common abstractions used across all Governance modules in the domain
- **Conflict resolution**: When two Governance modules make competing demands, the Domain Law defines precedence
- **Domain audit format**: How the domain's compliance record is structured

Domain Laws are named by their domain: FlightLaw, ChronicleLaw, ClawLaw. The compound name is a proper noun—it identifies a specific body of law, not a generic concept. New domains create new Domain Laws.

**Governance Modules** are context-specific implementations within a Domain Law. They carry the domain expertise—the research, the thresholds, the concrete types—that makes governance meaningful in a particular operational context.

Governance modules are where theory meets practice. FireGovernance under FlightLaw exists because wildfire drone operations have specific safety requirements that differ from thermal survey operations. CharacterGovernance under ChronicleLaw exists because character state integrity in a narrative system has specific persistence requirements that differ from world state coherence.

Each Governance module is grounded in domain-specific research. FireGovernance requires fire science. ThermalGovernance requires atmospheric thermodynamics. CharacterGovernance requires RPG character system design. This research produces the concrete numbers, rules, and types that the Governance module enforces.

A Governance module specifies:

- **Concrete types**: The domain-specific implementations of its parent Law's abstractions
- **Thresholds and limits**: Grounded in domain research, not guesswork
- **Integration points**: How this module connects to context-specific systems
- **Audit format**: Context-specific compliance records

### Below the Deployment Boundary: Running Code

**Reference Implementations** are where the Law compiles and runs. Each is a deployable application built on a Domain Law through an Enforcement Kernel. ClawLaw v0.1.0-alpha provides governed autonomy for desktop agents. ChronicleLaw provides human authorship verification in AI-assisted storytelling. FlightLaw provides deterministic safety for autonomous flight operations.

Reference implementations are the proof that the architecture works—that Laws specified in prose survive compilation into binaries that actually enforce them.

### How the Levels Interact

Authority flows downward. A Governance module derives its authority from the Domain Law that contains it. A Domain Law derives its authority from the Laws it composes. Laws derive their authority from the Codex. The Enforcement Kernel is the mechanism that compiles authority into guarantees—it does not grant authority of its own.

Information flows upward. As Governance modules are implemented in real operational contexts, they reveal refinements needed in the Laws themselves. These refinements are proposed through the Protocol Law and adopted through constitutional amendment.

No level can redefine the level above it. A Governance module cannot exceed the authority granted by its Domain Law. A Domain Law cannot exceed the authority granted by the Laws it composes. An Enforcement Kernel cannot weaken a Law's specification—it can only strengthen it with language-specific guarantees.

This is how the Codex evolves: concrete implementations teach abstract principles what they missed.

---

## IV. Law Implementation Across Domains

Laws define **what** is governed. Domain Laws define **which** Laws apply. Governance modules define **how** governance manifests in a specific operational context. The Enforcement Kernel determines **where** the compiler draws the line between valid and invalid.

### Example: The Observation Law Across Domains

The Observation Law governs telemetry, readiness, and logging. Its implementation varies by domain:

| Domain Law | Observation Law Implementation |
|------------|-------------------------------|
| **FlightLaw** | GPS fix validation (3D lock required), battery health, motor status, IMU calibration, pre-flight checklist enforcement |
| **ClawLaw** | System resource monitoring, process isolation verification, network state logging |
| **ChronicleLaw** | Session state capture, narrative branch logging, authorship attribution |

The Law is the same. The Enforcement Kernel compiles it. The Domain Law configures it. The Governance module implements it with domain expertise. This separation allows the Codex to remain stable while Domain Laws and their Governance modules evolve.

---

## V. Reference Domain Laws

### FlightLaw: Avionics

**Governing Domain:** Safety-critical drone and aviation operations  
**Enforcement Kernel:** RustVector (Rust)

**Composed Laws:**
- The Observation Law: Flight telemetry, hardware readiness, and pre-flight validation
- The Resource Law: Battery management and thermal limits
- The Spatial Law: Geofencing and flight envelope enforcement
- The Authority Law: Risk-tiered approval for high-consequence maneuvers

**Governance Modules:**
- **ThermalGovernance**: Atmospheric thermal survey operations. Altitude profiles, thermal detection thresholds, survey pattern constraints.
- **FireGovernance**: Wildfire and fire suppression operations. Smoke plume modeling, radiant heat limits, incident command integration.
- **SurveyGovernance**: Photogrammetric and mapping operations. Overlap requirements, altitude constraints, coverage verification.
- **LawEnforcement**: Surveillance and public safety operations. Fourth Amendment constraints, evidence chain of custody, operational boundaries.
- **SearchAndRescueGovernance**: Emergency search operations. Extended range calculations, communication requirements, coordination protocols.

**Purpose:** Enables certification-ready autonomous aviation. FlightLaw enforces hard boundaries that satisfy regulatory requirements. A drone under FlightLaw cannot violate its geofence, cannot ignore low-battery warnings, cannot exceed altitude limits. These are not suggestions—they are constitutional constraints compiled into the binary.

**The Digital Black Box:** FlightLaw provides a tamper-evident, replayable record of every decision the autonomous system made. Any incident can be reconstructed exactly. Every state transition is attributable. The system can demonstrate—not merely claim—that it *could not* have violated safety constraints. This transforms compliance from documentation exercise to architectural proof.

### ChronicleLaw: Narrative

**Governing Domain:** AI-assisted storytelling and game narrative  
**Enforcement Kernel:** SwiftVector (Swift)

**Composed Laws:**
- The Persistence Law: World fact protection and narrative coherence
- The Authority Law: Human authorship verification

**Governance Modules:**
- **CharacterGovernance**: Character state integrity. Identity, mortality, relationships, goals, moral positions. Protects character facts from hallucinatory mutation.
- **CombatGovernance**: Conflict resolution determinism. Mechanical fairness, outcome reproducibility, same-inputs-same-outputs guarantee.
- **NarrativeGovernance**: Prose generation constraints. Style boundaries, content limits, the rules for transforming gameplay events into literary prose.
- **WorldGovernance**: World state coherence. Geography, factions, history, environmental conditions. Protects canonical world facts.
- **ModuleGovernance**: Content authoring and validation. Schema compliance, balance constraints, narrative primitive requirements, three-tier authorship enforcement.

**Purpose:** Solves the Agency Paradox in literary applications. When AI assists in storytelling, who is the author? ChronicleLaw protects "Character Motivation" and "Plot Decisions" as human-only state transitions, providing a verifiable audit trail of human authorship. The AI may draft prose; it cannot decide fate.

### ClawLaw: Desktop

**Governing Domain:** Autonomous agents with shell and browser access  
**Enforcement Kernel:** SwiftVector (Swift)

**Composed Laws:**
- The Boundary Law: Sandboxed filesystem and network access
- The Resource Law: Token budget and thermal management
- The Authority Law: Approval queue for destructive operations

**Governance Modules:**
- **ShellGovernance**: Terminal command execution boundaries. Command whitelisting, directory scoping, privilege escalation prevention.
- **BrowserGovernance**: Web interaction constraints. Domain restrictions, form submission approval, download authorization.
- **FileSystemGovernance**: File operation governance. Read/write scope, deletion approval, sensitive file detection.

**Purpose:** Makes the "monster playable." Desktop agents with tool access are extraordinarily capable and extraordinarily dangerous. ClawLaw provides the rules for natural weapons—the agent can use the terminal, but only within boundaries it cannot subvert.

---

## VI. The Role of the Steward

The human engineer is the **Steward**—the legislator who defines the Laws, composes Domain Laws, configures Governance modules, and maintains ultimate authority over the system.

The Steward does not:
- Write prompts and hope for compliance
- Monitor logs and react to violations
- Trust the model to self-regulate

The Steward does:
- Define the Laws that govern agent capability
- Select the Enforcement Kernel appropriate to the domain
- Compose Domain Laws for operational contexts
- Configure Governance modules with domain-specific expertise
- Maintain authority over state transitions the agent cannot access
- Review audit trails to verify lawful operation

### The Paradox Resolved

The Agency Paradox asks: in a world of autonomous AI, who is truly in command?

The Codex answers: **The Steward writes the Laws. The Kernel compiles them. The agent proposes within them. The Reducer enforces. The audit trail proves.**

This is not a hierarchy of trust—it is a separation of concerns. The agent is trusted to reason well. It is not trusted to define its own boundaries. That authority belongs to the Steward, exercised through the Laws, compiled by the Kernel, enforced by the Constitution.

---

## VII. Extensibility

The Codex is designed for extension at every level.

**New Laws** may be added to the registry. Each Law is identified by name and assigned a registry number. New Laws must be deterministic, composable, auditable, and pass Protocol Law validation.

**New Enforcement Kernels** may implement the Codex in additional languages. Each Kernel must demonstrate constitutional equivalence—identical inputs producing identical governance decisions regardless of implementation language. The Protocol Law provides the compliance test suite.

**New Domain Laws** may be created for new operational domains. A Domain Law selects the Laws relevant to its domain, chooses an Enforcement Kernel, and defines how its Governance modules interact.

**New Governance modules** may be added to existing Domain Laws as new operational contexts are encountered. Each Governance module must trace its authority to a composed Law and must be grounded in domain-specific research. Governance modules are scaffolded and validated through the Protocol Law.

---

## VIII. Conclusion

The Stochastic Gap will not close. Models will remain probabilistic. Agents will remain capable of proposing actions their operators never intended.

The question is not whether to constrain intelligence—it is how to govern it without destroying it.

The SwiftVector Codex offers one answer: define the Laws clearly, compile them through Enforcement Kernels that provide real guarantees, compose them into Domain Laws for specific contexts, implement them as Governance modules grounded in real expertise, enforce them deterministically, audit them completely, and reserve final authority for the Steward who bears responsibility.

Intelligence may be fluid. Authority must be rigid. Between them, the Codex provides the constitutional framework that makes autonomous systems not merely capable, but lawful.

---

## Appendices

### A. Document Hierarchy

| Document | Purpose | Stability |
|----------|---------|-----------|
| **The Codex** (this document) | Constitutional philosophy, Laws, architecture | Stable |
| **SwiftVector Whitepaper** | Technical specification of the SwiftVector Enforcement Kernel | Stable |
| **Law Specifications** (per-Law) | Detailed technical specification of each Law | Evolving |
| **Domain Law Guides** (per-domain) | Domain Law composition, Kernel selection, shared types | Evolving |
| **Governance Module Specs** (per-module) | Context-specific implementation and domain research | Active |

### B. Related Reading

- [The Agency Paradox](./manifestos/Agency-Paradox.md) — The philosophical foundation
- [Swift at the Edge](./manifestos/Swift-at-the-Edge.md) — The platform rationale
- [SwiftVector Whitepaper](./whitepaper/SwiftVector-Whitepaper.md) — The technical specification

### C. Glossary

**Agent**: A reasoning component that observes state and proposes actions. Agents may be probabilistic.

**Codex**: The complete constitutional framework comprising the Laws, the architecture, and the governance philosophy. Language-agnostic.

**Domain Law**: A domain-specific composition of Laws compiled through an Enforcement Kernel. Provides shared types, infrastructure, and conflict resolution for a particular operational domain. Examples: FlightLaw, ChronicleLaw, ClawLaw.

**Enforcement Kernel**: A language-specific implementation of the Codex's constitutional primitives—the Reducer, the state machine, the audit trail, the type-safe action system. Sits at the Compilation Boundary. Examples: SwiftVector (Swift), RustVector (Rust).

**Governance Module**: A context-specific implementation within a Domain Law, grounded in domain research, carrying the concrete types and thresholds that make governance operational. Examples: FireGovernance, CharacterGovernance, ShellGovernance.

**Law**: A universal, deterministic governance principle that constrains agent capability within defined boundaries. Language-agnostic and domain-agnostic. Identified by name; numbered for registry reference.

**Reducer**: The pure function that validates and applies state transitions. The constitutional enforcer. Compiled by the Enforcement Kernel.

**State**: The single source of truth. Explicit, typed, immutable, auditable.

**Steward**: The human engineer who defines Laws, selects Enforcement Kernels, composes Domain Laws, configures Governance modules, and maintains ultimate authority over the system.

**Stochastic Gap**: The distance between human intent and probabilistic model output. The problem the Codex exists to solve.

### D. Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | February 2026 | Initial publication. Two-level architecture (Laws, Jurisdictions). |
| 1.1 | February 2026 | Four-level architecture. Replaced "Jurisdiction" with Domain Law and Governance modules. Added reference Governance modules for all three Domain Laws. Updated Protocol Law scope. |
| 1.2 | February 2026 | Architecture aligned with visual diagram. Added Enforcement Kernels and Compilation Boundary as formal architectural concepts. Added Deployment Boundary. Introduced SwiftVector and RustVector as named Kernels. Removed bracket notation from naming conventions. Removed "gaps in numbering" language; Laws identified by name with registry numbers. Constitutional equivalence across Kernels formalized. Domain Law Kernel selection made explicit. |

---

**License:** CC BY 4.0  
**Repository:** [github.com/stephen-sweeney/SwiftVector](https://github.com/stephen-sweeney/SwiftVector)  
**Website:** [agentincommand.ai](https://agentincommand.ai)  
**Contact:** stephen@agentincommand.ai
