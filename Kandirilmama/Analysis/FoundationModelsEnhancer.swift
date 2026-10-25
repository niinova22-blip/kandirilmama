#if canImport(FoundationModels)
import Foundation
import FoundationModels

@available(iOS 26.0, *)
@Generable
struct CoverageFinding {
    @Guide(description: "Maddenin kimliği; listede verilen id ile birebir aynı olmalı")
    var itemID: String

    @Guide(description: "Bu konu metinde açıkça konuşulduysa true, emin değilsen false")
    var discussed: Bool

    @Guide(description: "discussed true ise metinden kelimesi kelimesine kopyalanmış kısa alıntı (en az 3 kelime); değilse boş metin")
    var quote: String
}

@available(iOS 26.0, *)
@Generable
struct CoverageAnswer {
    @Guide(description: "Listedeki her madde için tam bir sonuç")
    var findings: [CoverageFinding]
}

/// Apple Intelligence (cihaz üzerindeki model) ile, kuralların kaçırdığı farklı
/// ifadeleri yakalamaya çalışır. Yalnızca destek amaçlıdır:
/// - Sadece kuralların "konuşulmadı" dediği maddelere bakar.
/// - Her bulgu transkriptte birebir doğrulanan alıntı gerektirir (`QuoteVerifier`).
/// - Risk puanını hiçbir zaman doğrudan etkilemez.
@available(iOS 26.0, *)
struct FoundationModelsEnhancer {
    /// Model bağlam penceresi küçük (~4K token); transkript parçalara bölünür.
    private static let maxChunkCharacters = 1_500

    static var isUsable: Bool {
        let model = SystemLanguageModel.default
        guard case .available = model.availability else { return false }
        return model.supportedLanguages.contains { $0.languageCode?.identifier == "tr" }
    }

    static var unavailabilityReason: String {
        let model = SystemLanguageModel.default
        switch model.availability {
        case .available:
            return "Apple Intelligence Türkçe desteklemiyor"
        case .unavailable(.deviceNotEligible):
            return "Cihaz Apple Intelligence desteklemiyor"
        case .unavailable(.appleIntelligenceNotEnabled):
            return "Apple Intelligence kapalı"
        case .unavailable(.modelNotReady):
            return "Apple Intelligence modeli henüz hazır değil"
        case .unavailable:
            return "Apple Intelligence kullanılamıyor"
        }
    }

    /// - Returns: `itemID → doğrulanmış alıntı`
    func findCoverage(transcript: String, items: [ChecklistItem]) async -> [String: String] {
        var remaining = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
        var confirmed: [String: String] = [:]

        for chunk in Self.chunks(of: transcript) {
            guard !remaining.isEmpty else { break }
            if Task.isCancelled { break }

            let pending = items.filter { remaining[$0.id] != nil }
            guard let answer = await ask(chunk: chunk, items: pending) else { continue }

            for finding in answer.findings where finding.discussed {
                guard remaining[finding.itemID] != nil,
                      QuoteVerifier.isVerbatim(finding.quote, in: chunk)
                else { continue }
                confirmed[finding.itemID] = finding.quote
                remaining[finding.itemID] = nil
            }
        }
        return confirmed
    }

    private func ask(chunk: String, items: [ChecklistItem]) async -> CoverageAnswer? {
        let instructions = """
        Sen bir alışveriş görüşmesi transkriptini inceleyen dikkatli bir asistansın.
        Yalnızca metinde AÇIKÇA geçen bilgilere dayan. Tahmin yürütme, yorum ekleme.
        Bir konu konuşulduysa alıntıyı metinden kelimesi kelimesine kopyala.
        Emin değilsen discussed değerini false yap.
        """
        let itemList = items
            .map { "- id: \($0.id) | konu: \($0.topicDescription)" }
            .joined(separator: "\n")
        let prompt = """
        Maddeler:
        \(itemList)

        Transkript:
        \"\"\"
        \(chunk)
        \"\"\"

        Her madde için bu transkript parçasında konunun konuşulup konuşulmadığını belirt.
        """

        do {
            let session = LanguageModelSession(instructions: instructions)
            let response = try await session.respond(
                to: prompt,
                generating: CoverageAnswer.self,
                options: GenerationOptions(sampling: .greedy)
            )
            return response.content
        } catch {
            // Bağlam aşımı, güvenlik filtresi vb. → bu parçayı atla, kural sonucu geçerli kalır.
            return nil
        }
    }

    private static func chunks(of transcript: String) -> [String] {
        var result: [String] = []
        var current = ""
        for sentence in TranscriptSegmenter.sentences(from: transcript) {
            if !current.isEmpty, current.count + sentence.count + 2 > maxChunkCharacters {
                result.append(current)
                current = ""
            }
            current += current.isEmpty ? sentence : ". " + sentence
        }
        if !current.isEmpty {
            result.append(current)
        }
        return result
    }
}
#endif
