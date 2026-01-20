//
//  StoryAction.swift
//  NarrativeDemo
//
//  Created by Stephen Sweeney on 1/3/26.
//

import CryptoKit
import Foundation
import SwiftVectorCore

// MARK: - Actions
enum StoryAction: Action {
    case moveTo(location: String)
    case findGold(amount: Int)
    case takeDamage(amount: Int)
    case findItem(String)
    case rest(healing: Int)
}

// MARK: - Action Protocol

extension StoryAction {
    var actionDescription: String {
        switch self {
        case .moveTo(let location):
            return "Move to \(location.indefiniteArticlePrefixed)"
        case .findGold(let amount):
            return "Find \(amount) gold"
        case .takeDamage(let amount):
            return "Take \(amount) damage"
        case .findItem(let item):
            return "Find \(item)"
        case .rest(let healing):
            return "Rest and recover \(healing) health"
        }
    }
    
    var correlationID: UUID {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let payload = (try? encoder.encode(self)) ?? Data()
        let digest = SHA256.hash(data: payload)
        return Self.uuid(from: Array(digest))
    }
    
    private static func uuid(from bytes: [UInt8]) -> UUID {
        guard bytes.count >= 16 else {
            return UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0))
        }
        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }
}
