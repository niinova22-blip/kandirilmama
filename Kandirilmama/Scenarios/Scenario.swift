import Foundation

enum Severity: String, Codable, Sendable {
    case critical
    case standard

    var title: String {
        switch self {
        case .critical: "Kritik"
        case .standard: "Önemli"
        }
    }
}

/// Bir checklist maddesinin "konuşuldu" sayılması için cümle düzeyinde eşleşme kuralı.
///
/// `groups` içindeki HER grup için en az bir alternatif aynı cümlede geçmelidir.
/// Alternatifler normalize edilmiş (küçük harf, Türkçe karakterler katlanmış) yazılır:
/// - `"garant"`       → "garanti", "garantisi", "garantili" ile eşleşir (kök/önek eşleşmesi)
/// - `"=kaza"`        → yalnızca tam "kaza" kelimesi ("kazanç" eşleşmez)
/// - `"geri al"`      → art arda gelen iki kelime ("geri alır mısınız")
struct MatchRule: Sendable, Hashable {
    let groups: [[String]]

    static func any(_ alternatives: String...) -> MatchRule {
        MatchRule(groups: [alternatives])
    }

    static func all(_ groups: [String]...) -> MatchRule {
        MatchRule(groups: groups)
    }
}

struct ChecklistItem: Identifiable, Sendable {
    let id: String
    let question: String
    let severity: Severity
    let rules: [MatchRule]
    /// Foundation Models'e konuyu tarif eden kısa açıklama (yalnızca destekleyici analizde).
    let topicDescription: String
}

struct RedFlagRule: Identifiable, Sendable {
    let id: String
    let title: String
    let advice: String
    let rules: [MatchRule]
}

struct Scenario: Identifiable, Sendable {
    let id: String
    let title: String
    let subtitle: String
    let systemImage: String
    let checklist: [ChecklistItem]
    let redFlags: [RedFlagRule]
    /// UI'da gösterilip gösterilmeyeceği. Yeni senaryolar önce `false` ile eklenebilir.
    let isEnabled: Bool
}

enum ScenarioCatalog {
    static let all: [Scenario] = [.secondHandPurchase]

    static var enabled: [Scenario] {
        all.filter(\.isEnabled)
    }

    static func scenario(id: String) -> Scenario? {
        all.first { $0.id == id }
    }
}
