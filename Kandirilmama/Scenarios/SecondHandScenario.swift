import Foundation

extension Scenario {
    static let secondHandPurchase = Scenario(
        id: "second-hand-purchase",
        title: "İkinci El Eşya/Araç Alışverişi",
        subtitle: "Garanti, hasar geçmişi, fiyat ve iade koşullarını kaçırmayın",
        systemImage: "car.side",
        checklist: [
            ChecklistItem(
                id: "warranty",
                question: "Garanti süresi soruldu mu?",
                severity: .critical,
                rules: [
                    .any("garant"),
                    .any("teminat"),
                ],
                topicDescription: "Ürünün garantisi, garanti süresi veya garanti kapsamı"
            ),
            ChecklistItem(
                id: "damage-history",
                question: "Hasar/arıza geçmişi konuşuldu mu?",
                severity: .critical,
                rules: [
                    .any("hasar", "ariza", "tramer", "degisen", "boya", "tamir", "bozuk", "bozul",
                         "kusur", "cizik", "kirik", "darbe", "ekspertiz", "onarim"),
                    .any("=kaza", "kazali", "kazasi", "kazaya", "kazada", "kazadan"),
                ],
                topicDescription: "Hasar kaydı, kaza, arıza, tamir, boya/değişen parça veya kusur geçmişi"
            ),
            ChecklistItem(
                id: "price-rationale",
                question: "Fiyatın gerekçesi netleşti mi?",
                severity: .standard,
                rules: [
                    // Yalnızca fiyatın söylenmesi yetmez; aynı cümlede gerekçe de geçmeli.
                    .all(["fiyat", "ucret", "para", "=tl", "lira", "bin"],
                         ["neden", "niye", "nicin", "sebeb", "sebep", "gerekce", "cunku",
                          "piyasa", "deger", "pahali", "ucuz", "emsal"]),
                ],
                topicDescription: "Fiyatın neden bu seviyede olduğu: piyasa değeri, durum, gerekçe veya karşılaştırma"
            ),
            ChecklistItem(
                id: "return-policy",
                question: "İade/cayma koşulu konuşuldu mu?",
                severity: .standard,
                rules: [
                    .any("iade", "cayma", "vazgec", "iptal", "geri al", "geri ver", "geri veril",
                         "degisim", "geri odeme"),
                ],
                topicDescription: "Ürünün iadesi, cayma hakkı, vazgeçme veya değişim koşulları"
            ),
        ],
        redFlags: [
            RedFlagRule(
                id: "pressure",
                title: "Acele/baskı ifadesi",
                advice: "Karar için baskı kurulmuş olabilir. Acele etmeyin, düşünmek için zaman isteyin.",
                rules: [
                    .any("baska alici", "hemen karar", "bugun son", "acele", "kacirirsin",
                         "kacirirsiniz", "son firsat"),
                ]
            ),
            RedFlagRule(
                id: "prepayment",
                title: "Ön ödeme/kapora talebi",
                advice: "Ürünü görmeden ve belgeleri kontrol etmeden ödeme yapmayın.",
                rules: [
                    .any("kapora", "on odeme", "pesinat", "onceden gonder", "once para",
                         "once odeme", "havale yap"),
                ]
            ),
            RedFlagRule(
                id: "no-paperwork",
                title: "Belge/fatura eksikliği",
                advice: "Faturası, ruhsatı veya noter satışı olmayan işlemler ciddi risk taşır.",
                rules: [
                    .all(["fatura", "noter", "belge", "ruhsat", "sozlesme", "evrak"],
                         ["=yok", "gerek yok", "gerekmez", "olmaz", "olmadan"]),
                    .any("faturasiz", "belgesiz", "senetsiz"),
                ]
            ),
            RedFlagRule(
                id: "absolute-claim",
                title: "Kesin/abartılı iddia",
                advice: "\"Hiç sorunu yok\" gibi iddiaları ekspertiz veya servis kaydıyla doğrulayın.",
                rules: [
                    .any("sifir gibi", "hic sorun", "hic hasar", "hic ariza", "hic boya", "tertemiz",
                         "kusursuz", "jilet gibi"),
                ]
            ),
            RedFlagRule(
                id: "skip-inspection",
                title: "Kontrolden kaçınma",
                advice: "Bağımsız ekspertiz/servis kontrolünü reddeden satıcıya karşı dikkatli olun.",
                rules: [
                    .all(["ekspertiz", "kontrol", "usta", "servis", "test"],
                         ["gerek yok", "gerekmez", "gerek kalmaz", "lazim degil", "yaptirma"]),
                ]
            ),
        ],
        isEnabled: true
    )
}
