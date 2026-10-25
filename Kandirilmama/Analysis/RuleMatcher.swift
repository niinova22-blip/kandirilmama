import Foundation

enum RuleMatcher {
    static func matches(_ rule: MatchRule, tokens: [String]) -> Bool {
        rule.groups.allSatisfy { alternatives in
            alternatives.contains { phraseMatches($0, in: tokens) }
        }
    }

    static func phraseMatches(_ phrase: String, in tokens: [String]) -> Bool {
        let parts = phrase.split(separator: " ").map(String.init)
        guard !parts.isEmpty, tokens.count >= parts.count else { return false }
        for start in 0...(tokens.count - parts.count) {
            var matched = true
            for (offset, part) in parts.enumerated() where !tokenMatches(part, tokens[start + offset]) {
                matched = false
                break
            }
            if matched { return true }
        }
        return false
    }

    static func tokenMatches(_ pattern: String, _ token: String) -> Bool {
        if pattern.hasPrefix("=") {
            return token == String(pattern.dropFirst())
        }
        return token.hasPrefix(pattern)
    }
}

/// Modelin döndürdüğü alıntının transkriptte gerçekten geçtiğini doğrular.
/// Model "uydurursa" alıntı bulunamaz ve sonuç reddedilir.
enum QuoteVerifier {
    static let minimumWords = 3

    static func isVerbatim(_ quote: String, in transcript: String) -> Bool {
        let normalizedQuote = TextNormalizer.normalize(quote)
        guard normalizedQuote.split(separator: " ").count >= minimumWords else { return false }
        return TextNormalizer.normalize(transcript).contains(normalizedQuote)
    }
}
