import Foundation

enum RetentionPreset: String, CaseIterable, Identifiable, Codable {
    case sixHours
    case oneDay
    case threeDays
    case sevenDays
    case thirtyDays

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sixHours: return "6 Saat"
        case .oneDay: return "1 Gün"
        case .threeDays: return "3 Gün"
        case .sevenDays: return "7 Gün"
        case .thirtyDays: return "30 Gün"
        }
    }

    var shortLabel: String {
        switch self {
        case .sixHours: return "6s"
        case .oneDay: return "1g"
        case .threeDays: return "3g"
        case .sevenDays: return "7g"
        case .thirtyDays: return "30g"
        }
    }

    var timeInterval: TimeInterval {
        switch self {
        case .sixHours: return 6 * 3600
        case .oneDay: return 24 * 3600
        case .threeDays: return 3 * 24 * 3600
        case .sevenDays: return 7 * 24 * 3600
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
        case 2...4: return .threeDays
        case 5...14: return .sevenDays
        default: return .thirtyDays
        }
    }
}
