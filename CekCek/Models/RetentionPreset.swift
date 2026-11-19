import Foundation

enum RetentionPreset: String, CaseIterable, Identifiable, Codable {
    case oneHour
    case threeHours
    case sixHours
    case twelveHours
    case oneDay
    case twoDays
    case threeDays
    case fiveDays
    case sevenDays
    case fourteenDays
    case thirtyDays

    var id: String { rawValue }

    var title: String {
        switch self {
        case .oneHour: return "1 Saat"
        case .threeHours: return "3 Saat"
        case .sixHours: return "6 Saat"
        case .twelveHours: return "12 Saat"
        case .oneDay: return "1 Gün"
        case .twoDays: return "2 Gün"
        case .threeDays: return "3 Gün"
        case .fiveDays: return "5 Gün"
        case .sevenDays: return "7 Gün"
        case .fourteenDays: return "14 Gün"
        case .thirtyDays: return "30 Gün"
        }
    }

    var shortLabel: String {
        switch self {
        case .oneHour: return "1s"
        case .threeHours: return "3s"
        case .sixHours: return "6s"
        case .twelveHours: return "12s"
        case .oneDay: return "1g"
        case .twoDays: return "2g"
        case .threeDays: return "3g"
        case .fiveDays: return "5g"
        case .sevenDays: return "7g"
        case .fourteenDays: return "14g"
        case .thirtyDays: return "30g"
        }
    }

    var timeInterval: TimeInterval {
        switch self {
        case .oneHour: return 1 * 3600
        case .threeHours: return 3 * 3600
        case .sixHours: return 6 * 3600
        case .twelveHours: return 12 * 3600
        case .oneDay: return 24 * 3600
        case .twoDays: return 2 * 24 * 3600
        case .threeDays: return 3 * 24 * 3600
        case .fiveDays: return 5 * 24 * 3600
        case .sevenDays: return 7 * 24 * 3600
        case .fourteenDays: return 14 * 24 * 3600
        case .thirtyDays: return 30 * 24 * 3600
        }
    }

    func expirationDate(from baseDate: Date = .now) -> Date {
        baseDate.addingTimeInterval(timeInterval)
    }

    static func fromDays(_ days: Int) -> RetentionPreset {
        switch days {
        case ...0: return .sixHours
        case 1: return .oneDay
        case 2: return .twoDays
        case 3...4: return .threeDays
        case 5...6: return .fiveDays
        case 7...10: return .sevenDays
        case 11...20: return .fourteenDays
        default: return .thirtyDays
        }
    }
}

@MainActor
final class RetentionSettingsManager: ObservableObject {
    static let shared = RetentionSettingsManager()

    private enum Keys {
        static let slot1 = "retentionSlot1"
        static let slot2 = "retentionSlot2"
        static let slot3 = "retentionSlot3"
        static let defaultPreset = "defaultRetentionPreset"
    }

    @Published var slot1: RetentionPreset {
        didSet {
            UserDefaults.standard.set(slot1.rawValue, forKey: Keys.slot1)
            ensureValidDefault()
        }
    }

    @Published var slot2: RetentionPreset {
        didSet {
            UserDefaults.standard.set(slot2.rawValue, forKey: Keys.slot2)
            ensureValidDefault()
        }
    }

    @Published var slot3: RetentionPreset {
        didSet {
            UserDefaults.standard.set(slot3.rawValue, forKey: Keys.slot3)
            ensureValidDefault()
        }
    }

    @Published var defaultPreset: RetentionPreset {
        didSet {
            UserDefaults.standard.set(defaultPreset.rawValue, forKey: Keys.defaultPreset)
        }
    }

    private init() {
        let defaults = UserDefaults.standard
        let s1 = defaults.string(forKey: Keys.slot1).flatMap(RetentionPreset.init(rawValue:)) ?? .oneDay
        let s2 = defaults.string(forKey: Keys.slot2).flatMap(RetentionPreset.init(rawValue:)) ?? .threeDays
        let s3 = defaults.string(forKey: Keys.slot3).flatMap(RetentionPreset.init(rawValue:)) ?? .sevenDays
        let def = defaults.string(forKey: Keys.defaultPreset).flatMap(RetentionPreset.init(rawValue:)) ?? .threeDays

        self.slot1 = s1
        self.slot2 = s2
        self.slot3 = s3
        self.defaultPreset = [s1, s2, s3].contains(def) ? def : s2
    }

    var activePresets: [RetentionPreset] {
        [slot1, slot2, slot3]
    }

    var uniqueActivePresets: [RetentionPreset] {
        var result: [RetentionPreset] = []
        for preset in activePresets where !result.contains(preset) {
            result.append(preset)
        }
        return result
    }

    func resetToDefaults() {
        slot1 = .oneDay
        slot2 = .threeDays
        slot3 = .sevenDays
        defaultPreset = .threeDays
    }

    private func ensureValidDefault() {
        if !activePresets.contains(defaultPreset) {
            defaultPreset = slot1
        }
    }
}
