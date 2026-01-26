//
//  StoryAgent.swift
//  NarrativeDemo
//
//  Created by Stephen Sweeney on 1/3/26.
//
import Foundation
import SwiftVectorCore
#if canImport(FoundationModels)
    import FoundationModels
#endif

// MARK: - Agent (Stochastic)
/// The Agent demonstrates the "stochastic" component of SwiftVector.
/// When FoundationModels is available, it uses Apple's on-device LLM.
/// Otherwise, it falls back to random selection.
///
/// Key insight: The Agent can propose anything—valid or invalid.
/// The Reducer is responsible for validation.

actor StoryAgent: Agent {
    
    enum StoryAgentError: Error {
        case invalidLLMOutput
        case unknownActionType
        case foundationModelsUnavailable
    }

    private let possibleActions: [StoryAction] = [
        .moveTo(location: "dark cave"),
        .moveTo(location: "sunlit meadow"),
        .moveTo(location: "ruined tower"),
        .findGold(amount: 20),
        .findGold(amount: 50),
        .findGold(amount: 500),      // Will be rejected—demonstrates validation
        .takeDamage(amount: 15),
        .takeDamage(amount: 30),
        .findItem("healing potion"),
        .findItem("rusty sword"),
        .findItem("ancient map"),
        .rest(healing: 25)
    ]
    
    func propose(about state: AdventureState) async -> StoryAction {
        // Use LLM when available for true stochastic behavior
        guard isFoundationModelsAvailable() else {
            return proposeWithoutLLM(state: state)
        }
        
        do {
            return try await proposeWithLLM(state: state)
        } catch {
            // Graceful fallback if LLM fails
            return proposeWithoutLLM(state: state)
        }
    }
    
    // MARK: - LLM-Based Proposal
    
    private func proposeWithLLM(state: AdventureState) async throws -> StoryAction {
        #if canImport(FoundationModels)
        let instructions = """
        You are a narrative game AI that proposes the next story event.
        You have access to the following action types:
        - moveTo: Move to a new location (e.g., "dark cave", "sunlit meadow", "ruined tower")
        - findGold: Find gold (any amount you think fits the narrative)
        - takeDamage: Take damage from enemies or hazards (typical: 10-30)
        - findItem: Discover an item (e.g., "healing potion", "rusty sword", "ancient map")
        - rest: Rest to recover health (typical: 20-30)
        
        Based on the current game state, propose ONE action that would create
        an interesting narrative moment. Respond ONLY with the action in this exact format:
        ACTION_TYPE: parameter
        
        Examples:
        moveTo: haunted mansion
        findGold: 75
        takeDamage: 15
        findItem: enchanted amulet
        rest: 25
        """
        
        let prompt = """
        Current State:
        Location: \(state.location)
        Health: \(state.health)/100
        Gold: \(state.gold)
        Inventory: \(state.inventory.isEmpty ? "empty" : state.inventory.joined(separator: ", "))
        
        What happens next?
        """
        
        let session = LanguageModelSession(instructions: instructions)
        let response = try await session.respond(to: prompt)
        
        return try parseAction(from: response.content)
        #else
        throw StoryAgentError.foundationModelsUnavailable
        #endif
    }
    
    private func parseAction(from llmOutput: String) throws -> StoryAction {
        let trimmed = llmOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Handle potential markdown or extra formatting from LLM
        let lines = trimmed.components(separatedBy: .newlines)
        guard let firstLine = lines.first(where: { $0.contains(":") }) else {
            throw StoryAgentError.invalidLLMOutput
        }
        
        let parts = firstLine.split(separator: ":", maxSplits: 1).map {
            $0.trimmingCharacters(in: .whitespaces)
        }
        
        guard parts.count == 2 else {
            throw StoryAgentError.invalidLLMOutput
        }
        
        let actionType = parts[0].lowercased()
        let parameter = parts[1]
        
        switch actionType {
        case "moveto":
            return .moveTo(location: parameter)
        case "findgold":
            // LLM might hallucinate huge amounts—reducer will validate
            let amount = Int(parameter) ?? 50
            return .findGold(amount: amount)
        case "takedamage":
            let amount = Int(parameter) ?? 20
            return .takeDamage(amount: amount)
        case "finditem":
            return .findItem(parameter)
        case "rest":
            let healing = Int(parameter) ?? 25
            return .rest(healing: healing)
        default:
            throw StoryAgentError.unknownActionType
        }
    }
    
    // MARK: - Fallback Without LLM
    
    private func proposeWithoutLLM(state: AdventureState) -> StoryAction {
        // Simple heuristics when LLM not available
        if state.health < 30 && state.location == "sunlit meadow" {
            return .rest(healing: 25)
        } else if state.gold < 50 {
            return [.findGold(amount: 20), .findGold(amount: 500)].randomElement()!
        } else if state.inventory.isEmpty {
            return possibleActions.filter {
                if case .findItem = $0 { return true }
                return false
            }.randomElement()!
        }
        
        return possibleActions.randomElement()!
    }
    
    // MARK: - Availability Check
    
    private func isFoundationModelsAvailable() -> Bool {
        #if canImport(FoundationModels)
        return SystemLanguageModel.default.isAvailable
        #else
        return false
        #endif
    }
}
