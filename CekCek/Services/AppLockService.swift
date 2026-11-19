import Foundation
import LocalAuthentication

@MainActor
final class AppLockService: ObservableObject {
    @Published var isLocked: Bool = false
    @Published var authErrorMessage: String?

    private let defaultsKey = "isAppLockEnabled"

    var isLockEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: defaultsKey) }
        set {
            objectWillChange.send()
            UserDefaults.standard.set(newValue, forKey: defaultsKey)
            if !newValue {
                isLocked = false
                authErrorMessage = nil
            }
        }
    }

    var biometricName: String {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return "Cihaz Parolası"
        }
        switch context.biometryType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        case .opticID: return "Optic ID"
        default: return "Cihaz Parolası"
        }
    }

    init() {
        if UserDefaults.standard.bool(forKey: defaultsKey) {
            isLocked = true
        }
    }

    func lockIfEnabled() {
        guard isLockEnabled else { return }
        isLocked = true
        authErrorMessage = nil
    }

    func authenticate() async {
        let context = LAContext()
        context.localizedCancelTitle = "Vazgeç"
        var error: NSError?

        let policy: LAPolicy = .deviceOwnerAuthentication
        guard context.canEvaluatePolicy(policy, error: &error) else {
            // Simülatör veya parola ayarlanmamış cihazlarda kullanıcı kilitli kalmasın
            authErrorMessage = "Bu cihazda biyometrik kilit veya parola tanımlı değil."
            isLocked = false
            return
        }

        do {
            let reason = "ÇEK ÇEK geçici galerinize erişmek için kimliğinizi doğrulayın."
            let success = try await context.evaluatePolicy(policy, localizedReason: reason)
            if success {
                isLocked = false
                authErrorMessage = nil
            }
        } catch {
            authErrorMessage = "Doğrulama tamamlanamadı. Tekrar deneyin."
        }
    }
}
