import AVFoundation
import Observation
import Speech

enum TranscriberError: LocalizedError {
    case onDeviceUnavailable
    case permissionsMissing
    case noMicrophoneInput

    var errorDescription: String? {
        switch self {
        case .onDeviceUnavailable:
            SpeechSupport.Status.onDeviceUnavailable.warning
        case .permissionsMissing:
            "Mikrofon ve konuşma tanıma izinleri gerekli. Ayarlar'dan izin verebilirsiniz."
        case .noMicrophoneInput:
            "Mikrofon girişi bulunamadı."
        }
    }
}

/// Ses tamponlarını audio thread'inden o anki tanıma isteğine aktarır.
private final class AudioRequestBox: @unchecked Sendable {
    private let lock = NSLock()
    private var request: SFSpeechAudioBufferRecognitionRequest?

    func set(_ request: SFSpeechAudioBufferRecognitionRequest?) {
        lock.lock()
        self.request = request
        lock.unlock()
    }

    func append(_ buffer: AVAudioPCMBuffer) {
        lock.lock()
        let current = request
        lock.unlock()
        current?.append(buffer)
    }
}

/// Cihaz üzerinde (requiresOnDeviceRecognition = true) canlı transkripsiyon.
///
/// Tanıma görevi sessizlikte veya belirli bir süre sonunda kendini bitirebilir;
/// bu durumda metin kaydedilir ve ses motoru durmadan yeni bir segment başlatılır.
@MainActor
@Observable
final class LiveTranscriber {
    private(set) var committedText = ""
    private(set) var partialText = ""
    private(set) var isRecording = false
    private(set) var errorMessage: String?

    var displayText: String {
        [committedText, partialText].filter { !$0.isEmpty }.joined(separator: " ")
    }

    private let audioEngine = AVAudioEngine()
    private let recognizer = SFSpeechRecognizer(locale: SpeechSupport.locale)
    private let requestBox = AudioRequestBox()
    @ObservationIgnored private var currentRequest: SFSpeechAudioBufferRecognitionRequest?
    @ObservationIgnored private var currentTask: SFSpeechRecognitionTask?
    @ObservationIgnored private var segmentID = 0
    @ObservationIgnored private var segmentFinished = true
    @ObservationIgnored private var segmentStartedAt = Date()
    @ObservationIgnored private var rapidFailures = 0

    func start() throws {
        guard !isRecording else { return }
        guard PermissionManager.allGranted else { throw TranscriberError.permissionsMissing }
        guard let recognizer, recognizer.supportsOnDeviceRecognition else {
            throw TranscriberError.onDeviceUnavailable
        }

        committedText = ""
        partialText = ""
        errorMessage = nil
        rapidFailures = 0

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: [])
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        let input = audioEngine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            throw TranscriberError.noMicrophoneInput
        }

        input.installTap(onBus: 0, bufferSize: 1024, format: format, block: Self.makeTapBlock(box: requestBox))
        audioEngine.prepare()
        startSegment(with: recognizer)

        do {
            try audioEngine.start()
        } catch {
            tearDownAudio()
            throw error
        }
        isRecording = true
    }

    /// Kaydı durdurur, son segmentin kesinleşmesini kısa süre bekler ve tam metni döndürür.
    func stop() async -> String {
        guard isRecording else { return committedText }
        isRecording = false
        tearDownAudio()

        // Son sonucun gelmesi için en fazla ~3 sn bekle (ana thread bloklanmaz).
        for _ in 0..<30 where !segmentFinished {
            try? await Task.sleep(for: .milliseconds(100))
        }
        if !segmentFinished {
            currentTask?.finish()
            commitPartial()
            segmentFinished = true
        }
        currentTask = nil
        currentRequest = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        return committedText
    }

    // MARK: - Segmentler

    private func startSegment(with recognizer: SFSpeechRecognizer) {
        segmentID += 1
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = true
        request.addsPunctuation = true
        request.taskHint = .dictation

        currentRequest = request
        requestBox.set(request)
        segmentFinished = false
        segmentStartedAt = Date()
        currentTask = recognizer.recognitionTask(
            with: request,
            resultHandler: Self.makeResultHandler(owner: self, segment: segmentID)
        )
    }

    private func handleUpdate(segment: Int, text: String?, isFinal: Bool, failed: Bool) {
        guard segment == segmentID, !segmentFinished else { return }

        if let text, !text.isEmpty {
            partialText = text
            rapidFailures = 0
        }
        guard isFinal || failed else { return }

        commitPartial()
        segmentFinished = true

        // Sessizlik kaynaklı hatalar normal; yalnızca art arda anında düşen hatalar sorun.
        if failed, Date().timeIntervalSince(segmentStartedAt) < 2 {
            rapidFailures += 1
        }

        guard isRecording, let recognizer else { return }
        if rapidFailures >= 3 {
            errorMessage = "Konuşma tanıma beklenmedik şekilde durdu. Kaydedilen kısım analiz edilecek."
            isRecording = false
            tearDownAudio()
            return
        }
        startSegment(with: recognizer)
    }

    private func commitPartial() {
        let text = partialText.trimmingCharacters(in: .whitespacesAndNewlines)
        partialText = ""
        guard !text.isEmpty else { return }
        committedText = committedText.isEmpty ? text : committedText + " " + text
    }

    private func tearDownAudio() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        requestBox.set(nil)
        currentRequest?.endAudio()
    }

    // MARK: - Ana aktör dışı closure'lar
    // Bu closure'lar audio/tanıma thread'lerinde çağrılır; MainActor'a bağlı
    // olmamaları için nonisolated fabrika fonksiyonlarında oluşturulur.

    nonisolated private static func makeTapBlock(box: AudioRequestBox) -> AVAudioNodeTapBlock {
        { buffer, _ in box.append(buffer) }
    }

    nonisolated private static func makeResultHandler(
        owner: LiveTranscriber,
        segment: Int
    ) -> (SFSpeechRecognitionResult?, Error?) -> Void {
        { [weak owner] result, error in
            let text = result?.bestTranscription.formattedString
            let isFinal = result?.isFinal ?? false
            let failed = error != nil
            Task { @MainActor in
                owner?.handleUpdate(segment: segment, text: text, isFinal: isFinal, failed: failed)
            }
        }
    }
}
