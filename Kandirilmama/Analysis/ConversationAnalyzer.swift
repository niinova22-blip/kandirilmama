import Foundation

/// Görüşme bittikten sonra bir kez çalışır (sürekli analiz yok → pil tasarrufu).
/// Ağır işler ana thread dışında yürür.
enum ConversationAnalyzer {
    static func analyze(transcript: String, scenario: Scenario) async -> AnalysisReport {
        let baseReport = await Task.detached(priority: .userInitiated) {
            RuleEngine.evaluate(transcript: transcript, scenario: scenario)
        }.value

        let missingIDs = Set(baseReport.items.filter { !$0.isCovered }.map(\.itemID))
        guard !missingIDs.isEmpty, !baseReport.isTranscriptTooShort else {
            return baseReport
        }

        #if canImport(FoundationModels)
        if #available(iOS 26.0, *), FoundationModelsEnhancer.isUsable {
            let missingItems = scenario.checklist.filter { missingIDs.contains($0.id) }
            let quotes = await FoundationModelsEnhancer().findCoverage(transcript: transcript, items: missingItems)
            return RuleEngine.merging(
                verifiedQuotes: quotes,
                into: baseReport,
                transcript: transcript,
                note: "Kural motoru + Apple Intelligence (alıntılar transkriptte doğrulandı)"
            )
        }
        #endif

        return baseReport
    }
}

enum AnalysisCapability {
    static var isEnhancedAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            return FoundationModelsEnhancer.isUsable
        }
        #endif
        return false
    }

    static var statusText: String {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            if FoundationModelsEnhancer.isUsable {
                return "Kural motoru + Apple Intelligence desteği"
            }
            return "Kural motoru (\(FoundationModelsEnhancer.unavailabilityReason))"
        }
        #endif
        return "Kural motoru (Apple Intelligence için iOS 26 gerekir)"
    }
}
