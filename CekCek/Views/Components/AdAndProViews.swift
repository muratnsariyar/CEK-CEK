import Combine
import SwiftUI

struct BrandSqueegeeBadge: View {
    var size: CGFloat = 76

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.07, green: 0.13, blue: 0.24),
                            Color(red: 0.12, green: 0.25, blue: 0.42)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)
                .shadow(color: .orange.opacity(0.28), radius: 10, y: 4)

            // Su damlaları & çekpas süpürme efekti
            Image(systemName: "drop.fill")
                .font(.system(size: size * 0.18))
                .foregroundStyle(.cyan.opacity(0.85))
                .offset(x: -size * 0.22, y: -size * 0.20)

            Image(systemName: "sparkles")
                .font(.system(size: size * 0.18, weight: .bold))
                .foregroundStyle(.orange)
                .offset(x: size * 0.24, y: -size * 0.22)

            // Kamera + Çekpas (squeegee) birleşimi
            VStack(spacing: 2) {
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: size * 0.36, weight: .bold))
                    .foregroundStyle(.white)

                RoundedRectangle(cornerRadius: 3)
                    .fill(
                        LinearGradient(
                            colors: [.orange, .cyan],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: size * 0.54, height: max(4, size * 0.06))
            }
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
                    Text("Siz rahat rahat çekin diye ÇEK ÇEK'i geliştirdik")
                        .font(.caption.bold())
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text("Çekpas gibi su misali süpürür, galerini kirletmez!")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
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
                    BrandSqueegeeBadge(size: 104)

                    Text("Siz Rahat Rahat Fotoğraf Çekin Diye\nÇEK ÇEK'i Geliştirdik!")
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)

                    Text("“Kamerayla çek, işin bitince çekpas gibi su misali süpürülsün — kişisel galerinde tek damla iz kalmasın!”")
                        .font(.body.italic())
                        .foregroundStyle(.orange)
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

                        Text("“Fotoğrafları çek, çekpas gibi su misali süpür at — galerinde iz bile kalmasın!”")
                            .font(.subheadline.italic())
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
