import SwiftUI

struct LockScreenOverlay: View {
    @ObservedObject var lockService: AppLockService

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.orange)

                VStack(spacing: 8) {
                    Text("CEK CEK Kilitli")
                        .font(.title2.bold())

                    Text("Geçici galerinize erişmek için \(lockService.biometricName) doğrulaması yapın.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                if let error = lockService.authErrorMessage {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                Button {
                    Task {
                        await lockService.authenticate()
                    }
                } label: {
                    Label("\(lockService.biometricName) ile Aç", systemImage: "faceid")
                        .font(.headline)
                        .frame(minWidth: 200)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
            }
            .padding()
        }
        .task {
            await lockService.authenticate()
        }
    }
}
