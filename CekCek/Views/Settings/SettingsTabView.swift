import SwiftData
import SwiftUI

struct SettingsTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allItems: [MediaItem]
    @ObservedObject var lockService: AppLockService

    @AppStorage("defaultRetentionPreset") private var defaultRetentionRaw: String = RetentionPreset.threeDays.rawValue
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
                Section("Çekim & Saklama") {
                    Picker("Varsayılan Saklama Süresi", selection: $defaultRetentionRaw) {
                        ForEach(RetentionPreset.allCases) { preset in
                            Text(preset.title).tag(preset.rawValue)
                        }
                    }

                    Toggle("Uygulama Kamerada Açılsın", isOn: $startOnCameraTab)
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

                Section("Kasa Depolama") {
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

                    Button {
                        let deleted = ExpirationService.purgeExpiredItems(in: modelContext)
                        refreshVaultSize()
                        infoMessage = deleted > 0
                            ? "\(deleted) süresi dolmuş medya temizlendi."
                            : "Süresi dolmuş medya bulunamadı."
                    } label: {
                        Label("Süresi Dolanları Şimdi Temizle", systemImage: "sparkles")
                    }

                    Button(role: .destructive) {
                        showPurgeAllConfirm = true
                    } label: {
                        Label("Tüm Geçici Kasayı Boşalt", systemImage: "trash")
                    }
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
