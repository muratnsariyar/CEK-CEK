import AVKit
import SwiftData
import SwiftUI

struct MediaDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \MediaFolder.createdAt) private var folders: [MediaFolder]
    @AppStorage("notificationLeadHours") private var notificationLeadHours: Int = 6

    private let initialItem: MediaItem
    private let galleryItems: [MediaItem]

    @State private var currentItemID: UUID
    @State private var isChromeHidden = false
    @State private var showInfoSheet = false
    @State private var showShareSheet = false
    @State private var showCustomDurationSheet = false
    @State private var showDeleteConfirm = false
    @State private var alertMessage: String?
    @State private var isExporting = false

    init(item: MediaItem, items: [MediaItem]? = nil) {
        self.initialItem = item
        if let items, !items.isEmpty {
            self.galleryItems = items
        } else {
            self.galleryItems = [item]
        }
        _currentItemID = State(initialValue: item.id)
    }

    private var activeItems: [MediaItem] {
        let valid = galleryItems.filter { !$0.isExpired && !$0.isDeleted }
        if valid.isEmpty {
            return initialItem.isDeleted ? [] : [initialItem]
        }
        return valid
    }

    private var currentItem: MediaItem {
        activeItems.first(where: { $0.id == currentItemID }) ?? activeItems.first ?? initialItem
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if activeItems.count > 1 {
                TabView(selection: $currentItemID) {
                    ForEach(activeItems) { media in
                        MediaPageCanvas(
                            item: media,
                            isActive: media.id == currentItemID,
                            onToggleChrome: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    isChromeHidden.toggle()
                                }
                            },
                            onSwipeUpForInfo: {
                                showInfoSheet = true
                            }
                        )
                        .tag(media.id)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .ignoresSafeArea()
            } else if let single = activeItems.first {
                MediaPageCanvas(
                    item: single,
                    isActive: true,
                    onToggleChrome: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isChromeHidden.toggle()
                        }
                    },
                    onSwipeUpForInfo: {
                        showInfoSheet = true
                    }
                )
                .ignoresSafeArea()
            }

            if !isChromeHidden {
                VStack(spacing: 0) {
                    topBar
                    Spacer()
                    bottomBar
                }
                .transition(.opacity)
            }
        }
        .preferredColorScheme(.dark)
        .statusBarHidden(isChromeHidden)
        .onDisappear {
            try? modelContext.save()
        }
        .sheet(isPresented: $showInfoSheet) {
            MediaInspectorSheet(
                item: currentItem,
                folders: folders,
                onExtendTap: {
                    showInfoSheet = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        showCustomDurationSheet = true
                    }
                }
            )
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: [MediaStorageService.shared.fileURL(for: currentItem.fileName)])
        }
        .sheet(isPresented: $showCustomDurationSheet) {
            DurationWheelPickerSheet(
                title: "Sayaçla Süre Uzat",
                initialDuration: RetentionSettingsManager.shared.lastUsedDuration
            ) { duration in
                let target = currentItem
                target.extend(by: duration)
                try? modelContext.save()
                NotificationService.shared.scheduleExpirationReminder(
                    for: target,
                    hoursBefore: notificationLeadHours
                )
                alertMessage = "Saklama süresi \(duration.title) uzatıldı."
            }
        }
        .confirmationDialog(
            "Bu medya kalıcı olarak silinsin mi?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Hemen Sil", role: .destructive) {
                deleteCurrentItem()
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

    private var topBar: some View {
        HStack(spacing: 12) {
            Button {
                try? modelContext.save()
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(.ultraThinMaterial, in: Circle())
            }

            Spacer()

            VStack(spacing: 2) {
                Text(currentItem.createdAt.formatted(date: .abbreviated, time: .omitted))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)

                HStack(spacing: 6) {
                    Text(currentItem.createdAt.formatted(date: .omitted, time: .shortened))
                    Text("•")
                    Text("Kalan: \(currentItem.remainingBadgeText)")
                        .foregroundStyle(currentItem.isCritical ? .red : (currentItem.isExpiringSoon ? .orange : .white.opacity(0.85)))
                }
                .font(.caption2.weight(.medium))
                .foregroundStyle(.white.opacity(0.8))
            }

            Spacer()

            Menu {
                ForEach(folders) { folder in
                    Button {
                        currentItem.folder = folder
                        try? modelContext.save()
                    } label: {
                        Label(folder.name, systemImage: folder.iconName)
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: currentItem.folder?.iconName ?? "folder.fill")
                        .font(.caption)
                    Text(currentItem.folder?.name ?? "Genel")
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial, in: Capsule())
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .background(
            LinearGradient(
                colors: [.black.opacity(0.65), .black.opacity(0.0)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .top)
        )
    }

    private var bottomBar: some View {
        HStack {
            Button {
                showShareSheet = true
            } label: {
                toolbarIconButton(icon: "square.and.arrow.up", title: "Paylaş")
            }

            Spacer()

            Menu {
                ForEach(RetentionSettingsManager.shared.uniqueActivePresets) { preset in
                    Button("+\(preset.title) Uzat") {
                        let target = currentItem
                        target.extend(by: preset)
                        try? modelContext.save()
                        NotificationService.shared.scheduleExpirationReminder(
                            for: target,
                            hoursBefore: notificationLeadHours
                        )
                        alertMessage = "Saklama süresi \(preset.title) uzatıldı."
                    }
                }
                Divider()
                Button("Sayaçla Süre Uzat...") {
                    showCustomDurationSheet = true
                }
            } label: {
                toolbarIconButton(icon: "clock.arrow.circlepath", title: "Uzat")
            }

            Spacer()

            Button {
                showInfoSheet = true
            } label: {
                toolbarIconButton(
                    icon: showInfoSheet ? "info.circle.fill" : "info.circle",
                    title: "Bilgi"
                )
            }

            Spacer()

            Button {
                exportToPersonalPhotos()
            } label: {
                if isExporting {
                    ProgressView()
                        .tint(.white)
                        .frame(width: 48, height: 42)
                } else {
                    toolbarIconButton(icon: "photo.badge.arrow.down", title: "Galeriye")
                }
            }
            .disabled(isExporting)

            Spacer()

            Button(role: .destructive) {
                showDeleteConfirm = true
            } label: {
                toolbarIconButton(icon: "trash", title: "Sil")
                    .foregroundStyle(.red)
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .background(.ultraThinMaterial)
    }

    private func toolbarIconButton(icon: String, title: String) -> some View {
        VStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 19, weight: .regular))
            Text(title)
                .font(.caption2)
        }
        .frame(minWidth: 48)
    }

    private func deleteCurrentItem() {
        let target = currentItem
        let remainingAfterDelete = activeItems.filter { $0.id != target.id }
        ExpirationService.deleteItem(target, in: modelContext)
        if let next = remainingAfterDelete.first {
            currentItemID = next.id
        } else {
            dismiss()
        }
    }

    private func exportToPersonalPhotos() {
        let target = currentItem
        isExporting = true
        Task {
            do {
                try await PhotoLibraryExportService.saveToPersonalGallery(item: target)
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

private struct MediaPageCanvas: View {
    let item: MediaItem
    let isActive: Bool
    let onToggleChrome: () -> Void
    let onSwipeUpForInfo: () -> Void

    @State private var fullImage: UIImage?
    @State private var player: AVPlayer?
    @State private var zoomScale: CGFloat = 1.0
    @State private var gestureScale: CGFloat = 1.0

    var body: some View {
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
                        .scaleEffect(zoomScale * gestureScale)
                        .gesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    gestureScale = value
                                }
                                .onEnded { value in
                                    let finalScale = max(1.0, min(zoomScale * value, 4.0))
                                    withAnimation(.spring(duration: 0.25)) {
                                        zoomScale = finalScale
                                        gestureScale = 1.0
                                    }
                                }
                        )
                        .onTapGesture(count: 2) {
                            withAnimation(.spring(duration: 0.25)) {
                                zoomScale = zoomScale > 1.05 ? 1.0 : 2.5
                            }
                        }
                        .onTapGesture(count: 1) {
                            onToggleChrome()
                        }
                } else {
                    ProgressView()
                        .tint(.white)
                }
            }
        }
        .contentShape(Rectangle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 35)
                .onEnded { value in
                    let isUpward = value.translation.height < -55
                    let isMostlyVertical = abs(value.translation.height) > abs(value.translation.width) * 1.4
                    if isUpward && isMostlyVertical {
                        onSwipeUpForInfo()
                    }
                }
        )
        .onAppear {
            loadMedia()
        }
        .onDisappear {
            player?.pause()
        }
        .onChange(of: isActive) { _, active in
            if !active {
                player?.pause()
                zoomScale = 1.0
            }
        }
    }

    private func loadMedia() {
        switch item.mediaType {
        case .photo:
            if fullImage == nil {
                fullImage = MediaStorageService.shared.loadImage(fileName: item.fileName)
            }
        case .video:
            if player == nil {
                let url = MediaStorageService.shared.fileURL(for: item.fileName)
                player = AVPlayer(url: url)
            }
        }
    }
}

private struct MediaInspectorSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Bindable var item: MediaItem
    let folders: [MediaFolder]
    let onExtendTap: () -> Void

    @State private var pixelResolution: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Tarih & Saat Başlığı (iPhone Fotoğraflar Tarzı)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.createdAt.formatted(.dateTime.weekday(.wide).day().month(.wide).year()))
                            .font(.headline)
                        Text(item.createdAt.formatted(date: .omitted, time: .shortened))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 4)

                    // Başlık / Not Kutusu (Photos'daki "Başlık Ekle" alanı gibi)
                    VStack(alignment: .leading, spacing: 6) {
                        TextField("Not veya başlık ekle...", text: $item.note, axis: .vertical)
                            .lineLimit(1...4)
                            .padding(12)
                            .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 12))
                            .onChange(of: item.note) { _, _ in
                                try? modelContext.save()
                            }
                    }

                    // Saklama Süresi & Klasör Kartı
                    VStack(spacing: 12) {
                        HStack {
                            Label("Otomatik Silinme", systemImage: "hourglass")
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Text(item.remainingBadgeText)
                                .font(.subheadline.bold())
                                .foregroundStyle(item.isCritical ? .red : (item.isExpiringSoon ? .orange : .green))
                        }

                        Divider()

                        HStack {
                            Text("Silinme Tarihi")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(item.expiresAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.subheadline)
                        }

                        Divider()

                        HStack {
                            Text("Klasör")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Spacer()
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
                                HStack(spacing: 5) {
                                    Image(systemName: item.folder?.iconName ?? "folder.fill")
                                    Text(item.folder?.name ?? "Genel")
                                    Image(systemName: "chevron.up.chevron.down")
                                        .font(.caption2)
                                }
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.orange)
                            }
                        }

                        Button {
                            onExtendTap()
                        } label: {
                            Label("Saklama Süresini Uzat", systemImage: "clock.arrow.circlepath")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                        }
                        .buttonStyle(.bordered)
                        .tint(.orange)
                    }
                    .padding(14)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))

                    // iPhone Fotoğraflar EXIF / Dosya Ayrıntıları Kartı
                    VStack(spacing: 0) {
                        HStack {
                            HStack(spacing: 8) {
                                Image(systemName: item.mediaType == .video ? "video.fill" : "camera.fill")
                                    .foregroundStyle(.secondary)
                                Text("CEK CEK Kasa")
                                    .font(.subheadline.weight(.semibold))
                            }
                            Spacer()
                            Text(fileFormatBadge)
                                .font(.caption2.bold())
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 6))
                        }
                        .padding(14)

                        Divider()

                        HStack(spacing: 12) {
                            detailPill(title: "Tür", value: item.mediaType.displayName)
                            Divider().frame(height: 28)
                            if let duration = item.formattedDuration {
                                detailPill(title: "Süre", value: duration)
                            } else {
                                detailPill(title: "Çözünürlük", value: pixelResolution ?? "—")
                            }
                            Divider().frame(height: 28)
                            detailPill(title: "Boyut", value: item.formattedFileSize)
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 8)
                    }
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Ayrıntılar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Bitti") {
                        try? modelContext.save()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .onAppear {
            loadResolution()
        }
    }

    private var fileFormatBadge: String {
        let ext = (item.fileName as NSString).pathExtension.uppercased()
        if ext == "JPG" { return "JPEG" }
        return ext.isEmpty ? (item.mediaType == .video ? "MOV" : "JPEG") : ext
    }

    private func detailPill(title: String, value: String) -> some View {
        VStack(spacing: 3) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }

    private func loadResolution() {
        guard item.mediaType == .photo, pixelResolution == nil else { return }
        if let image = MediaStorageService.shared.loadImage(fileName: item.fileName) {
            if let cg = image.cgImage {
                pixelResolution = "\(cg.width) × \(cg.height)"
            } else {
                let w = Int(image.size.width * image.scale)
                let h = Int(image.size.height * image.scale)
                pixelResolution = "\(w) × \(h)"
            }
        }
    }
}
