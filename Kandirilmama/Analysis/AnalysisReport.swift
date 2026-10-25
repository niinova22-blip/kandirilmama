import Foundation

enum RiskLevel: String, Codable, Sendable {
    case low
    case medium
    case high

    var title: String {
        switch self {
        case .low: "Düşük Risk"
        case .medium: "Orta Risk"
        case .high: "Yüksek Risk"
        }
    }
}

enum EvidenceSource: String, Codable, Sendable {
    /// Anahtar ifade kuralı eşleşti.
    case rule
    /// Apple Intelligence buldu ve alıntı transkriptte birebir doğrulandı.
    case verifiedModel
}

struct ItemResult: Codable, Identifiable, Hashable, Sendable {
    let itemID: String
    let question: String
    let severity: Severity
    var isCovered: Bool
    var evidence: String?
    var source: EvidenceSource?

    var id: String { itemID }
}

struct RedFlagHit: Codable, Identifiable, Hashable, Sendable {
    let flagID: String
    let title: String
    let advice: String
    let evidence: String

    var id: String { flagID }
}

struct AnalysisReport: Codable, Sendable {
    static let minimumMeaningfulWordCount = 30

    var items: [ItemResult]
    var redFlags: [RedFlagHit]
    var riskLevel: RiskLevel
    var riskScore: Int
    var riskReasons: [String]
    var wordCount: Int
    var usedOnDeviceModel: Bool
    var analysisNote: String?

    var isTranscriptTooShort: Bool {
        wordCount < Self.minimumMeaningfulWordCount
    }

    init(items: [ItemResult], redFlags: [RedFlagHit], wordCount: Int, usedOnDeviceModel: Bool, analysisNote: String?) {
        self.items = items
        self.redFlags = redFlags
        self.wordCount = wordCount
        self.usedOnDeviceModel = usedOnDeviceModel
        self.analysisNote = analysisNote
        let assessment = RiskPolicy.assess(items: items, redFlags: redFlags)
        self.riskScore = assessment.score
        self.riskLevel = assessment.level
        self.riskReasons = assessment.reasons
    }
}

/// Risk seviyesi yalnızca bu sabit puan tablosundan hesaplanır; model risk "tahmin" etmez.
///
/// | Durum                         | Puan |
/// |-------------------------------|------|
/// | Konuşulmamış kritik madde     | 3    |
/// | Konuşulmamış önemli madde     | 1    |
/// | Tespit edilen uyarı ifadesi   | 2    |
///
/// 0–1 → Düşük, 2–4 → Orta, 5+ → Yüksek
enum RiskPolicy {
    static let criticalMissingPoints = 3
    static let standardMissingPoints = 1
    static let redFlagPoints = 2
    static let mediumThreshold = 2
    static let highThreshold = 5

    static func level(for score: Int) -> RiskLevel {
        switch score {
        case highThreshold...: .high
        case mediumThreshold...: .medium
        default: .low
        }
    }

    static func assess(items: [ItemResult], redFlags: [RedFlagHit]) -> (score: Int, level: RiskLevel, reasons: [String]) {
        var score = 0
        var reasons: [String] = []

        for item in items where !item.isCovered {
            let points = item.severity == .critical ? criticalMissingPoints : standardMissingPoints
            score += points
            reasons.append("\(item.severity.title) madde konuşulmadı: \(item.question) (+\(points))")
        }
        for flag in redFlags {
            score += redFlagPoints
            reasons.append("Uyarı ifadesi: \(flag.title) (+\(redFlagPoints))")
        }
        if reasons.isEmpty {
            reasons.append("Tüm maddeler konuşuldu ve uyarı ifadesi tespit edilmedi.")
        }
        return (score, level(for: score), reasons)
    }
}
