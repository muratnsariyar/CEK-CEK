import Foundation
import UserNotifications

@MainActor
final class NotificationService: ObservableObject {
    static let shared = NotificationService()

    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined

    private let center = UNUserNotificationCenter.current()

    private init() {
        Task {
            await refreshAuthorizationStatus()
        }
    }

    func refreshAuthorizationStatus() async {
        let settings = await center.notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }

    func requestAuthorization() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            await refreshAuthorizationStatus()
            return granted
        } catch {
            await refreshAuthorizationStatus()
            return false
        }
    }

    func scheduleExpirationReminder(for item: MediaItem, hoursBefore: Int) {
        let enabled = UserDefaults.standard.bool(forKey: "notificationsEnabled")
        guard enabled else { return }

        let identifier = reminderIdentifier(for: item.id)
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        let leadTime = TimeInterval(max(1, hoursBefore) * 3600)
        let fireDate = item.expiresAt.addingTimeInterval(-leadTime)
        guard fireDate > Date().addingTimeInterval(60) else { return }

        let content = UNMutableNotificationContent()
        content.title = "ÇEK ÇEK — Süre Dolmak Üzere"
        let folderLabel = item.folder?.name ?? "Genel"
        content.body = "\"\(folderLabel)\" klasöründeki bir \(item.mediaType.displayName.lowercased()) \(hoursBefore) saat içinde otomatik silinecek."
        content.sound = .default

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: fireDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        center.add(request)
    }

    func cancelReminder(for itemID: UUID) {
        let identifier = reminderIdentifier(for: itemID)
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        center.removeDeliveredNotifications(withIdentifiers: [identifier])
    }

    func rescheduleAllReminders(for items: [MediaItem], enabled: Bool, hoursBefore: Int) {
        center.removeAllPendingNotificationRequests()
        guard enabled else { return }

        let upcoming = items
            .filter { !$0.isExpired }
            .sorted { $0.expiresAt < $1.expiresAt }
            .prefix(50)

        for item in upcoming {
            scheduleExpirationReminder(for: item, hoursBefore: hoursBefore)
        }
    }

    private func reminderIdentifier(for itemID: UUID) -> String {
        "cekcek.expire.\(itemID.uuidString)"
    }
}
