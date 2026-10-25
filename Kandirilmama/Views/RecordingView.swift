import AVFoundation
import SwiftData
import SwiftUI

struct RecordingView: View {
    let scenario: Scenario

    private enum Phase {
        case ready
        case recording(startedAt: Date)
        case analyzing
        case done(ConversationRecord)
    }

    @Environment(\.modelContext) private var modelContext
    @State private var transcriber = LiveTranscriber()
    @State private var phase: Phase = .ready
    @State private var startError: String?

    var body: some View {
        Group {
            switch phase {
            case .ready:
                readyView
            case .recording(let startedAt):
                recordingView(startedAt: startedAt)
            case .analyzing:
                ProgressView("Görüşme analiz ediliyor…")
                    .controlSize(.large)
            case .done(let record):
                ResultView(record: record)
            }
        }
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(isBusy)
        .onChange(of: transcriber.isRecording) { _, isRecording in
            // Tanıma kendiliğinden durduysa (art arda hata) eldeki metinle analize geç.
            if !isRecording, case .recording(let startedAt) = phase {
                Task { await finish(startedAt: startedAt) }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification)) { _ in
            // Telefon araması vb. kesinti → kaydı güvenle bitir.
            if case .recording(let startedAt) = phase {
                Task { await finish(startedAt: startedAt) }
            }
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }

    private var isBusy: Bool {
        switch phase {
        case .recording, .analyzing: true
        default: false
        }
    }

    private var navigationTitle: String {
        if case .done = phase { return "Sonuç" }
        return scenario.title
    }

    // MARK: - Hazır

    private var readyView: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "mic.circle")
                .font(.system(size: 80))
                .foregroundStyle(.tint)
            Text("Görüşme başladığında butona basın. Konuşma bu cihazda metne çevrilecek.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            if let startError {
                Text(startError)
                    .font(.callout)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
            Spacer()
            Button(action: start) {
                Label("Görüşmeyi Başlat", systemImage: "record.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .controlSize(.large)
        }
        .padding(24)
    }

    // MARK: - Kayıtta

    private func recordingView(startedAt: Date) -> some View {
        VStack(spacing: 0) {
            RecordingIndicator(startedAt: startedAt)

            ScrollViewReader { proxy in
                ScrollView {
                    Text(transcriber.displayText.isEmpty ? "Dinleniyor…" : transcriber.displayText)
                        .font(.body)
                        .foregroundStyle(transcriber.displayText.isEmpty ? .secondary : .primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                    Color.clear.frame(height: 1).id("bottom")
                }
                .onChange(of: transcriber.displayText) {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }

            Button {
                Task { await finish(startedAt: startedAt) }
            } label: {
                Label("Durdur", systemImage: "stop.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(24)
        }
    }

    // MARK: - Akış

    private func start() {
        do {
            try transcriber.start()
            startError = nil
            UIApplication.shared.isIdleTimerDisabled = true
            phase = .recording(startedAt: Date())
        } catch {
            startError = error.localizedDescription
        }
    }

    private func finish(startedAt: Date) async {
        guard case .recording = phase else { return }
        phase = .analyzing
        UIApplication.shared.isIdleTimerDisabled = false

        let transcript = await transcriber.stop()
        let report = await ConversationAnalyzer.analyze(transcript: transcript, scenario: scenario)
        let record = ConversationRecord(
            createdAt: startedAt,
            duration: Date().timeIntervalSince(startedAt),
            scenarioID: scenario.id,
            transcript: transcript,
            report: report
        )
        modelContext.insert(record)
        try? modelContext.save()
        phase = .done(record)
    }
}

/// Kayıt boyunca ekranın üstünde sabit duran kırmızı gösterge.
private struct RecordingIndicator: View {
    let startedAt: Date
    @State private var pulse = false

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(.white)
                .frame(width: 12, height: 12)
                .opacity(pulse ? 0.3 : 1)
            Text("KAYITTA")
                .font(.headline.weight(.heavy))
            Spacer()
            TimelineView(.periodic(from: startedAt, by: 1)) { context in
                Text(Duration.seconds(context.date.timeIntervalSince(startedAt)).formatted(.time(pattern: .minuteSecond)))
                    .font(.headline.monospacedDigit())
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.red)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Kayıt devam ediyor")
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8).repeatForever()) {
                pulse = true
            }
        }
    }
}
