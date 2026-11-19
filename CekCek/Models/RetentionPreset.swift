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
    static let fourteenDays = RetentionDuration(days: 14, hours: 0, minutes: 0)
    static let thirtyDays = RetentionDuration(days: 30, hours: 0, minutes: 0)

    static func fromDays(_ days: Int) -> RetentionDuration {
        RetentionDuration(days: max(1, days), hours: 0, minutes: 0)
    }
}

typealias RetentionPreset = RetentionDuration

@MainActor
final class RetentionSettingsManager: ObservableObject {
    static let shared = RetentionSettingsManager()

    static let minSlotCount = 3
    static let maxSlotCount = 5

    private enum Keys {
        static let slots = "retentionDurationSlotsList"
        static let slot1 = "retentionDurationSlot1"
        static let slot2 = "retentionDurationSlot2"
        static let slot3 = "retentionDurationSlot3"
        static let lastUsed = "lastUsedRetentionDuration"
        static let selectedSlotIndex = "lastSelectedRetentionSlotIndex"
        static let defaultsVersion = "retentionDefaultsVersion"
    }

    private static let currentDefaultsVersion = 3

    @Published var slots: [RetentionDuration] {
        didSet {
            let sanitized = slots.map(\.clamped)
            if sanitized != slots {
                slots = sanitized
                return
            }
            Self.saveSlots(sanitized)
            if selectedSlotIndex >= sanitized.count {
                selectedSlotIndex = max(0, sanitized.count - 1)
            }
            if sanitized.indices.contains(selectedSlotIndex) {
                lastUsedDuration = sanitized[selectedSlotIndex]
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
            let maxIdx = max(0, slots.count - 1)
            let clamped = max(0, min(maxIdx, selectedSlotIndex))
            if clamped != selectedSlotIndex { selectedSlotIndex = clamped; return }
            UserDefaults.standard.set(clamped, forKey: Keys.selectedSlotIndex)
        }
    }

    private init() {
        let defaults = UserDefaults.standard
        let savedVersion = defaults.integer(forKey: Keys.defaultsVersion)
        let isPro = defaults.bool(forKey: "isCekCekProEnabled")

        var initialSlots: [RetentionDuration]
        if let storedList = Self.loadSlots(), storedList.count >= Self.minSlotCount {
            initialSlots = Array(storedList.prefix(Self.maxSlotCount))
        } else {
            let s1 = Self.loadDuration(forKey: Keys.slot1) ?? .oneDay
            let s2 = Self.loadDuration(forKey: Keys.slot2) ?? .sevenDays
            let s3 = Self.loadDuration(forKey: Keys.slot3) ?? .thirtyDays
            initialSlots = [s1, s2, s3]
        }

        if savedVersion < 2 && !isPro {
            initialSlots = [.oneDay, .sevenDays, .thirtyDays]
        }

        let storedIndex = defaults.object(forKey: Keys.selectedSlotIndex) as? Int ?? 1
        let clampedIndex = max(0, min(initialSlots.count - 1, storedIndex))
        let loadedLastUsed = Self.loadDuration(forKey: Keys.lastUsed) ?? initialSlots[clampedIndex]

        self.slots = initialSlots
        self.selectedSlotIndex = clampedIndex
        self.lastUsedDuration = loadedLastUsed.clamped

        Self.saveSlots(initialSlots)
        defaults.set(Self.currentDefaultsVersion, forKey: Keys.defaultsVersion)
    }

    var activePresets: [RetentionDuration] {
        slots
    }

    var uniqueActivePresets: [RetentionDuration] {
        var result: [RetentionDuration] = []
        for preset in slots where !result.contains(preset) {
            result.append(preset)
        }
        return result
    }

    var canAddSlot: Bool {
        slots.count < Self.maxSlotCount
    }

    var canRemoveSlot: Bool {
        slots.count > Self.minSlotCount
    }

    func slot(at index: Int) -> RetentionDuration {
        guard slots.indices.contains(index) else {
            return slots.first ?? .sevenDays
        }
        return slots[index]
    }

    func selectSlot(index: Int) {
        guard slots.indices.contains(index) else { return }
        selectedSlotIndex = index
        lastUsedDuration = slots[index]
    }

    func updateSlot(at index: Int, to duration: RetentionDuration) {
        guard slots.indices.contains(index) else { return }
        let safe = duration.clamped
        slots[index] = safe
        if selectedSlotIndex == index {
            lastUsedDuration = safe
        }
    }

    func addSlot(_ duration: RetentionDuration) {
        guard canAddSlot else { return }
        let safe = duration.clamped
        slots.append(safe)
        selectedSlotIndex = slots.count - 1
        lastUsedDuration = safe
    }

    func removeSlot(at index: Int) {
        guard canRemoveSlot, slots.indices.contains(index) else { return }
        slots.remove(at: index)
        if selectedSlotIndex >= slots.count {
            selectedSlotIndex = max(0, slots.count - 1)
        }
        lastUsedDuration = slots[selectedSlotIndex]
    }

    func resetToDefaults() {
        slots = [.oneDay, .sevenDays, .thirtyDays]
        selectedSlotIndex = 1
        lastUsedDuration = .sevenDays
    }

    private static func saveSlots(_ list: [RetentionDuration]) {
        if let data = try? JSONEncoder().encode(list) {
            UserDefaults.standard.set(data, forKey: Keys.slots)
        }
    }

    private static func loadSlots() -> [RetentionDuration]? {
        guard let data = UserDefaults.standard.data(forKey: Keys.slots),
              let decoded = try? JSONDecoder().decode([RetentionDuration].self, from: data) else {
            return nil
        }
        return decoded.map(\.clamped)
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
