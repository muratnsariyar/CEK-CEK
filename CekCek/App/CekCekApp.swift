import SwiftData
import SwiftUI

@main
struct CekCekApp: App {
    let modelContainer: ModelContainer

    init() {
        let schema = Schema([
            MediaItem.self,
            MediaFolder.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            modelContainer = try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("SwiftData ModelContainer oluşturulamadı: \(error)")
        }

        ExpirationService.registerBackgroundTask(modelContainer: modelContainer)
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
        }
        .modelContainer(modelContainer)
    }
}
