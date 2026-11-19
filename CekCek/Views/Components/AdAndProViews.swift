import Combine
import SwiftUI

struct AdBannerView: View {
    @ObservedObject var monetization = MonetizationService.shared

    var body: some View {
        if monetization.shouldShowAds {
            HStack(spacing: 10) {
                Image(systemName: "megaphone.fill")
                    .font(.subheadline)
                    .foregroundStyle(.orange)

                VStack(alignment: .leading, spacing: 2) {
                    Text("REKLAM ALANI")
                        .font(.caption2.bold())
                        .foregroundStyle(.orange)
                    Text("50 ücretsiz kullanım hakkınız doldu")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Button {
                    monetization.showProPaywall = true
                } label: {
                    Text("Reklamları Kaldır (Pro)")
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
                colors: [Color(.systemBackground), Color.orange.opacity(0.14)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                HStack {
                    Text("REKLAM")
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

                VStack(spacing: 16) {
                    Image(systemName: "sparkles.rectangle.stack.fill")
                        .font(.system(size: 68))
                        .foregroundStyle(.orange)

                    Text("50 Ücretsiz Kullanım Hakkınız Doldu")
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)

                    Text("Uygulamayı ücretsiz kullanmaya devam edebilirsiniz. Reklamları tamamen kaldırmak ve 3 saklama süresini dilediğiniz gibi özelleştirmek için CEK CEK Pro'ya geçebilirsiniz.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                Spacer()

                Button {
                    monetization.showInterstitialAd = false
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        monetization.showProPaywall = true
                    }
                } label: {
                    Label("CEK CEK Pro ile Reklamları Kaldır", systemImage: "crown.fill")
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
                VStack(spacing: 24) {
                    VStack(spacing: 10) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 56))
                            .foregroundStyle(.orange)
                            .padding(.top, 12)

                        Text("CEK CEK Pro")
                            .font(.largeTitle.bold())

                        Text("Geçici kameranızı tam kontrol altına alın")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    VStack(spacing: 14) {
                        featureRow(
                            icon: "timer",
                            title: "3 Süre Butonunu Özelleştirin",
                            subtitle: "Sayaçla 1 dakikadan 30 güne kadar istediğiniz 3 saklama süresini kendiniz belirleyin."
                        )
                        featureRow(
                            icon: "nosign",
                            title: "Tamamen Reklamsız Deneyim",
                            subtitle: "50 kullanım sonrasında çıkan tüm banner ve tam ekran reklamları kaldırın."
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
                        Label("CEK CEK Pro Aktif", systemImage: "checkmark.seal.fill")
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
