//
//  BaseOrchestrator.swift
//  SwiftVectorCore
//
//  Created by Stephen Sweeney
//  Copyright © 2026 Flightworks Aerial LLC. All rights reserved.
//

import Foundation

/// Reusable orchestration engine that applies actions, records audit entries,
/// and streams state updates. Intended as a building block for concrete
/// orchestrators that provide agent-specific behavior.
///
/// Note: This type does not conform to `Orchestrator` directly. Concrete
/// orchestrators compose it and implement `advance()`.
public actor BaseOrchestrator<S: State, A: Action, R: Reducer> where R.S == S, R.A == A {

    public typealias State = S
    public typealias Action = A
    public typealias ReducerType = R

    public private(set) var currentState: S

    private let reducer: R
    private let clock: any Clock
    private let uuid: any UUIDGenerator

    nonisolated private let stream: AsyncStream<S>
    private let continuation: AsyncStream<S>.Continuation

    private var log: EventLog<A>

    public init(
        initialState: S,
        reducer: R,
        clock: any Clock,
        uuidGenerator: any UUIDGenerator
    ) {
        (stream, continuation) = AsyncStream.makeStream()
        self.currentState = initialState
        self.reducer = reducer
        self.clock = clock
        self.uuid = uuidGenerator
        self.log = EventLog()

        log.append(.initialization(
            id: uuid.next(),
            timestamp: clock.now(),
            initialStateHash: initialState.stateHash()
        ))

        continuation.yield(initialState)
    }

    public nonisolated func stateStream() -> AsyncStream<S> {
        stream
    }

    public func auditLog() async -> EventLog<A> {
        log
    }

    @discardableResult
    public func submit(_ action: A, agentID: String) async -> ReducerResult<S> {
        await apply(action: action, agentID: agentID)
    }

    @discardableResult
    public func replay(_ action: A, agentID: String) async -> ReducerResult<S> {
        await apply(action: action, agentID: agentID)
    }

    @discardableResult
    func apply(action: A, agentID: String) async -> ReducerResult<S> {
        let hashBefore = currentState.stateHash()
        let result = reducer.reduce(state: currentState, action: action)

        currentState = result.newState
        let hashAfter = currentState.stateHash()

        if result.applied {
            log.append(.accepted(
                id: uuid.next(),
                timestamp: clock.now(),
                action: action,
                agentID: agentID,
                stateHashBefore: hashBefore,
                stateHashAfter: hashAfter,
                rationale: result.rationale,
                previousEntryHash: ""
            ))
        } else {
            log.append(.rejected(
                id: uuid.next(),
                timestamp: clock.now(),
                action: action,
                agentID: agentID,
                stateHash: hashBefore,
                rationale: result.rationale,
                previousEntryHash: ""
            ))
        }

        continuation.yield(currentState)
        return result
    }

    deinit {
        continuation.finish()
    }
}
