import XCTest
@testable import Kandirilmama

final class TextNormalizerTests: XCTestCase {
    func testTurkishCaseAndFolding() {
        XCTAssertEqual(TextNormalizer.normalize("İADE Şartı, ÇOK önemli!"), "iade sarti cok onemli")
        XCTAssertEqual(TextNormalizer.normalize("IŞIK"), "isik")
    }

    func testSegmenterSplitsLongUnpunctuatedText() {
        let words = (1...70).map { "k\($0)" }.joined(separator: " ")
        let sentences = TranscriptSegmenter.sentences(from: words, maxWords: 30, overlap: 5)
        XCTAssertGreaterThan(sentences.count, 2)
        XCTAssertTrue(sentences.allSatisfy { $0.split(separator: " ").count <= 30 })
    }

    /// Kurallardaki tüm kalıplar zaten normalize biçimde yazılmış olmalı;
    /// aksi halde (ör. "garanti" yerine "Garanti" ya da "arıza") hiç eşleşmezler.
    func testAllScenarioPatternsAreNormalized() {
        for scenario in ScenarioCatalog.all {
            let rules = scenario.checklist.flatMap(\.rules) + scenario.redFlags.flatMap(\.rules)
            for phrase in rules.flatMap({ $0.groups.flatMap { $0 } }) {
                let raw = phrase.replacingOccurrences(of: "=", with: "")
                XCTAssertEqual(TextNormalizer.normalize(raw), raw, "Normalize edilmemiş kalıp: \(phrase)")
            }
        }
    }
}

final class RuleEngineTests: XCTestCase {
    private let scenario = Scenario.secondHandPurchase

    private func item(_ id: String, in report: AnalysisReport) -> ItemResult {
        report.items.first { $0.itemID == id }!
    }

    func testWarrantyDetectedWithSuffix() {
        let report = RuleEngine.evaluate(transcript: "Telefonun garantisi kaç ay kaldı?", scenario: scenario)
        XCTAssertTrue(item("warranty", in: report).isCovered)
        XCTAssertEqual(item("warranty", in: report).source, .rule)
    }

    func testDamageDetectedWithTurkishCharacters() {
        let report = RuleEngine.evaluate(transcript: "Araçta daha önce bir arıza oldu mu?", scenario: scenario)
        XCTAssertTrue(item("damage-history", in: report).isCovered)
    }

    func testKazancDoesNotCountAsAccident() {
        let report = RuleEngine.evaluate(transcript: "Bu satıştan kazancım az.", scenario: scenario)
        XCTAssertFalse(item("damage-history", in: report).isCovered)
    }

    func testPriceAloneIsNotARationale() {
        let report = RuleEngine.evaluate(transcript: "Fiyatı on beş bin lira.", scenario: scenario)
        XCTAssertFalse(item("price-rationale", in: report).isCovered)
    }

    func testPriceWithReasonIsCovered() {
        let report = RuleEngine.evaluate(transcript: "Fiyat neden bu kadar yüksek?", scenario: scenario)
        XCTAssertTrue(item("price-rationale", in: report).isCovered)
    }

    func testReturnPolicyMultiWordPhrase() {
        let report = RuleEngine.evaluate(transcript: "Beğenmezsem geri alır mısınız?", scenario: scenario)
        XCTAssertTrue(item("return-policy", in: report).isCovered)
    }

    func testRedFlagPrepayment() {
        let report = RuleEngine.evaluate(transcript: "Önce kapora gönderirseniz ayırırım.", scenario: scenario)
        XCTAssertEqual(report.redFlags.map(\.flagID), ["prepayment"])
    }

    func testRedFlagNoPaperwork() {
        let report = RuleEngine.evaluate(transcript: "Faturası yok ama sağlam.", scenario: scenario)
        XCTAssertTrue(report.redFlags.contains { $0.flagID == "no-paperwork" })
    }

    func testEmptyTranscriptIsHighRisk() {
        let report = RuleEngine.evaluate(transcript: "", scenario: scenario)
        XCTAssertTrue(report.items.allSatisfy { !$0.isCovered })
        XCTAssertEqual(report.riskScore, 3 + 3 + 1 + 1)
        XCTAssertEqual(report.riskLevel, .high)
        XCTAssertTrue(report.isTranscriptTooShort)
    }

    func testFullyCoveredConversationIsLowRisk() {
        let transcript = """
        Garantisi var mı, kaç ay kaldı? Evet altı ay garantisi var. \
        Daha önce hasar kaydı ya da arıza oldu mu? Hayır, sadece bakım yapıldı. \
        Fiyat neden piyasanın üstünde? Çünkü yeni lastik takıldı. \
        Sorun çıkarsa iade edebilir miyim? Bir hafta içinde iade kabul ederim.
        """
        let report = RuleEngine.evaluate(transcript: transcript, scenario: scenario)
        XCTAssertTrue(report.items.allSatisfy(\.isCovered))
        XCTAssertTrue(report.redFlags.isEmpty)
        XCTAssertEqual(report.riskLevel, .low)
    }

    func testOneCriticalMissingIsMediumRisk() {
        let transcript = "Arıza var mı? Yok. Fiyat neden böyle? Piyasa bu. İade olur mu? Olur."
        let report = RuleEngine.evaluate(transcript: transcript, scenario: scenario)
        XCTAssertFalse(item("warranty", in: report).isCovered)
        XCTAssertEqual(report.riskScore, 3)
        XCTAssertEqual(report.riskLevel, .medium)
    }
}

final class ModelMergeTests: XCTestCase {
    private let scenario = Scenario.secondHandPurchase

    func testVerbatimQuoteIsAccepted() {
        let transcript = "Ürünün resmi güvencesi on iki ay daha devam ediyor."
        let base = RuleEngine.evaluate(transcript: transcript, scenario: scenario)
        XCTAssertFalse(base.items.first { $0.itemID == "warranty" }!.isCovered)

        let merged = RuleEngine.merging(
            verifiedQuotes: ["warranty": "resmi güvencesi on iki ay"],
            into: base,
            transcript: transcript,
            note: nil
        )
        let warranty = merged.items.first { $0.itemID == "warranty" }!
        XCTAssertTrue(warranty.isCovered)
        XCTAssertEqual(warranty.source, .verifiedModel)
        XCTAssertLessThan(merged.riskScore, base.riskScore)
    }

    func testHallucinatedQuoteIsRejected() {
        let transcript = "Ürün çok temiz, kutusu da duruyor."
        let base = RuleEngine.evaluate(transcript: transcript, scenario: scenario)
        let merged = RuleEngine.merging(
            verifiedQuotes: ["warranty": "iki yıl garantisi var"],
            into: base,
            transcript: transcript,
            note: nil
        )
        XCTAssertFalse(merged.items.first { $0.itemID == "warranty" }!.isCovered)
        XCTAssertEqual(merged.riskScore, base.riskScore)
    }

    func testTooShortQuoteIsRejected() {
        XCTAssertFalse(QuoteVerifier.isVerbatim("garanti", in: "garanti var"))
    }
}
