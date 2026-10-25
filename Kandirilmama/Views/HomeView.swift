import SwiftData
import SwiftUI

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ConversationRecord.createdAt, order: .reverse) private var records: [ConversationRecord]

    @State private var speechStatus = SpeechSupport.check()
    @State private var permissionsGranted = PermissionManager.allGranted
    @Environment(\.scenePhase) private var scenePhase

    private var canRecord: Bool {
        speechStatus == .ready && permissionsGranted
    }

    var body: some View {
        NavigationStack {
            List {
                if let warning = blockingWarning {
                    Section {
                        Label(warning, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                            .font(.callout)
                    }
                }

                Section("Senaryo seçin") {
                    ForEach(ScenarioCatalog.enabled) { scenario in
                        NavigationLink {
                            RecordingView(scenario: scenario)
                        } label: {
                            ScenarioRow(scenario: scenario)
                        }
                        .disabled(!canRecord)
                    }
                }

                Section {
                    Label(AnalysisCapability.statusText, systemImage: "cpu")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Label("Çevrimdışı çalışır · Veriler yalnızca bu cihazda", systemImage: "airplane")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if !records.isEmpty {
                    Section("Geçmiş görüşmeler") {
                        ForEach(records) { record in
                            NavigationLink {
                                ResultView(record: record)
                            } label: {
                                HistoryRow(record: record)
                            }
                        }
                        .onDelete(perform: delete)
                    }
                }
            }
            .navigationTitle("Kandırılmama")
        }
        .onChange(of: scenePhase) { _, phase in
            // Kullanıcı Ayarlar'dan izin verip dönmüş olabilir.
            if phase == .active {
                speechStatus = SpeechSupport.check()
                permissionsGranted = PermissionManager.allGranted
            }
        }
    }

    private var blockingWarning: String? {
        if let warning = speechStatus.warning { return warning }
        if !permissionsGranted { return TranscriberError.permissionsMissing.errorDescription }
        return nil
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(records[index])
        }
        try? modelContext.save()
    }
}

private struct ScenarioRow: View {
    let scenario: Scenario

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: scenario.systemImage)
                .font(.title2)
                .foregroundStyle(.tint)
                .frame(width: 36)
            VStack(alignment: .leading, spacing: 4) {
                Text(scenario.title).font(.headline)
                Text(scenario.subtitle).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
    }
}

private struct HistoryRow: View {
    let record: ConversationRecord

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(record.scenario?.title ?? "Görüşme").font(.subheadline)
                Text(record.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let report = record.report {
                RiskBadge(level: report.riskLevel, compact: true)
            }
        }
    }
}
