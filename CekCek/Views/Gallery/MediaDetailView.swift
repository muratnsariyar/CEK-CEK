import AVKit
import SwiftData
import SwiftUI

struct MediaDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \MediaFolder.createdAt) private var folders: [MediaFolder]
    @AppStorage("notificationLeadHours") private var notificationLeadHours: Int = 6

    @Bindable var item: MediaItem

    @State private var fullImage: UIImage?
    @State private var player: AVPlayer?
    @State private var showShareSheet = false
    @State private var showCustomDateSheet = false
    @State private var customExpireDate: Date = Date().addingTimeInterval(86400 * 3)
    @State private var showDeleteConfirm = false
    @State private var alertMessage: String?
    @State private var isExporting = false
    @State private var zoomScale: CGFloat = 1.0

    var body: some View {
        VStack(spacing: 0) {
            mediaCanvas

            // Bilgi & Not Bölümü
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label(
                        "Kalan: \(item.remainingBadgeText)",
                        systemImage: "hourglass"
                    )
                    .font(.subheadline.bold())
                    .foregroundStyle(item.isCritical ? .red : (item.isExpiringSoon ? .orange : .primary))

                    Spacer()

                    Text(item.formattedFileSize)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 12) {
                    Text("Çekim: \(item.createdAt.formatted(date: .abbreviated, time: .shortened))")
                    Spacer()
                    Text("Silinme: \(item.expiresAt.formatted(date: .abbreviated, time: .shortened))")
                }
                .font(.caption2)
                .foregroundStyle(.secondary)

                TextField("Not ekle (örn: Kargo fişi, tahta notu)...", text: $item.note)
                    .textFieldStyle(.roundedBorder)
                    .font(.subheadline)
                    .onSubmit {
                        try? modelContext.save()
                    }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.secondarySystemBackground))

            actionBar
        }
        .navigationTitle(item.folder?.name ?? "Medya Detayı")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Kapat") {
                    try? modelContext.save()
                    dismiss()
                }
            }
        }
        .onAppear {
            loadMedia()
            customExpireDate = max(Date().addingTimeInterval(3600), item.expiresAt)
        }
        .onDisappear {
            player?.pause()
            try? modelContext.save()
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: [MediaStorageService.shared.fileURL(for: item.fileName)])
        }
        .sheet(isPresented: $showCustomDateSheet) {
            customDatePickerSheet
        }
        .confirmationDialog(
            "Bu medya kalıcı olarak silinsin mi?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Hemen Sil", role: .destructive) {
                ExpirationService.deleteItem(item, in: modelContext)
                dismiss()
            }
            Button("Vazgeç", role: .cancel) {}
        }
        .alert("CEK CEK", isPresented: Binding(
            get: { alertMessage != nil },
            set: { if !$0 { alertMessage = nil } }
        )) {
            Button("Tamam", role: .cancel) {}
        } message: {
            Text(alertMessage ?? "")
        }
    }

    private var mediaCanvas: some View {
        ZStack {
            Color.black

            if item.mediaType == .video {
                if let player {
                    VideoPlayer(player: player)
                } else {
                    ProgressView()
                        .tint(.white)
                }
            } else {
                if let fullImage {
                    Image(uiImage: fullImage)
                        .resizable()
                        .scaledToFit()
                        .scaleEffect(zoomScale)
                        .gesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    zoomScale = max(1.0, min(value, 4.0))
                                }
                                .onEnded { _ in
                                    if zoomScale < 1.05 {
                                        withAnimation(.spring) {
                                            zoomScale = 1.0
                                        }
                                    }
                                }
                        )
                        .onTapGesture(count: 2) {
                            withAnimation(.spring) {
                                zoomScale = zoomScale > 1.0 ? 1.0 : 2.2
                            }
                        }
                } else {
                    ProgressView()
                        .tint(.white)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var actionBar: some View {
        HStack {
            // Paylaş
            Button {
                showShareSheet = true
            } label: {
                actionButtonLabel(title: "Paylaş", icon: "square.and.arrow.up")
            }

            Spacer()

            // Süre Uzat
            Menu {
                ForEach(RetentionPreset.allCases) { preset in
                    Button("+\(preset.title) Uzat") {
                        item.extend(by: preset)
                        try? modelContext.save()
                        NotificationService.shared.scheduleExpirationReminder(
                            for: item,
                            hoursBefore: notificationLeadHours
                        )
                        alertMessage = "Saklama süresi \(preset.title) uzatıldı."
                    }
                }
                Divider()
                Button("Özel Tarih Seç...") {
                    customExpireDate = max(Date().addingTimeInterval(3600), item.expiresAt)
                    showCustomDateSheet = true
                }
            } label: {
                actionButtonLabel(title: "Uzat", icon: "clock.arrow.circlepath")
            }

            Spacer()

            // Kişisel Galeriye Kaydet
            Button {
                exportToPersonalPhotos()
            } label: {
                if isExporting {
                    ProgressView()
                        .frame(width: 56, height: 42)
                } else {
                    actionButtonLabel(title: "Galeriye", icon: "photo.badge.arrow.down")
                }
            }
            .disabled(isExporting)

            Spacer()

            // Klasör Değiştir
            Menu {
                ForEach(folders) { folder in
                    Button {
                        item.folder = folder
                        try? modelContext.save()
                    } label: {
                        Label(folder.name, systemImage: folder.iconName)
                    }
                }
            } label: {
                actionButtonLabel(title: "Klasör", icon: "folder")
            }

            Spacer()

            // Sil
            Button(role: .destructive) {
                showDeleteConfirm = true
            } label: {
                actionButtonLabel(title: "Sil", icon: "trash")
                    .foregroundStyle(.red)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(Color(.systemBackground))
    }

    private func actionButtonLabel(title: String, icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
            Text(title)
                .font(.caption2)
        }
        .frame(minWidth: 50)
    }

    private var customDatePickerSheet: some View {
        NavigationStack {
            Form {
                DatePicker(
                    "Otomatik Silinme Tarihi",
                    selection: $customExpireDate,
                    in: Date().addingTimeInterval(600)...,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .datePickerStyle(.graphical)
            }
            .navigationTitle("Özel Süre")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("İptal") { showCustomDateSheet = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet") {
                        item.expiresAt = customExpireDate
                        try? modelContext.save()
                        NotificationService.shared.scheduleExpirationReminder(
                            for: item,
                            hoursBefore: notificationLeadHours
                        )
                        showCustomDateSheet = false
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func loadMedia() {
        switch item.mediaType {
        case .photo:
            fullImage = MediaStorageService.shared.loadImage(fileName: item.fileName)
        case .video:
            let url = MediaStorageService.shared.fileURL(for: item.fileName)
            player = AVPlayer(url: url)
        }
    }

    private func exportToPersonalPhotos() {
        isExporting = true
        Task {
            do {
                try await PhotoLibraryExportService.saveToPersonalGallery(item: item)
                await MainActor.run {
                    isExporting = false
                    alertMessage = "Medya kişisel Fotoğraflar galerinize kalıcı olarak kaydedildi."
                }
            } catch {
                await MainActor.run {
                    isExporting = false
                    alertMessage = error.localizedDescription
                }
            }
        }
    }
}
