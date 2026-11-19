import BackgroundTasks
import Foundation
import SwiftData

enum ExpirationService {
    static let backgroundTaskIdentifier = "com.cekcek.app.cleanup"

    @MainActor
    @discardableResult
    static func purgeExpiredItems(in context: ModelContext) -> Int {
        let descriptor = FetchDescriptor<MediaItem>()
        guard let allItems = try? context.fetch(descriptor) else { return 0 }

        let now = Date()
        var deletedCount = 0
        var activeCount = 0
        var validFileNames = Set<String>()

        for item in allItems {
            if item.expiresAt <= now {
                MediaStorageService.shared.deleteFiles(
                    fileName: item.fileName,
                    thumbnailFileName: item.thumbnailFileName
                )
                NotificationService.shared.cancelReminder(for: item.id)
                context.delete(item)
                deletedCount += 1
            } else {
                activeCount += 1
                validFileNames.insert(item.fileName)
                if let thumb = item.thumbnailFileName {
                    validFileNames.insert(thumb)
                }
            }
        }

        if deletedCount > 0 {
            try? context.save()
        }

        MediaStorageService.shared.cleanupOrphanedFiles(validFileNames: validFileNames)
        MonetizationService.shared.updateActiveCount(activeCount)
        return deletedCount
    }

    @MainActor
    static func activeMediaCount(in context: ModelContext) -> Int {
        let now = Date()
        let descriptor = FetchDescriptor<MediaItem>()
        guard let allItems = try? context.fetch(descriptor) else { return 0 }
        return allItems.filter { $0.expiresAt > now }.count
    }

    @MainActor
    static func deleteItem(_ item: MediaItem, in context: ModelContext) {
        MediaStorageService.shared.deleteFiles(
            fileName: item.fileName,
            thumbnailFileName: item.thumbnailFileName
        )
        NotificationService.shared.cancelReminder(for: item.id)
        context.delete(item)
        try? context.save()
        MonetizationService.shared.updateActiveCount(activeMediaCount(in: context))
    }

    @MainActor
    static func purgeAllItems(in context: ModelContext) {
        let descriptor = FetchDescriptor<MediaItem>()
        guard let allItems = try? context.fetch(descriptor) else { return }

        for item in allItems {
            MediaStorageService.shared.deleteFiles(
                fileName: item.fileName,
                thumbnailFileName: item.thumbnailFileName
            )
            NotificationService.shared.cancelReminder(for: item.id)
            context.delete(item)
        }
        try? context.save()
        MediaStorageService.shared.cleanupOrphanedFiles(validFileNames: [])
        MonetizationService.shared.updateActiveCount(0)
    }

    static func registerBackgroundTask(modelContainer: ModelContainer) {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: backgroundTaskIdentifier,
            using: nil
        ) { task in
            guard let refreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            scheduleNextBackgroundCleanup()

            let work = Task { @MainActor in
                let context = ModelContext(modelContainer)
                _ = purgeExpiredItems(in: context)
                refreshTask.setTaskCompleted(success: true)
            }

            refreshTask.expirationHandler = {
                work.cancel()
                refreshTask.setTaskCompleted(success: false)
            }
        }
    }

    static func scheduleNextBackgroundCleanup() {
        let request = BGAppRefreshTaskRequest(identifier: backgroundTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 60 * 60) // En erken 1 saat sonra
        try? BGTaskScheduler.shared.submit(request)
    }
}
