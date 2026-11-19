import AVFoundation
import PhotosUI
import SwiftData
import SwiftUI

struct CameraTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MediaFolder.createdAt) private var folders: [MediaFolder]
    @Query(sort: \MediaItem.createdAt, order: .reverse) private var recentItems: [MediaItem]

    @AppStorage("defaultRetentionPreset") private var defaultRetentionRaw: String = RetentionPreset.threeDays.rawValue
    @AppStorage("notificationLeadHours") private var notificationLeadHours: Int = 6

    @StateObject private var camera = CameraManager()

    @State private var selectedRetention: RetentionPreset = .threeDays
    @State private var selectedFolderID: UUID?
    @State private var showFlashOverlay: Bool = false
    @State private var statusBanner: String?
    @State private var baseZoomFactor: CGFloat = 1.0
    @State private var importedPickerItem: PhotosPickerItem?
    @State private var previewItem: MediaItem?

    var onOpenGallery: () -> Void

    private var activeFolder: MediaFolder? {
        if let id = selectedFolderID, let match = folders.first(where: { $0.id == id }) {
            return match
        }
        return folders.first
    }

    private var latestActiveItem: MediaItem? {
        recentItems.first(where: { !$0.isExpired })
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if camera.permissionDenied {
                permissionDeniedView
            } else if camera.isCameraUnavailable {
                simulatorFallbackView
            } else {
                CameraPreviewView(session: camera.session) { devicePoint in
                    camera.focus(at: devicePoint)
                }
                .ignoresSafeArea(edges: .top)
                .gesture(
                    MagnificationGesture()
                        .onChanged { value in
                            camera.setZoom(factor: baseZoomFactor * value)
                        }
                        .onEnded { _ in
                            baseZoomFactor = camera.zoomFactor
                        }
                )
            }

            if showFlashOverlay {
                Color.white
                    .opacity(0.65)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }

            VStack(spacing: 0) {
                topBar
                Spacer()

                if let banner = statusBanner {
                    Text(banner)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.black.opacity(0.75), in: Capsule())
                        .overlay(Capsule().stroke(.orange.opacity(0.7), lineWidth: 1))
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(.bottom, 12)
                }

                bottomControls
            }
        }
        .onAppear {
            selectedRetention = RetentionPreset(rawValue: defaultRetentionRaw) ?? .threeDays
            if selectedFolderID == nil {
                selectedFolderID = folders.first?.id
            }
            camera.onPhotoCaptured = { data in
                saveCapturedPhoto(data: data)
            }
            camera.onVideoCaptured = { tempURL in
                saveCapturedVideo(tempURL: tempURL)
            }
            camera.checkPermissionsAndStart()
        }
        .onDisappear {
            camera.stopSession()
        }
        .onChange(of: importedPickerItem) { _, newValue in
            guard let newValue else { return }
            Task {
                await importFromPhotosPicker(newValue)
                importedPickerItem = nil
            }
        }
        .sheet(item: $previewItem) { item in
            NavigationStack {
                MediaDetailView(item: item)
            }
        }
        .alert("Kamera Hatası", isPresented: Binding(
            get: { camera.errorMessage != nil },
            set: { if !$0 { camera.errorMessage = nil } }
        )) {
            Button("Tamam", role: .cancel) {}
        } message: {
            Text(camera.errorMessage ?? "")
        }
    }

    private var topBar: some View {
        HStack {
            if !camera.isCameraUnavailable && !camera.permissionDenied {
                Button {
                    camera.toggleFlash()
                } label: {
                    Image(systemName: flashIconName)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(camera.flashMode == .on ? .orange : .white)
                        .frame(width: 40, height: 40)
                        .background(.black.opacity(0.45), in: Circle())
                }
            } else {
                Spacer().frame(width: 40)
            }

            Spacer()

            if camera.isRecording {
                HStack(spacing: 6) {
                    Circle()
                        .fill(.red)
                        .frame(width: 8, height: 8)
                    Text(camera.formattedRecordingTime)
                        .font(.subheadline.monospacedDigit().bold())
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.red.opacity(0.85), in: Capsule())
            } else {
                folderPickerMenu
            }

            Spacer()

            if !camera.isCameraUnavailable && !camera.permissionDenied {
                Button {
                    camera.switchCamera()
                } label: {
                    Image(systemName: "arrow.triangle.2.circlepath.camera.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(.black.opacity(0.45), in: Circle())
                }
                .disabled(camera.isRecording)
            } else {
                Spacer().frame(width: 40)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    private var folderPickerMenu: some View {
        Menu {
            ForEach(folders) { folder in
                Button {
                    selectedFolderID = folder.id
                    selectedRetention = folder.defaultPreset
                } label: {
                    Label(folder.name, systemImage: folder.iconName)
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: activeFolder?.iconName ?? "folder.fill")
                    .foregroundStyle(activeFolder?.color ?? .orange)
                Text(activeFolder?.name ?? "Genel")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Image(systemName: "chevron.down")
                    .font(.caption2.bold())
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.black.opacity(0.55), in: Capsule())
            .overlay(Capsule().stroke(.white.opacity(0.18), lineWidth: 1))
        }
    }

    private var bottomControls: some View {
        VStack(spacing: 14) {
            // Saklama Süresi Hızlı Seçici
            HStack(spacing: 6) {
                Image(systemName: "timer")
                    .font(.caption.bold())
                    .foregroundStyle(.orange)
                ForEach(RetentionPreset.allCases) { preset in
                    Button {
                        withAnimation(.snappy) {
                            selectedRetention = preset
                        }
                    } label: {
                        Text(preset.shortLabel)
                            .font(.caption.bold())
                            .foregroundStyle(selectedRetention == preset ? .black : .white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                selectedRetention == preset ? Color.orange : Color.white.opacity(0.15),
                                in: Capsule()
                            )
                    }
                    .disabled(camera.isRecording)
                }
            }

            // Fotoğraf / Video Modu
            if !camera.isCameraUnavailable {
                HStack(spacing: 24) {
                    ForEach(CameraCaptureMode.allCases) { mode in
                        Button {
                            withAnimation(.snappy) {
                                camera.captureMode = mode
                            }
                        } label: {
                            Text(mode.title)
                                .font(.caption.bold())
                                .tracking(0.8)
                                .foregroundStyle(camera.captureMode == mode ? .orange : .white.opacity(0.65))
                        }
                        .disabled(camera.isRecording)
                    }
                }
            }

            // Deklanşör Satırı
            HStack {
                // Son Çekilen Önizleme
                Button {
                    if let item = latestActiveItem {
                        previewItem = item
                    } else {
                        onOpenGallery()
                    }
                } label: {
                    recentThumbnailView
                }
                .frame(width: 56, height: 56)

                Spacer()

                // Ana Çekim Tuşu
                Button {
                    handleShutterTap()
                } label: {
                    ZStack {
                        Circle()
                            .stroke(.white, lineWidth: 4)
                            .frame(width: 76, height: 76)

                        if camera.captureMode == .video && !camera.isCameraUnavailable {
                            RoundedRectangle(cornerRadius: camera.isRecording ? 8 : 32)
                                .fill(.red)
                                .frame(
                                    width: camera.isRecording ? 30 : 62,
                                    height: camera.isRecording ? 30 : 62
                                )
                                .animation(.spring(duration: 0.2), value: camera.isRecording)
                        } else {
                            Circle()
                                .fill(.white)
                                .frame(width: 62, height: 62)
                        }
                    }
                }
                .disabled(camera.permissionDenied)

                Spacer()

                // İçe Aktar (Opsiyonel)
                PhotosPicker(selection: $importedPickerItem, matching: .images) {
                    VStack(spacing: 2) {
                        Image(systemName: "square.and.arrow.down")
                            .font(.system(size: 18, weight: .semibold))
                        Text("Aktar")
                            .font(.caption2)
                    }
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 14))
                }
                .disabled(camera.isRecording)
            }
            .padding(.horizontal, 28)
        }
        .padding(.top, 14)
        .padding(.bottom, 18)
        .background(
            LinearGradient(
                colors: [.black.opacity(0.0), .black.opacity(0.75), .black.opacity(0.95)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    @ViewBuilder
    private var recentThumbnailView: some View {
        if let item = latestActiveItem,
           let thumb = MediaStorageService.shared.loadImage(fileName: item.thumbnailFileName ?? item.fileName) {
            Image(uiImage: thumb)
                .resizable()
                .scaledToFill()
                .frame(width: 52, height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(.white.opacity(0.8), lineWidth: 1.5)
                )
        } else {
            RoundedRectangle(cornerRadius: 12)
                .fill(.white.opacity(0.14))
                .frame(width: 52, height: 52)
                .overlay {
                    Image(systemName: "photo.stack")
                        .foregroundStyle(.white.opacity(0.7))
                }
        }
    }

    private var simulatorFallbackView: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 64))
                .foregroundStyle(.orange)

            Text("Simülatör Kamera Modu")
                .font(.title3.bold())
                .foregroundStyle(.white)

            Text("iOS Simülatör'de fiziksel kamera yoktur.\nAşağıdaki deklanşöre basarak test amaçlı demo fotoğraf çekebilir veya sağ alttan fotoğraf aktarabilirsiniz.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.75))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var permissionDeniedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.fill")
                .font(.system(size: 54))
                .foregroundStyle(.orange)

            Text("Kamera İzni Gerekli")
                .font(.title3.bold())
                .foregroundStyle(.white)

            Text("CEK CEK'in kişisel galerinize kaydetmeden çekim yapabilmesi için Ayarlar'dan kamera izni vermeniz gerekir.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.75))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button("Ayarları Aç") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var flashIconName: String {
        switch camera.flashMode {
        case .auto: return "bolt.badge.a.fill"
        case .on: return "bolt.fill"
        case .off: return "bolt.slash.fill"
        @unknown default: return "bolt.badge.a.fill"
        }
    }

    private func handleShutterTap() {
        if camera.isCameraUnavailable {
            triggerFlashFeedback()
            let folderName = activeFolder?.name ?? "Genel"
            if let demoData = MediaStorageService.shared.generateDemoPhotoData(
                folderName: folderName,
                retentionTitle: selectedRetention.title
            ) {
                saveCapturedPhoto(data: demoData)
            }
            return
        }

        switch camera.captureMode {
        case .photo:
            triggerFlashFeedback()
            camera.capturePhoto()
        case .video:
            camera.toggleVideoRecording()
        }
    }

    private func triggerFlashFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        withAnimation(.easeOut(duration: 0.08)) {
            showFlashOverlay = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            withAnimation(.easeOut(duration: 0.15)) {
                showFlashOverlay = false
            }
        }
    }

    private func saveCapturedPhoto(data: Data) {
        do {
            let saved = try MediaStorageService.shared.savePhoto(data: data)
            let item = MediaItem(
                fileName: saved.fileName,
                thumbnailFileName: saved.thumbnailFileName,
                mediaType: .photo,
                expiresAt: selectedRetention.expirationDate(),
                fileSizeBytes: saved.fileSizeBytes,
                folder: activeFolder
            )
            modelContext.insert(item)
            try? modelContext.save()
            NotificationService.shared.scheduleExpirationReminder(for: item, hoursBefore: notificationLeadHours)
            showBanner("Kasaya kaydedildi • \(selectedRetention.title)")
        } catch {
            camera.errorMessage = error.localizedDescription
        }
    }

    private func saveCapturedVideo(tempURL: URL) {
        let retention = selectedRetention
        let folder = activeFolder
        let leadHours = notificationLeadHours

        Task {
            do {
                let saved = try await MediaStorageService.shared.saveVideo(from: tempURL)
                await MainActor.run {
                    let item = MediaItem(
                        fileName: saved.fileName,
                        thumbnailFileName: saved.thumbnailFileName,
                        mediaType: .video,
                        expiresAt: retention.expirationDate(),
                        durationSeconds: saved.durationSeconds,
                        fileSizeBytes: saved.fileSizeBytes,
                        folder: folder
                    )
                    modelContext.insert(item)
                    try? modelContext.save()
                    NotificationService.shared.scheduleExpirationReminder(for: item, hoursBefore: leadHours)
                    showBanner("Video kasaya kaydedildi • \(retention.title)")
                }
            } catch {
                await MainActor.run {
                    camera.errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func importFromPhotosPicker(_ pickerItem: PhotosPickerItem) async {
        guard let data = try? await pickerItem.loadTransferable(type: Data.self) else { return }
        await MainActor.run {
            saveCapturedPhoto(data: data)
        }
    }

    private func showBanner(_ text: String) {
        withAnimation(.spring(duration: 0.25)) {
            statusBanner = text
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            withAnimation(.easeOut(duration: 0.25)) {
                if statusBanner == text {
                    statusBanner = nil
                }
            }
        }
    }
}
