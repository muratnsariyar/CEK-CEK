import Foundation
import SwiftData

enum MediaType: String, Codable {
    case photo
    case video

    var displayName: String {
        switch self {
        case .photo: return "Fotoğraf"
        case .video: return "Video"
        }
    }

    var iconName: String {
        switch self {
        case .photo: return "photo"
        case .video: return "video.fill"
        }
    }
}

@Model
final class MediaItem {
    var id: UUID
    var fileName: String
    var thumbnailFileName: String?
    var mediaTypeRaw: String
    var createdAt: Date
    var expiresAt: Date
    var note: String
    var durationSeconds: Double?
    var fileSizeBytes: Int64
    var folder: MediaFolder?

    init(
        id: UUID = UUID(),
        fileName: String,
        thumbnailFileName: String? = nil,
        mediaType: MediaType,
        createdAt: Date = .now,
        expiresAt: Date,
        note: String = "",
        durationSeconds: Double? = nil,
        fileSizeBytes: Int64 = 0,
        folder: MediaFolder? = nil
    ) {
        self.id = id
        self.fileName = fileName
        self.thumbnailFileName = thumbnailFileName
        self.mediaTypeRaw = mediaType.rawValue
        self.createdAt = createdAt
        self.expiresAt = expiresAt
        self.note = note
        self.durationSeconds = durationSeconds
        self.fileSizeBytes = fileSizeBytes
        self.folder = folder
    }

    var mediaType: MediaType {
        get { MediaType(rawValue: mediaTypeRaw) ?? .photo }
        set { mediaTypeRaw = newValue.rawValue }
    }

    var isExpired: Bool {
        expiresAt <= Date()
    }

    var remainingInterval: TimeInterval {
        max(0, expiresAt.timeIntervalSinceNow)
    }

    var isExpiringSoon: Bool {
        remainingInterval < 24 * 3600
    }

    var isCritical: Bool {
        remainingInterval < 6 * 3600
    }

    var remainingBadgeText: String {
        let seconds = expiresAt.timeIntervalSinceNow
        if seconds <= 0 {
            return "Doldu"
        }
        if seconds < 60 {
            return "\(max(1, Int(seconds.rounded()))) sn"
        }
        let minutes = Int(seconds / 60)
        if minutes < 60 {
            return "\(minutes) dk"
        }
        let hours = Int(seconds / 3600)
        if hours < 24 {
            return "\(hours) sa"
        }
        let days = Int(ceil(seconds / 86400))
        return "\(days) gün"
    }

    var formattedDuration: String? {
        guard let durationSeconds, durationSeconds > 0 else { return nil }
        let total = Int(durationSeconds.rounded())
        let mins = total / 60
        let secs = total % 60
        return String(format: "%02d:%02d", mins, secs)
    }

    var formattedFileSize: String {
        ByteCountFormatter.string(fromByteCount: fileSizeBytes, countStyle: .file)
    }

    func extend(by preset: RetentionPreset) {
        let base = max(Date(), expiresAt)
        expiresAt = preset.expirationDate(from: base)
    }
}
