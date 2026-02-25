//
//  CompositionRule.swift
//  SwiftVectorCore
//
//  Copyright © 2026 Flightworks Aerial LLC. All rights reserved.
//

import Foundation

// MARK: - CompositionRule

/// The rule used to compose individual Law verdicts into a final decision.
///
/// When multiple Laws evaluate the same action, the `CompositionRule`
/// determines how their individual verdicts combine. The rule must be
/// recorded alongside the verdicts so that replay can verify not just
/// the individual decisions but the composition logic that combined them.
///
/// ## Available Rules
///
/// - `denyWins`: Any deny overrides all allows. Most restrictive verdict
///   wins. This is the safest default for safety-critical systems.
/// - `unanimousAllow`: All non-abstaining Laws must allow for the action
///   to proceed. A single objection blocks. Suitable for high-assurance
///   contexts where every Law must explicitly agree.
/// - `majorityAllow`: A strict majority of non-abstaining Laws must allow.
///   Suitable for advisory governance where some dissent is tolerable.
///
/// ## Abstention Handling
/// All rules filter out `.abstain` verdicts before applying composition.
/// A Law that abstains has no jurisdiction and does not influence the
/// outcome under any rule.
///
/// ## Custom Rules
/// Domain Laws that need composition logic beyond these three options
/// should define custom composition functions in their own modules.
/// The framework provides these standard rules; domains extend them.
public enum CompositionRule: String, Sendable, Equatable, Codable, CaseIterable {

    /// Any deny overrides all allows. Most restrictive verdict wins.
    ///
    /// Priority: deny > escalate > allow.
    /// This is the default and safest composition strategy.
    case denyWins

    /// All non-abstaining Laws must allow for the action to proceed.
    ///
    /// Priority: deny > escalate > (unanimous allow required).
    /// A single non-allow verdict blocks the action.
    case unanimousAllow

    /// A strict majority (> 50%) of non-abstaining Laws must allow.
    ///
    /// If no strict majority allows, deny takes priority over escalate.
    /// Ties go to the more restrictive outcome.
    case majorityAllow
}
