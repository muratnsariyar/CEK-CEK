import Foundation

@MainActor
final class MonetizationService: ObservableObject {
    static let shared = MonetizationService()
    static let freeActiveLimit: Int = 50
    private static let interstitialFrequency: Int = 4

    private enum Keys {
        static let isPro = "isCekCekProEnabled"
    }

    @Published var activeItemCount: Int = 0
    @Published var simulateLimitExceeded: Bool = false

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

    private var capturesWhileOverLimit: Int = 0

    private init() {
        self.isPro = UserDefaults.standard.bool(forKey: Keys.isPro)
    }

    var effectiveActiveCount: Int {
        simulateLimitExceeded ? (Self.freeActiveLimit + 1) : activeItemCount
    }

    var remainingAdFreeUsages: Int {
        max(0, Self.freeActiveLimit - effectiveActiveCount)
    }

    var shouldShowAds: Bool {
        !isPro && effectiveActiveCount > Self.freeActiveLimit
    }

    func updateActiveCount(_ count: Int) {
        activeItemCount = max(0, count)
        if !shouldShowAds {
            showInterstitialAd = false
            capturesWhileOverLimit = 0
        }
    }

    func recordCapture(newActiveCount: Int) {
        updateActiveCount(newActiveCount)
        guard shouldShowAds else { return }

        capturesWhileOverLimit += 1
        if capturesWhileOverLimit == 1 || capturesWhileOverLimit % Self.interstitialFrequency == 0 {
            showInterstitialAd = true
        }
    }
}
