//
//  State.swift
//  SwiftVectorCore
//
//  Created by Stephen Sweeney
//  Copyright © 2026 Flightworks Aerial LLC. All rights reserved.
//

import Foundation
import CryptoKit

// MARK: - State Protocol

/// A deterministic, hashable snapshot of system state.
///
/// State is the single source of truth in SwiftVector's control loop:
/// ```
/// State → Agent → Action → Reducer → New State
/// ```
///
/// Conformers must be value types to guarantee immutability between transitions.
/// The `Sendable` requirement ensures safe passage across actor boundaries.
///
/// ## Example
/// ```swift
/// struct GameState: State {
///     var location: String
///     var health: Int
///     var inventory: [String]
/// }
/// ```
///
/// ## Hashing
/// The default `stateHash()` implementation uses JSON encoding with sorted keys
/// followed by SHA256. Conformers may override for performance-critical paths,
/// but must ensure determinism: same state → same hash, always.
public protocol State: Sendable, Equatable, Codable {
    
    /// Generates a cryptographic hash of the complete state.
    ///
    /// This hash serves two purposes:
    /// 1. **Audit trail**: Links state transitions in an immutable chain
    /// 2. **Replay verification**: Confirms identical state after replay
    ///
    /// The default implementation encodes to JSON with sorted keys, then
    /// applies SHA256. This is deterministic across runs and platforms.
    ///
    /// - Returns: A 64-character lowercase hexadecimal SHA256 hash
    func stateHash() -> String
}

// MARK: - Default Implementation

extension State {
    
    /// Default implementation using JSON + SHA256.
    ///
    /// This is suitable for most use cases. Override only if:
    /// - Performance profiling shows hashing as a bottleneck
    /// - State contains non-Codable properties requiring custom serialization
    ///
    /// - Important: Any override must be deterministic. Non-deterministic hashing
    ///   breaks replay verification and audit trail integrity.
    public func stateHash() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]  // Deterministic key ordering
        
        guard let data = try? encoder.encode(self) else {
            // State protocol requires Codable, so this should never fail.
            // If it does, it's a programmer error in the conforming type.
            preconditionFailure(
                "State must be JSON-encodable. Check that all properties of \(type(of: self)) are Codable."
            )
        }
        
        let digest = SHA256.hash(data: data)
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - StateHashable (Deprecated Name Alias)

/// Alias for backward compatibility during migration.
/// Prefer `State` for new code.
@available(*, deprecated, renamed: "State")
public typealias StateHashable = State
