import Foundation

@MainActor
final class MonetizationService: ObservableObject {
    static let shared = MonetizationService()
    static let freeAdQuota: Int = 50

    private enum Keys {
        static let totalUsageCount = "totalCaptureUsageCount"
        static let isPro = "isCekCekProEnabled"
    }

    @Published var totalUsageCount: Int {
        didSet {
            UserDefaults.standard.set(totalUsageCount, forKey: Keys.totalUsageCount)
        }
    }

    @Published var isPro: Bool {
        didSet {
            UserDefaults.standard.set(isPro, forKey: Keys.isPro)
            if isPro {
                showInterstitialAd = false
            }
        }
    }

    @Published var showInterstitialAd: Bool = false
    @Published var showProPaywall: Bool = false

    private init() {
        let defaults = UserDefaults.standard
        self.totalUsageCount = defaults.integer(forKey: Keys.totalUsageCount)
        self.isPro = defaults.bool(forKey: Keys.isPro)
    }

    var remainingAdFreeUsages: Int {
        max(0, Self.freeAdQuota - totalUsageCount)
    }

    var shouldShowAds: Bool {
        !isPro && totalUsageCount >= Self.freeAdQuota
    }

    func recordCapture() {
        totalUsageCount += 1
        if shouldShowAds && (totalUsageCount - Self.freeAdQuota) % 3 == 0 {
            showInterstitialAd = true
        }
    }

    func simulateQuotaExhausted() {
        totalUsageCount = Self.freeAdQuota
    }

    func resetUsageQuota() {
        totalUsageCount = 0
        showInterstitialAd = false
    }
}
