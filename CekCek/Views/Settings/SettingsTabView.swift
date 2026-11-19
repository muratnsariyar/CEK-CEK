import SwiftData
import SwiftUI

struct SettingsTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allItems: [MediaItem]
    @ObservedObject var lockService: AppLockService
    @ObservedObject private var retentionSettings = RetentionSettingsManager.shared
    @ObservedObject private var monetization = MonetizationService.shared

    @AppStorage("notificationsEnabled") private var notificationsEnabled: Bool = false
    @AppStorage("notificationLeadHours") private var notificationLeadHours: Int = 6
    @AppStorage("startOnCameraTab") private var startOnCameraTab: Bool = true

    @State private var vaultSizeBytes: Int64 = 0
    @State private var showPurgeAllConfirm = false
    @State private var infoMessage: String?

    private let leadHourOptions = [3, 6, 12, 24]

    var body: some View {
        NavigationStack {
            Form {
                Section("Üyelik & Reklamsız Kullanım") {
                    HStack {
                        Label(
                            monetization.isPro ? "CEK CEK Pro" : "Ücretsiz Paket",
                            systemImage: monetization.isPro ? "crown.fill" : "person.crop.circle"
                        )
                        .foregroundStyle(monetization.isPro ? .orange : .primary)
                        Spacer()
                        Text(monetization.isPro ? "Reklamsız & Tam Erişim" : "Aktif")
                            .font(.subheadline)
                            .foregroundStyle(monetization.isPro ? .green : .secondary)
                    }

                    if !monetization.isPro {
                        HStack {
                            Text("Reklamsız Kullanım Hakkı")
                            Spacer()
                            if monetization.remainingAdFreeUsages > 0 {
                                Text("\(monetization.remainingAdFreeUsages) / \(MonetizationService.freeAdQuota) kaldı")
                                    .foregroundStyle(.orange)
                                    .fontWeight(.semibold)
                            } else {
                                Text("50 hak doldu — Reklamlar aktif")
                                    .foregroundStyle(.red)
                                    .font(.caption.bold())
                            }
                        }

                        Button {
                            monetization.showProPaywall = true
                        } label: {
                            Label("CEK CEK Pro'ya Geç", systemImage: "crown.fill")
                                .foregroundStyle(.orange)
                                .fontWeight(.semibold)
                        }
                    }
                }

                Section {
                    if monetization.isPro {
                        Picker("1. Süre Butonu", selection: $retentionSettings.slot1) {
                            ForEach(RetentionPreset.allCases) { preset in
                                Text(preset.title).tag(preset)
                            }
                        }
                        Picker("2. Süre Butonu", selection: $retentionSettings.slot2) {
                            ForEach(RetentionPreset.allCases) { preset in
                                Text(preset.title).tag(preset)
                            }
                        }
                        Picker("3. Süre Butonu", selection: $retentionSettings.slot3) {
                            ForEach(RetentionPreset.allCases) { preset in
                                Text(preset.title).tag(preset)
                            }
                        }

                        Picker("Varsayılan Saklama Süresi", selection: $retentionSettings.defaultPreset) {
                            ForEach(retentionSettings.uniqueActivePresets) { preset in
                                Text(preset.title).tag(preset)
                            }
                        }

                        Button("Süreleri Varsayılana Sıfırla") {
                            retentionSettings.resetToDefaults()
                        }
                    } else {
                        proLockedDurationRow(title: "1. Süre Butonu", value: retentionSettings.slot1.title)
                        proLockedDurationRow(title: "2. Süre Butonu", value: retentionSettings.slot2.title)
                        proLockedDurationRow(title: "3. Süre Butonu", value: retentionSettings.slot3.title)

                        Picker("Varsayılan Saklama Süresi", selection: $retentionSettings.defaultPreset) {
                            ForEach(retentionSettings.uniqueActivePresets) { preset in
                                Text(preset.title).tag(preset)
                            }
                        }
                    }

                    Toggle("Uygulama Kamerada Açılsın", isOn: $startOnCameraTab)
                } header: {
                    Text("Çekim & Saklama Süreleri (3 Seçenek)")
                } footer: {
                    Text(
                        monetization.isPro
                            ? "Kamerada görünecek 3 saklama süresi butonunu dilediğiniz gibi ayarlayabilirsiniz."
                            : "Kamera ekranındaki 3 saklama süresini özelleştirmek CEK CEK Pro paketine dahildir."
                    )
                }

                Section {
                    Toggle("Süre Bitimi Hatırlatması", isOn: Binding(
                        get: { notificationsEnabled },
                        set: { newValue in
                            handleNotificationToggle(newValue)
                        }
                    ))

                    if notificationsEnabled {
                        Picker("Ne Kadar Önce Hatırlat?", selection: $notificationLeadHours) {
                            ForEach(leadHourOptions, id: \.self) { hours in
                                Text("\(hours) saat önce").tag(hours)
                            }
                        }
                        .onChange(of: notificationLeadHours) { _, newValue in
                            NotificationService.shared.rescheduleAllReminders(
                                for: allItems,
                                enabled: notificationsEnabled,
                                hoursBefore: newValue
                            )
                        }
                    }
                } header: {
                    Text("Bildirimler")
                } footer: {
                    Text("Medyanız otomatik silinmeden önce kaydetmek veya süresini uzatmak isterseniz bildirim alırsınız.")
                }

                Section {
                    Toggle("\(lockService.biometricName) ile Kilitle", isOn: Binding(
                        get: { lockService.isLockEnabled },
                        set: { lockService.isLockEnabled = $0 }
                    ))
                } header: {
                    Text("Gizlilik & Güvenlik")
                } footer: {
                    Text("Etkinleştirildiğinde uygulama arka plana alındığında otomatik kilitlenir.")
                }

                Section {
                    HStack {
                        Text("Aktif Medya Sayısı")
                        Spacer()
                        Text("\(allItems.filter { !$0.isExpired }.count)")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Kullanılan Alan")
                        Spacer()
                        Text(ByteCountFormatter.string(fromByteCount: vaultSizeBytes, countStyle: .file))
                            .foregroundStyle(.secondary)
                    }

                    Button(role: .destructive) {
                        showPurgeAllConfirm = true
                    } label: {
                        Label("Tüm Geçici Kasayı Boşalt", systemImage: "trash")
                    }
                } header: {
                    Text("Kasa Depolama")
                } footer: {
                    Text("Süresi dolan fotoğraf ve videolar müdahaleye gerek kalmadan otomatik olarak silinir.")
                }

                Section {
                    Toggle("Pro Paketi Simüle Et", isOn: $monetization.isPro)

                    Button("50 Kullanım Hakkını Doldur (Reklamları Başlat)") {
                        monetization.simulateQuotaExhausted()
                    }

                    Button("Kullanım Sayacını Sıfırla (0/50)") {
                        monetization.resetUsageQuota()
                    }
                } header: {
                    Text("Geliştirici Testi")
                } footer: {
                    Text("Reklam tetikleme (50 hak) ve Pro süre özelleştirme özelliklerini test etmek içindir.")
                }

                Section("Hakkında") {
                    HStack {
                        Text("Uygulama")
                        Spacer()
                        Text("CEK CEK")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Depolama Konumu")
                        Spacer()
                        Text("İzole Uygulama Kasası")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Ayarlar")
            .onAppear {
                refreshVaultSize()
            }
            .confirmationDialog(
                "Kasadaki tüm fotoğraf ve videolar kalıcı olarak silinsin mi?",
                isPresented: $showPurgeAllConfirm,
                titleVisibility: .visible
            ) {
                Button("Tüm Kasayı Sil", role: .destructive) {
                    ExpirationService.purgeAllItems(in: modelContext)
                    refreshVaultSize()
                }
                Button("Vazgeç", role: .cancel) {}
            }
            .alert("CEK CEK", isPresented: Binding(
                get: { infoMessage != nil },
                set: { if !$0 { infoMessage = nil } }
            )) {
                Button("Tamam", role: .cancel) {}
            } message: {
                Text(infoMessage ?? "")
            }
        }
    }

    private func proLockedDurationRow(title: String, value: String) -> some View {
        Button {
            monetization.showProPaywall = true
        } label: {
            HStack {
                Text(title)
                    .foregroundStyle(.primary)
                Spacer()
                Text(value)
                    .foregroundStyle(.secondary)
                Text("PRO")
                    .font(.caption2.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color.orange, in: Capsule())
            }
        }
    }

    private func refreshVaultSize() {
        vaultSizeBytes = MediaStorageService.shared.totalVaultSizeBytes()
    }

    private func handleNotificationToggle(_ wantsEnabled: Bool) {
        if !wantsEnabled {
            notificationsEnabled = false
            NotificationService.shared.rescheduleAllReminders(
                for: allItems,
                enabled: false,
                hoursBefore: notificationLeadHours
            )
            return
        }

        Task {
            let granted = await NotificationService.shared.requestAuthorization()
            await MainActor.run {
                if granted {
                    notificationsEnabled = true
                    NotificationService.shared.rescheduleAllReminders(
                        for: allItems,
                        enabled: true,
                        hoursBefore: notificationLeadHours
                    )
                } else {
                    notificationsEnabled = false
                    infoMessage = "Bildirim izni verilmedi. Ayarlar > CEK CEK üzerinden bildirimleri açabilirsiniz."
                }
            }
        }
    }
}
