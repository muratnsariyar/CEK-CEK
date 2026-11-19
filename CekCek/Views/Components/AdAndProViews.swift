import Combine
import SwiftUI

struct BrandSqueegeeBadge: View {
    var size: CGFloat = 76

    var body: some View {
        ZStack {
            // Mat antrasit / derin gece laciverti arka plan (Konsept 1)
            RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.06, green: 0.08, blue: 0.13),
                            Color(red: 0.11, green: 0.15, blue: 0.22),
                            Color(red: 0.05, green: 0.07, blue: 0.11)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)
                .shadow(color: .orange.opacity(0.28), radius: 10, y: 4)

            // Kamera gövdesi silüeti
            RoundedRectangle(cornerRadius: size * 0.11, style: .continuous)
                .fill(Color(red: 0.14, green: 0.18, blue: 0.26))
                .overlay(
                    RoundedRectangle(cornerRadius: size * 0.11, style: .continuous)
                        .stroke(Color.white.opacity(0.22), lineWidth: max(1, size * 0.012))
                )
                .frame(width: size * 0.72, height: size * 0.52)
                .offset(y: -size * 0.02)

            // Merkezde büyük optik kamera lensi
            ZStack {
                Circle()
                    .stroke(Color.orange, lineWidth: max(2, size * 0.032))
                    .frame(width: size * 0.43, height: size * 0.43)

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(red: 0.08, green: 0.32, blue: 0.54),
                                Color(red: 0.02, green: 0.06, blue: 0.14)
                            ],
                            center: .topLeading,
                            startRadius: 2,
                            endRadius: size * 0.22
                        )
                    )
                    .frame(width: size * 0.36, height: size * 0.36)

                // Lens ışık yansıması
                Ellipse()
                    .fill(Color.cyan.opacity(0.55))
                    .frame(width: size * 0.09, height: size * 0.055)
                    .offset(x: -size * 0.06, y: -size * 0.06)
            }
            .offset(y: -size * 0.02)

            // Lensin üzerinden çapraz geçen Çekçek (Squeegee)
            ZStack {
                // Çekçek sapı
                RoundedRectangle(cornerRadius: size * 0.04)
                    .fill(Color(red: 0.20, green: 0.26, blue: 0.36))
                    .frame(width: size * 0.08, height: size * 0.24)
                    .overlay(
                        RoundedRectangle(cornerRadius: size * 0.02)
                            .fill(Color.orange)
                            .frame(width: size * 0.036, height: size * 0.12)
                            .offset(y: size * 0.03)
                    )
                    .offset(y: size * 0.13)

                // Çekçek bıçağı (üstte camgöbeği silikon, altta turuncu gövde)
                VStack(spacing: 0) {
                    RoundedRectangle(cornerRadius: max(1.5, size * 0.02))
                        .fill(Color.cyan)
                        .frame(width: size * 0.80, height: max(2.5, size * 0.035))

                    RoundedRectangle(cornerRadius: max(2, size * 0.028))
                        .fill(
                            LinearGradient(
                                colors: [.orange, Color(red: 0.92, green: 0.40, blue: 0.0)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: size * 0.84, height: max(3.5, size * 0.052))
                }

                // Merkez bağlantı kelepçesi
                RoundedRectangle(cornerRadius: max(2, size * 0.024))
                    .fill(Color.white.opacity(0.92))
                    .frame(width: size * 0.15, height: max(4, size * 0.062))
                    .offset(y: size * 0.012)
            }
            .rotationEffect(.degrees(-11))
            .offset(y: size * 0.11)
        }
    }
}

struct AdBannerView: View {
    @ObservedObject var monetization = MonetizationService.shared

    var body: some View {
        if monetization.shouldShowAds {
            HStack(spacing: 10) {
                BrandSqueegeeBadge(size: 38)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Zamanı gelince silinecekler varsa")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Text("ÇEK ÇEK burada!")
                        .font(.caption.bold())
                        .foregroundStyle(.orange)
                        .lineLimit(1)
                }

                Spacer()

                Button {
                    monetization.showProPaywall = true
                } label: {
                    Text("Pro'ya Geç")
                        .font(.caption2.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.orange, in: Capsule())
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.secondarySystemBackground))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.orange.opacity(0.35), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
        }
    }
}

struct InterstitialAdSheet: View {
    @ObservedObject var monetization = MonetizationService.shared
    @Environment(\.dismiss) private var dismiss

    @State private var remainingSeconds: Int = 3
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(.systemBackground),
                    Color.cyan.opacity(0.10),
                    Color.orange.opacity(0.16)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                HStack {
                    Text("ÇEK ÇEK • SPONSORLU")
                        .font(.caption.bold())
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(.orange.opacity(0.2), in: Capsule())
                        .foregroundStyle(.orange)

                    Spacer()

                    Button {
                        monetization.showInterstitialAd = false
                        dismiss()
                    } label: {
                        Text(remainingSeconds > 0 ? "\(remainingSeconds) sn" : "Reklamı Kapat")
                            .font(.subheadline.bold())
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(
                                remainingSeconds > 0 ? Color(.tertiarySystemFill) : Color.primary.opacity(0.12),
                                in: Capsule()
                            )
                    }
                    .disabled(remainingSeconds > 0)
                }
                .padding(.horizontal)

                Spacer()

                VStack(spacing: 18) {
                    BrandSqueegeeBadge(size: 108)

                    VStack(spacing: 6) {
                        Text("Zamanı Gelince Silinecekler Varsa")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.primary)

                        Text("ÇEK ÇEK Burada!")
                            .font(.largeTitle.weight(.heavy))
                            .foregroundStyle(.orange)
                    }
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)

                    Text("“Zamanı gelince silinecekler varsa ÇEK ÇEK burada — çekpas gibi su misali süpürür, galerinde iz kalmaz!”")
                        .font(.body.italic())
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)

                    Text("Kasanızda 50'den fazla medya bulunduğu için bu ekranı görüyorsunuz. Medyalarınız silindikçe hakkınız otomatik yenilenir.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 28)
                }

                Spacer()

                Button {
                    monetization.showInterstitialAd = false
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        monetization.showProPaywall = true
                    }
                } label: {
                    Label("ÇEK ÇEK Pro ile Reklamları Kaldır", systemImage: "crown.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            .padding(.top, 16)
        }
        .interactiveDismissDisabled(remainingSeconds > 0)
        .onReceive(timer) { _ in
            if remainingSeconds > 0 {
                remainingSeconds -= 1
            }
        }
    }
}

struct ProPaywallSheet: View {
    @ObservedObject var monetization = MonetizationService.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    VStack(spacing: 12) {
                        BrandSqueegeeBadge(size: 88)
                            .padding(.top, 8)

                        Text("ÇEK ÇEK Pro")
                            .font(.largeTitle.bold())

                        Text("“Zamanı gelince silinecekler varsa ÇEK ÇEK burada!”")
                            .font(.subheadline.bold())
                            .foregroundStyle(.orange)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 12)
                    }

                    VStack(spacing: 14) {
                        featureRow(
                            icon: "timer",
                            title: "Süre Seçeneklerini Özelleştirin & Ekleyin",
                            subtitle: "Gün, saat ve dakika cinsinden saklama sürelerini kendiniz belirleyin ve yeni süre seçenekleri ekleyin."
                        )
                        featureRow(
                            icon: "nosign",
                            title: "Tamamen Reklamsız Deneyim",
                            subtitle: "50 medya sınırını aşsanız bile tüm reklamları tamamen kaldırın."
                        )
                        featureRow(
                            icon: "folder.badge.plus",
                            title: "Sınırsız Özel Klasör",
                            subtitle: "İş, fiş, şantiye veya notlarınız için dilediğiniz kadar kategori oluşturun."
                        )
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))

                    if monetization.isPro {
                        Label("ÇEK ÇEK Pro Aktif", systemImage: "checkmark.seal.fill")
                            .font(.headline)
                            .foregroundStyle(.green)
                            .padding()
                    } else {
                        Button {
                            monetization.isPro = true
                            dismiss()
                        } label: {
                            Text("Pro Paketi Etkinleştir")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)
                    }
                }
                .padding(20)
            }
            .navigationTitle("Pro Paket")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Kapat") { dismiss() }
                }
            }
        }
    }

    private func featureRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.orange)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
}
