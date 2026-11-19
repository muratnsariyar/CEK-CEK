import Foundation

struct RetentionDuration: Codable, Equatable, Hashable, Identifiable {
    var days: Int
    var hours: Int
    var minutes: Int

    init(days: Int = 0, hours: Int = 0, minutes: Int = 0) {
        let clampedDays = max(0, min(30, days))
        let clampedHours = max(0, min(23, hours))
        var clampedMinutes = max(0, min(59, minutes))
        if clampedDays == 0 && clampedHours == 0 && clampedMinutes < 1 {
            clampedMinutes = 1
        }
        self.days = clampedDays
        self.hours = clampedHours
        self.minutes = clampedMinutes
    }

    var clamped: RetentionDuration {
        RetentionDuration(days: days, hours: hours, minutes: minutes)
    }

    var id: String {
        "\(days)d_\(hours)h_\(minutes)m"
    }

    var timeInterval: TimeInterval {
        let safe = clamped
        return TimeInterval(safe.days * 86400 + safe.hours * 3600 + safe.minutes * 60)
    }

    var title: String {
        let safe = clamped
        var parts: [String] = []
        if safe.days > 0 { parts.append("\(safe.days) Gün") }
        if safe.hours > 0 { parts.append("\(safe.hours) Saat") }
        if safe.minutes > 0 { parts.append("\(safe.minutes) Dk") }
        return parts.isEmpty ? "1 Dk" : parts.joined(separator: " ")
    }

    var shortLabel: String {
        let safe = clamped
        var parts: [String] = []
        if safe.days > 0 { parts.append("\(safe.days)g") }
        if safe.hours > 0 { parts.append("\(safe.hours)s") }
        if safe.minutes > 0 { parts.append("\(safe.minutes)dk") }
        return parts.isEmpty ? "1dk" : parts.joined(separator: " ")
    }

    func expirationDate(from baseDate: Date = .now) -> Date {
        baseDate.addingTimeInterval(timeInterval)
    }

    static let oneDay = RetentionDuration(days: 1, hours: 0, minutes: 0)
    static let threeDays = RetentionDuration(days: 3, hours: 0, minutes: 0)
    static let sevenDays = RetentionDuration(days: 7, hours: 0, minutes: 0)

    static func fromDays(_ days: Int) -> RetentionDuration {
        RetentionDuration(days: max(1, days), hours: 0, minutes: 0)
    }
}

typealias RetentionPreset = RetentionDuration

@MainActor
final class RetentionSettingsManager: ObservableObject {
    static let shared = RetentionSettingsManager()

    private enum Keys {
        static let slot1 = "retentionDurationSlot1"
        static let slot2 = "retentionDurationSlot2"
        static let slot3 = "retentionDurationSlot3"
        static let lastUsed = "lastUsedRetentionDuration"
        static let selectedSlotIndex = "lastSelectedRetentionSlotIndex"
    }

    @Published var slot1: RetentionDuration {
        didSet {
            let safe = slot1.clamped
            if safe != slot1 { slot1 = safe; return }
            Self.saveDuration(safe, forKey: Keys.slot1)
            if selectedSlotIndex == 0 {
                lastUsedDuration = safe
            }
        }
    }

    @Published var slot2: RetentionDuration {
        didSet {
            let safe = slot2.clamped
            if safe != slot2 { slot2 = safe; return }
            Self.saveDuration(safe, forKey: Keys.slot2)
            if selectedSlotIndex == 1 {
                lastUsedDuration = safe
            }
        }
    }

    @Published var slot3: RetentionDuration {
        didSet {
            let safe = slot3.clamped
            if safe != slot3 { slot3 = safe; return }
            Self.saveDuration(safe, forKey: Keys.slot3)
            if selectedSlotIndex == 2 {
                lastUsedDuration = safe
            }
        }
    }

    @Published var lastUsedDuration: RetentionDuration {
        didSet {
            let safe = lastUsedDuration.clamped
            if safe != lastUsedDuration { lastUsedDuration = safe; return }
            Self.saveDuration(safe, forKey: Keys.lastUsed)
        }
    }

    @Published var selectedSlotIndex: Int {
        didSet {
            let clamped = max(0, min(2, selectedSlotIndex))
            if clamped != selectedSlotIndex { selectedSlotIndex = clamped; return }
            UserDefaults.standard.set(clamped, forKey: Keys.selectedSlotIndex)
        }
    }

    private init() {
        let defaults = UserDefaults.standard
        let s1 = Self.loadDuration(forKey: Keys.slot1) ?? .oneDay
        let s2 = Self.loadDuration(forKey: Keys.slot2) ?? .threeDays
        let s3 = Self.loadDuration(forKey: Keys.slot3) ?? .sevenDays

        let storedIndex = defaults.object(forKey: Keys.selectedSlotIndex) as? Int ?? 1
        let clampedIndex = max(0, min(2, storedIndex))
        let active = [s1, s2, s3]
        let loadedLastUsed = Self.loadDuration(forKey: Keys.lastUsed) ?? active[clampedIndex]

        self.slot1 = s1
        self.slot2 = s2
        self.slot3 = s3
        self.selectedSlotIndex = clampedIndex
        self.lastUsedDuration = loadedLastUsed.clamped
    }

    var activePresets: [RetentionDuration] {
        [slot1, slot2, slot3]
    }

    var uniqueActivePresets: [RetentionDuration] {
        var result: [RetentionDuration] = []
        for preset in activePresets where !result.contains(preset) {
            result.append(preset)
        }
        return result
    }

    func slot(at index: Int) -> RetentionDuration {
        switch index {
        case 0: return slot1
        case 1: return slot2
        case 2: return slot3
        default: return slot2
        }
    }

    func selectSlot(index: Int) {
        let clamped = max(0, min(2, index))
        selectedSlotIndex = clamped
        lastUsedDuration = activePresets[clamped]
    }

    func updateSlot(at index: Int, to duration: RetentionDuration) {
        let safe = duration.clamped
        switch index {
        case 0: slot1 = safe
        case 1: slot2 = safe
        case 2: slot3 = safe
        default: break
        }
        if selectedSlotIndex == index {
            lastUsedDuration = safe
        }
    }

    func resetToDefaults() {
        slot1 = .oneDay
        slot2 = .threeDays
        slot3 = .sevenDays
        selectedSlotIndex = 1
        lastUsedDuration = .threeDays
    }

    private static func saveDuration(_ duration: RetentionDuration, forKey key: String) {
        if let data = try? JSONEncoder().encode(duration) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private static func loadDuration(forKey key: String) -> RetentionDuration? {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode(RetentionDuration.self, from: data) else {
            return nil
        }
        return decoded.clamped
    }
}
