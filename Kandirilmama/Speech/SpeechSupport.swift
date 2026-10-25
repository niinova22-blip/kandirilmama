import AVFoundation
import Speech

enum SpeechSupport {
    static let locale = Locale(identifier: "tr-TR")

    enum Status: Equatable {
        case ready
        case localeUnsupported
        case onDeviceUnavailable

        var warning: String? {
            switch self {
            case .ready:
                nil
            case .localeUnsupported:
                "Bu cihaz Türkçe konuşma tanımayı desteklemiyor. Uygulama kayıt yapamaz."
            case .onDeviceUnavailable:
                """
                Bu cihazda Türkçe için CİHAZ ÜZERİNDE konuşma tanıma kullanılamıyor. \
                Gizlilik gereği uygulama sesinizi sunucuya göndermez, bu yüzden kayıt yapılamaz. \
                Ayarlar › Genel › Klavye › Dikte bölümünde Türkçe dikteyi açıp \
                dil paketinin indirilmesini bekleyin ve tekrar deneyin.
                """
            }
        }
    }

    static func check() -> Status {
        guard let recognizer = SFSpeechRecognizer(locale: locale) else {
            return .localeUnsupported
        }
        guard recognizer.supportsOnDeviceRecognition else {
            return .onDeviceUnavailable
        }
        return .ready
    }
}

enum PermissionManager {
    static var isMicrophoneGranted: Bool {
        AVAudioApplication.shared.recordPermission == .granted
    }

    static var isSpeechGranted: Bool {
        SFSpeechRecognizer.authorizationStatus() == .authorized
    }

    static var allGranted: Bool {
        isMicrophoneGranted && isSpeechGranted
    }

    /// - Returns: Her iki izin de verildiyse `true`.
    static func requestAll() async -> Bool {
        let microphone = await AVAudioApplication.requestRecordPermission()
        let speech = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
        return microphone && speech
    }
}
