//
//  StoryAction.swift
//  NarrativeDemo
//
//  Created by Stephen Sweeney on 1/3/26.
//

// MARK: - Actions
enum StoryAction: Sendable, Equatable {
    case moveTo(location: String)
    case findGold(amount: Int)
    case takeDamage(amount: Int)
    case findItem(String)
    case rest(healing: Int)
}
