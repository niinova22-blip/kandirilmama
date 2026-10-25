import SwiftUI

struct ResultView: View {
    static let disclaimer = "Bu araç destek amaçlıdır, hukuki garanti sağlamaz"

    let record: ConversationRecord

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var isConfirmingDelete = false

    var body: some View {
        content
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .destructive) {
                        isConfirmingDelete = true
                    } label: {
                        Image(systemName: "trash")
                    }
                    .accessibilityLabel("Görüşmeyi sil")
                }
            }
            .confirmationDialog("Bu görüşme ve transkripti kalıcı olarak silinsin mi?",
                                isPresented: $isConfirmingDelete,
                                titleVisibility: .visible) {
                Button("Sil", role: .destructive) {
                    modelContext.delete(record)
                    try? modelContext.save()
                    dismiss()
                }
            }
    }

    private var content: some View {
        List {
            if let report = record.report {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        RiskBadge(level: report.riskLevel, compact: false)
                        Text("Risk puanı: \(report.riskScore)")
                            .font(.subheadline.weight(.semibold))
                        ForEach(report.riskReasons, id: \.self) { reason in
                            Text("• \(reason)")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                } footer: {
                    Text("Puanlama: konuşulmamış kritik madde +\(RiskPolicy.criticalMissingPoints), önemli madde +\(RiskPolicy.standardMissingPoints), uyarı ifadesi +\(RiskPolicy.redFlagPoints). 0–1 düşük, 2–4 orta, 5+ yüksek.")
                }

                if report.isTranscriptTooShort {
                    Section {
                        Label("Transkript çok kısa (\(report.wordCount) kelime). Sonuçlar güvenilir olmayabilir.",
                              systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                    }
                }

                Section("Kontrol listesi") {
                    ForEach(report.items) { item in
                        ChecklistRow(item: item)
                    }
                }

                if !report.redFlags.isEmpty {
                    Section("Dikkat edilmesi gereken ifadeler") {
                        ForEach(report.redFlags) { flag in
                            RedFlagRow(flag: flag)
                        }
                    }
                }

                Section("Analiz yöntemi") {
                    Text(report.analysisNote ?? "Kural motoru (anahtar ifade eşleştirme)")
                        .font(.footnote)
                    Text("Konuşmacılar ayırt edilemez; ifadeler kimin söylediğinden bağımsız değerlendirilir.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Analiz sonucu okunamadı.")
            }

            Section("Transkript") {
                DisclosureGroup("Tam metni göster") {
                    Text(record.transcript.isEmpty ? "(Boş)" : record.transcript)
                        .font(.callout)
                        .textSelection(.enabled)
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            Text(Self.disclaimer)
                .font(.footnote.weight(.semibold))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(12)
                .background(.thinMaterial)
        }
    }
}

private struct ChecklistRow: View {
    let item: ItemResult

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Image(systemName: item.isCovered ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(item.isCovered ? .green : .red)
                Text(item.question)
                    .font(.subheadline.weight(.medium))
                Spacer()
                Text(item.severity.title)
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(item.severity == .critical ? Color.red.opacity(0.15) : Color.gray.opacity(0.15),
                                in: Capsule())
            }
            if let evidence = item.evidence {
                Text("“\(evidence)”")
                    .font(.caption)
                    .italic()
                    .foregroundStyle(.secondary)
                if item.source == .verifiedModel {
                    Label("Apple Intelligence buldu · alıntı doğrulandı", systemImage: "sparkles")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Bu konu görüşmede geçmedi. Karar vermeden önce sorun.")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(.vertical, 2)
    }
}

private struct RedFlagRow: View {
    let flag: RedFlagHit

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(flag.title, systemImage: "exclamationmark.triangle.fill")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.orange)
            Text("“\(flag.evidence)”")
                .font(.caption)
                .italic()
                .foregroundStyle(.secondary)
            Text(flag.advice)
                .font(.caption)
        }
        .padding(.vertical, 2)
    }
}

struct RiskBadge: View {
    let level: RiskLevel
    let compact: Bool

    private var color: Color {
        switch level {
        case .low: .green
        case .medium: .orange
        case .high: .red
        }
    }

    private var icon: String {
        switch level {
        case .low: "checkmark.shield.fill"
        case .medium: "exclamationmark.shield.fill"
        case .high: "xmark.shield.fill"
        }
    }

    var body: some View {
        Label(level.title, systemImage: icon)
            .font(compact ? .caption.weight(.semibold) : .title2.weight(.bold))
            .foregroundStyle(color)
            .padding(.horizontal, compact ? 8 : 0)
            .padding(.vertical, compact ? 4 : 0)
            .background(compact ? color.opacity(0.12) : .clear, in: Capsule())
    }
}
