import Foundation

/// Türkçe metni kural eşleştirmesi için sadeleştirir:
/// küçük harf (tr kurallarıyla: İ→i, I→ı), Türkçe karakter katlama (ş→s, ı→i ...),
/// harf/rakam dışındaki her şeyi tek boşluğa indirger.
enum TextNormalizer {
    private static let turkishLocale = Locale(identifier: "tr_TR")
    private static let folding: [Character: Character] = [
        "ç": "c", "ğ": "g", "ı": "i", "ö": "o", "ş": "s", "ü": "u",
        "â": "a", "î": "i", "û": "u",
    ]

    static func normalize(_ text: String) -> String {
        let lowered = text.lowercased(with: turkishLocale)
        var output = ""
        output.reserveCapacity(lowered.count)
        var lastWasSpace = true
        for character in lowered {
            let folded = folding[character] ?? character
            if folded.isLetter || folded.isNumber {
                output.append(folded)
                lastWasSpace = false
            } else if !lastWasSpace {
                output.append(" ")
                lastWasSpace = true
            }
        }
        if output.hasSuffix(" ") {
            output.removeLast()
        }
        return output
    }

    static func tokens(_ text: String) -> [String] {
        normalize(text).split(separator: " ").map(String.init)
    }
}

/// Transkripti cümlelere böler. Konuşma tanıma noktalama koymazsa uzun parçaları
/// örtüşen kelime pencerelerine ayırır.
enum TranscriptSegmenter {
    static func sentences(from text: String, maxWords: Int = 30, overlap: Int = 5) -> [String] {
        let rough = text
            .split(whereSeparator: { ".!?\n…".contains($0) })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var result: [String] = []
        for sentence in rough {
            let words = sentence.split(whereSeparator: \.isWhitespace)
            guard words.count > maxWords else {
                result.append(sentence)
                continue
            }
            let stride = max(1, maxWords - overlap)
            var start = 0
            while start < words.count {
                let end = min(start + maxWords, words.count)
                result.append(words[start..<end].joined(separator: " "))
                if end == words.count { break }
                start += stride
            }
        }
        return result
    }
}
