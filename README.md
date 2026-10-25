# Kandırılmama (MVP)

Görüşmeleri **tamamen cihaz üzerinde** metne çeviren, sonra sorulmayan kritik soruları ve şüpheli ifadeleri gösteren iOS uygulaması. Ağ isteği, backend, analytics ve harici paket yok.

## Mimari

| Katman | Teknoloji | Not |
|---|---|---|
| Konuşma tanıma | `SFSpeechRecognizer`, `tr-TR`, `requiresOnDeviceRecognition = true` | Cihaz desteklemiyorsa kayıt engellenir, kullanıcı uyarılır |
| Analiz (asıl karar) | Kural motoru (`Analysis/RuleEngine.swift`) | Deterministik, her cihazda aynı sonuç (iOS 17+, iPhone 11 dahil) |
| Analiz (destek) | Foundation Models, yalnızca iOS 26+ ve Apple Intelligence açık | Sadece eksik maddelere bakar; birebir alıntı doğrulanmazsa sonuç reddedilir |
| Risk | `RiskPolicy` puan tablosu | Model risk belirlemez |
| Veri | SwiftData, `cloudKitDatabase: .none`, yedekten hariç | Veri cihazdan çıkmaz |

Analiz yalnızca görüşme bitince, bir kez çalışır.

## Yeni senaryo eklemek

`Scenarios/` altına `SecondHandScenario.swift` örneğindeki gibi bir `Scenario` tanımlayın ve `ScenarioCatalog.all` listesine ekleyin. Sadece `isEnabled: true` olanlar arayüzde görünür.

Kalıplar normalize edilmiş biçimde yazılır: küçük harf, `ş→s`, `ı→i` vb. Varsayılan eşleşme önek eşleşmesidir (`"garant"`). Kelimenin tam eşleşmesi için başına `=` konur (`"=kaza"`). `.all([...], [...])` kullanıldığında her gruptan en az bir ifadenin aynı cümlede geçmesi gerekir.

## Derleme (GitHub Actions)

Mac gerekmez. `main` dalına her push'ta `.github/workflows/ios.yml` sırasıyla şunları yapar:
1. `scripts/check-no-network.sh` ile kodda ağ API'si, harici paket veya iCloud entitlement olup olmadığını denetler.
2. XcodeGen ile `project.yml` dosyasından Xcode projesini üretir.
3. Birim testlerini simülatörde çalıştırır.
4. İmzasız bir `.ipa` üretir ve workflow çıktısı (artifact) olarak yükler.

### TestFlight (iPhone'a yükleme)

`.github/workflows/testflight.yml` elle tetiklenir. Uygulamayı otomatik imzalayıp (sertifikaları Apple bulutta yönetir) TestFlight'a yükler. Tek seferlik kurulum:

1. **Bundle ID:** developer.apple.com › Certificates, Identifiers & Profiles › Identifiers bölümünden bir App ID kaydedin (ör. `com.<adınız>.kandirilmama`). Ek capability gerekmez.
2. **Uygulama kaydı:** App Store Connect › Apps › "+" › New App ile bu bundle ID'yi seçerek uygulamayı oluşturun.
3. **API anahtarı:** App Store Connect › Users and Access › Integrations › App Store Connect API bölümünden **Admin** rolüyle bir anahtar oluşturun ve `.p8` dosyasını indirin (yalnızca bir kez indirilebilir).
4. **GitHub ayarları:**
   ```sh
   gh secret set APPLE_TEAM_ID          # Membership sayfasındaki 10 karakterlik Team ID
   gh secret set ASC_KEY_ID             # API anahtarının Key ID'si
   gh secret set ASC_ISSUER_ID          # API sayfasının üstündeki Issuer ID
   gh secret set ASC_PRIVATE_KEY < AuthKey_XXXX.p8
   gh variable set BUNDLE_ID --body "com.<adınız>.kandirilmama"
   ```
5. Actions › TestFlight › **Run workflow**. Build birkaç dakika içinde TestFlight'ta görünür. iPhone'a TestFlight uygulamasından kurulur.

İmzasız IPA'yı geliştirici hesabı olmadan denemek isterseniz Sideloadly veya AltStore kullanılabilir (7 günde bir yeniden imzalama gerekir).

## Bilinen sınırlamalar

- Konuşmacı ayrımı yok. Bir ifadeyi alıcı da söylese satıcı da söylese aynı şekilde değerlendirilir.
- Ekran kilitlenirse kayıt durur. Bu yüzden kayıt sırasında ekranın otomatik kilitlenmesi kapatılır.
- Kural kalıpları ilk sürüm. Gerçek görüşme transkriptleriyle genişletilmeli.
