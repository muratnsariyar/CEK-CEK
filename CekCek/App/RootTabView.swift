import SwiftData
import SwiftUI

enum MainTab: Hashable {
    case camera
    case gallery
    case folders
    case settings
}

struct RootTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("startOnCameraTab") private var startOnCameraTab: Bool = true

    @StateObject private var lockService = AppLockService()
    @State private var selectedTab: MainTab = .camera
    @State private var didConfigureInitialTab = false

    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                CameraTabView(onOpenGallery: {
                    selectedTab = .gallery
                })
                .tabItem {
                    Label("Çek", systemImage: "camera.fill")
                }
                .tag(MainTab.camera)

                GalleryTabView()
                    .tabItem {
                        Label("Galeri", systemImage: "photo.stack.fill")
                    }
                    .tag(MainTab.gallery)

                FoldersTabView()
                    .tabItem {
                        Label("Klasörler", systemImage: "folder.fill")
                    }
                    .tag(MainTab.folders)

                SettingsTabView(lockService: lockService)
                    .tabItem {
                        Label("Ayarlar", systemImage: "gearshape.fill")
                    }
                    .tag(MainTab.settings)
            }
            .tint(.orange)

            if lockService.isLocked {
                LockScreenOverlay(lockService: lockService)
                    .transition(.opacity)
            }
        }
        .onAppear {
            if !didConfigureInitialTab {
                selectedTab = startOnCameraTab ? .camera : .gallery
                didConfigureInitialTab = true
            }
            MediaFolder.seedDefaultsIfNeeded(in: modelContext)
            ExpirationService.purgeExpiredItems(in: modelContext)
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                ExpirationService.purgeExpiredItems(in: modelContext)
            case .background:
                lockService.lockIfEnabled()
                ExpirationService.scheduleNextBackgroundCleanup()
            default:
                break
            }
        }
    }
}
