//
//  String+IndefiniteArticle.swift
//  NarrativeDemo
//
//  Created by Stephen Sweeney on 1/3/26.
//

extension String {
    // LEARNING-DEBT(workaround): Swift 6 actor isolation inference on extension computed properties
    // See LEARNING.md for details.
    nonisolated var indefiniteArticlePrefixed: String {
        let vowels = Set("aeiou")
        let first = self.lowercased().first ?? " "
        return vowels.contains(first) ? "an \(self)" : "a \(self)"
    }
}
