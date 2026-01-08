//
//  ViewModel.swift
//  NarrativeDemo
//
//  Created by Stephen Sweeney on 1/2/26.
//
import Combine

// MARK: - ViewModel (Safe, no retain cycles)
@MainActor
final class ViewModel: ObservableObject {
    @Published var state = AdventureState()
    
    private let orchestrator = AdventureOrchestrator()
    private var task: Task<Void, Never>?
    
    init() {
        task = Task { [weak self] in
            guard let self else { return }
            for await newState in await orchestrator.stateStream() {
                await MainActor.run {
                    self.state = newState
                }
            }
        }
    }
    
    func nextEvent() {
        Task {
            await orchestrator.advanceStory()
        }
    }
    
    deinit {
        task?.cancel()
    }
}
