# CEK CEK

**CEK CEK**, iş yeri evrakları, kargo fişleri, tahta notları veya geçici görselleri kişisel Fotoğraflar galerinizi kirletmeden çekmenizi ve belirlediğiniz süre sonunda otomatik olarak temizlemenizi sağlayan bir iOS uygulamasıdır.

## Özellikler

- **İzole Kamera (Fotoğraf & Video)**: `AVFoundation` ile doğrudan uygulama içinden fotoğraf ve video çeker; iOS Fotoğraflar galerisine kaydetmez.
- **Otomatik Süre ve Temizlik**: Çekim sırasında `6 Saat`, `1 Gün`, `3 Gün`, `7 Gün` veya `30 Gün` saklama süresi seçilebilir. Süresi dolan medyalar uygulama açılışında ve arka planda (`BGAppRefreshTask`) otomatik silinir.
- **Klasörler & Kategoriler**: `Genel`, `İş`, `Fiş & Evrak`, `Hızlı Not` hazır klasörleri ve kendi özel klasörlerinizi oluşturma desteği.
- **Paylaşım & Kurtarma**: WhatsApp/Mail/AirDrop paylaşımı, süre uzatma (veya özel tarih seçimi), istenirse tek dokunuşla kişisel Fotoğraflar galerisine kalıcı aktarma.
- **Hatırlatma Bildirimleri**: Süresi dolmak üzere olan medyalar için silinmeden 3/6/12/24 saat önce yerel bildirim.
- **Gizlilik Kilidi**: İsteğe bağlı Face ID / Touch ID / Cihaz Parolası ile uygulama kilidi.
- **Simülatör Desteği**: Fiziksel kamera bulunmayan iOS Simülatör'de demo fotoğraf çekimi ve görsel aktarma desteği.

## Teknolojiler

- **iOS 17+**
- **SwiftUI** + **SwiftData**
- **AVFoundation** & **AVKit**
- **BackgroundTasks**, **UserNotifications**, **Photos**, **LocalAuthentication**

## Kurulum ve Çalıştırma

1. Depoyu klonlayın:
   ```bash
   git clone https://github.com/muratnsariyar/CEK-CEK.git
   cd CEK-CEK
   ```
2. `CEK-CEK.xcodeproj` dosyasını Xcode ile açın.
3. Gerçek bir iPhone'da çalıştırmak için **Signing & Capabilities** sekmesinden kendi Apple Development Team hesabınızı seçin.
4. `Cmd + R` ile iOS Simülatör veya fiziksel cihazda çalıştırın.
