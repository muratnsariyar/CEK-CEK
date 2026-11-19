# ÇEK ÇEK

> **“Zamanı gelince silinecekler varsa ÇEK ÇEK burada!”**

**ÇEK ÇEK**, iş yeri evrakları, kargo fişleri, tahta notları veya geçici görselleri kişisel Fotoğraflar galerinizi kirletmeden çekmenizi ve belirlediğiniz süre sonunda otomatik olarak temizlemenizi sağlayan bir iOS uygulamasıdır.

## Özellikler

- **İzole Kamera (Fotoğraf & Video)**: `AVFoundation` ile doğrudan uygulama içinden fotoğraf ve video çeker; iOS Fotoğraflar galerisine kaydetmez.
- **Esnek Süre Seçimi & Otomatik Temizlik**:
  - Ücretsiz sürümde varsayılan `1 Gün`, `7 Gün`, `30 Gün` hızlı süre seçenekleri.
  - **Pro Paket** ile Apple Saat/Takvim tarzı kaydırmalı sayaç (Gün / Saat / Dakika) üzerinden süreleri özelleştirme ve 3 ile 5 arasında süre yuvası belirleme.
  - En son seçilen süreyi otomatik hatırlama ve süresi dolan medyaları uygulama açılışında / arka planda (`BGAppRefreshTask`) otomatik silme.
- **Canlı Metin (Live Text) & QR Okuyucu**:
  - Apple Fotoğraflar deneyimiyle fotoğraf üzerindeki yazıları doğrudan ekrandan basılı tutarak seçme, kopyalama ve QR kod / bağlantıları algılama (`VisionKit` & `Vision`).
- **Apple Fotoğraflar Tarzı Önizleme**:
  - Tam ekran medya inceleme, çift dokunuşla yakınlaştırma, aşağı sürükleyerek kapatma (swipe-down to dismiss) ve iOS Fotoğraflar benzeri bilgi/not paneli.
- **50 Aktif Medya Reklamsız Kota**:
  - Kasada aktif 50 medyaya kadar tamamen reklamsız kullanım; medyalar silindikçe kota otomatik yenilenir (`50/50`).
- **Klasörler & Kategoriler**: `Genel`, `İş`, `Fiş & Evrak`, `Hızlı Not` hazır klasörleri ve özel klasör oluşturma desteği.
- **Paylaşım, Kurtarma & Geliştiriciye Bildir**: WhatsApp/Mail/AirDrop paylaşımı, süre uzatma, kişisel Fotoğraflar galerisine kalıcı aktarma ve uygulama içi geliştirici geri bildirim ekranı.
- **Gizlilik Kilidi**: İsteğe bağlı Face ID / Touch ID / Cihaz Parolası ile uygulama kilidi.

## Teknolojiler

- **iOS 17+**
- **SwiftUI** + **SwiftData**
- **AVFoundation**, **AVKit**, **VisionKit** (`ImageAnalyzer`), **Vision**
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
