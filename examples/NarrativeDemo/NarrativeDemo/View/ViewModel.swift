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
    @Published var narrativeLog: [String] = ["🌲 You awaken in an ancient forest, birds singing overhead."]
    
    private let orchestrator = AdventureOrchestrator(
        governancePolicy: StoryLaws.defaultPolicy()
    )
    private var task: Task<Void, Never>?
    
    init() {
        task = Task { [weak self] in
            guard let self else { return }
            for await newState in await orchestrator.stateStream() {
                let narrative = await orchestrator.getNarrativeLog()
                await MainActor.run {
                    self.state = newState
                    self.narrativeLog = narrative
                }
            }
        }
    }
    
    func nextEvent() {
        Task {
            await orchestrator.advance()
        }
    }
    
    deinit {
        task?.cancel()
    }
}
