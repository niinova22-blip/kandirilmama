import SwiftUI

struct OnboardingView: View {
    let onFinish: () -> Void

    @State private var page = 0
    @State private var isRequesting = false
    @State private var permissionDenied = false
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                OnboardingPage(
                    systemImage: "waveform.badge.mic",
                    title: "Bu uygulama görüşmenizi KAYDEDER",
                    lines: [
                        "\"Görüşmeyi Başlat\" dediğinizde mikrofon konuşmayı dinler ve metne çevirir.",
                        "Kayıt sürdükçe ekranda sürekli kırmızı \"KAYITTA\" göstergesi görünür.",
                        "Görüşme bitince sorulmayan kritik soruları ve şüpheli ifadeleri gösterir.",
                    ]
                )
                .tag(0)

                OnboardingPage(
                    systemImage: "lock.iphone",
                    title: "Her şey bu cihazda kalır",
                    lines: [
                        "Ses ve metin hiçbir sunucuya gönderilmez; uygulama internet kullanmaz.",
                        "Kayıtlar yalnızca bu cihazda saklanır, iCloud ile eşitlenmez ve istediğiniz an silinebilir.",
                        "Karşı tarafı görüşmenin kaydedildiğinden haberdar edin. Kayıt yapmak yasal sorumluluğunuzdadır.",
                    ]
                )
                .tag(1)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            VStack(spacing: 12) {
                if permissionDenied {
                    Text("İzin verilmedi. Kayıt için Ayarlar'dan mikrofon ve konuşma tanıma izni vermelisiniz.")
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                    Button("Ayarları Aç") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            openURL(url)
                        }
                    }
                    Button("Yine de devam et", action: onFinish)
                        .font(.footnote)
                } else if page == 0 {
                    Button {
                        withAnimation { page = 1 }
                    } label: {
                        Text("Devam").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                } else {
                    Button {
                        Task { await requestPermissions() }
                    } label: {
                        Text("Anladım, izinleri ver").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(isRequesting)
                }
            }
            .padding(24)
        }
    }

    private func requestPermissions() async {
        isRequesting = true
        let granted = await PermissionManager.requestAll()
        isRequesting = false
        if granted {
            onFinish()
        } else {
            permissionDenied = true
        }
    }
}

private struct OnboardingPage: View {
    let systemImage: String
    let title: String
    let lines: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Spacer()
            Image(systemName: systemImage)
                .font(.system(size: 56))
                .foregroundStyle(.tint)
            Text(title)
                .font(.largeTitle.bold())
            ForEach(lines, id: \.self) { line in
                Label {
                    Text(line)
                } icon: {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.tint)
                }
                .font(.body)
            }
            Spacer()
            Spacer()
        }
        .padding(.horizontal, 28)
    }
}
