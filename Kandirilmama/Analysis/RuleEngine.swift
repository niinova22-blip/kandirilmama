import Foundation

/// Deterministik analiz: aynı transkript her cihazda aynı sonucu verir.
enum RuleEngine {
    private struct Sentence {
        let text: String
        let tokens: [String]
    }

    static func evaluate(transcript: String, scenario: Scenario) -> AnalysisReport {
        let sentences = TranscriptSegmenter.sentences(from: transcript).map {
            Sentence(text: $0, tokens: TextNormalizer.tokens($0))
        }

        let items = scenario.checklist.map { item -> ItemResult in
            let evidence = firstMatch(of: item.rules, in: sentences)
            return ItemResult(
                itemID: item.id,
                question: item.question,
                severity: item.severity,
                isCovered: evidence != nil,
                evidence: evidence,
                source: evidence == nil ? nil : .rule
            )
        }

        let redFlags = scenario.redFlags.compactMap { flag -> RedFlagHit? in
            guard let evidence = firstMatch(of: flag.rules, in: sentences) else { return nil }
            return RedFlagHit(flagID: flag.id, title: flag.title, advice: flag.advice, evidence: evidence)
        }

        return AnalysisReport(
            items: items,
            redFlags: redFlags,
            wordCount: TextNormalizer.tokens(transcript).count,
            usedOnDeviceModel: false,
            analysisNote: nil
        )
    }

    /// Modelin bulduğu ve doğrulanmış alıntıları rapora işler. Model yalnızca
    /// "konuşulmadı" → "konuşuldu" yönünde ve yalnızca birebir alıntıyla etki edebilir;
    /// risk puanı yine `RiskPolicy` ile yeniden hesaplanır.
    static func merging(
        verifiedQuotes: [String: String],
        into report: AnalysisReport,
        transcript: String,
        note: String?
    ) -> AnalysisReport {
        let items = report.items.map { item -> ItemResult in
            guard !item.isCovered,
                  let quote = verifiedQuotes[item.itemID],
                  QuoteVerifier.isVerbatim(quote, in: transcript)
            else { return item }
            var updated = item
            updated.isCovered = true
            updated.evidence = quote
            updated.source = .verifiedModel
            return updated
        }
        return AnalysisReport(
            items: items,
            redFlags: report.redFlags,
            wordCount: report.wordCount,
            usedOnDeviceModel: true,
            analysisNote: note
        )
    }

    private static func firstMatch(of rules: [MatchRule], in sentences: [Sentence]) -> String? {
        sentences.first { sentence in
            rules.contains { RuleMatcher.matches($0, tokens: sentence.tokens) }
        }?.text
    }
}
