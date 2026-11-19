import Foundation
import SwiftData
import SwiftUI

@Model
final class MediaFolder {
    var id: UUID
    var name: String
    var iconName: String
    var colorHex: String
    var defaultRetentionDays: Int
    var createdAt: Date
    var isSystemDefault: Bool

    @Relationship(deleteRule: .nullify, inverse: \MediaItem.folder)
    var items: [MediaItem] = []

    init(
        id: UUID = UUID(),
        name: String,
        iconName: String = "folder.fill",
        colorHex: String = "#FF9500",
        defaultRetentionDays: Int = 3,
        createdAt: Date = .now,
        isSystemDefault: Bool = false
    ) {
        self.id = id
        self.name = name
        self.iconName = iconName
        self.colorHex = colorHex
        self.defaultRetentionDays = defaultRetentionDays
        self.createdAt = createdAt
        self.isSystemDefault = isSystemDefault
    }

    var color: Color {
        Color(hex: colorHex) ?? .orange
    }

    var activeItems: [MediaItem] {
        items.filter { !$0.isExpired }
    }

    var defaultPreset: RetentionPreset {
        RetentionPreset.fromDays(defaultRetentionDays)
    }

    @MainActor
    static func seedDefaultsIfNeeded(in context: ModelContext) {
        let descriptor = FetchDescriptor<MediaFolder>()
        let existingCount = (try? context.fetchCount(descriptor)) ?? 0
        guard existingCount == 0 else { return }

        let defaults: [MediaFolder] = [
            MediaFolder(
                name: "Genel",
                iconName: "tray.fill",
                colorHex: "#007AFF",
                defaultRetentionDays: 3,
                isSystemDefault: true
            ),
            MediaFolder(
                name: "İş",
                iconName: "briefcase.fill",
                colorHex: "#FF9500",
                defaultRetentionDays: 7
            ),
            MediaFolder(
                name: "Fiş & Evrak",
                iconName: "doc.text.fill",
                colorHex: "#34C759",
                defaultRetentionDays: 30
            ),
            MediaFolder(
                name: "Hızlı Not",
                iconName: "bolt.fill",
                colorHex: "#AF52DE",
                defaultRetentionDays: 1
            )
        ]

        for folder in defaults {
            context.insert(folder)
        }
        try? context.save()
    }
}

extension Color {
    init?(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        guard cleaned.count == 6, let value = UInt64(cleaned, radix: 16) else {
            return nil
        }
        let r = Double((value >> 16) & 0xFF) / 255.0
        let g = Double((value >> 8) & 0xFF) / 255.0
        let b = Double(value & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}
