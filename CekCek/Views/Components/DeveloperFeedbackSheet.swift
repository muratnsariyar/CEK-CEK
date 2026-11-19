import SwiftUI
import UIKit

enum FeedbackCategory: String, CaseIterable, Identifiable {
    case bug = "Hata Bildirimi"
    case suggestion = "Özellik Önerisi"
    case general = "Genel Görüş"

    var id: String { rawValue }
}

struct DeveloperFeedbackSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var category: FeedbackCategory = .bug
    @State private var message: String = ""
    @State private var includeDeviceInfo: Bool = true
    @State private var alertMessage: String?

    private let developerEmail = "murat.nazimsariyar@gmail.com"

    private var appVersionText: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    private var deviceSummary: String {
        let device = UIDevice.current
        return """
        ---
        Uygulama: ÇEK ÇEK \(appVersionText)
        Cihaz: \(device.model) (\(device.systemName) \(device.systemVersion))
        """
    }

    private var fullEmailBody: String {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        if includeDeviceInfo {
            return "\(trimmed)\n\n\(deviceSummary)"
        }
        return trimmed
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Konu") {
                    Picker("Bildirim Türü", selection: $category) {
                        ForEach(FeedbackCategory.allCases) { item in
                            Text(item.rawValue).tag(item)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    ZStack(alignment: .topLeading) {
                        if message.isEmpty {
                            Text("Karşılaştığınız sorunu veya önerinizi buraya yazın...")
                                .foregroundStyle(.tertiary)
                                .padding(.top, 8)
                                .padding(.leading, 4)
                        }
                        TextEditor(text: $message)
                            .frame(minHeight: 140)
                    }
                } header: {
                    Text("Mesajınız")
                }

                Section {
                    Toggle("Cihaz ve Sürüm Bilgisini Ekle", isOn: $includeDeviceInfo)
                    if includeDeviceInfo {
                        Text(deviceSummary)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    Button {
                        sendViaMailApp()
                    } label: {
                        Label("Mail Uygulaması ile Gönder", systemImage: "paperplane.fill")
                            .fontWeight(.semibold)
                            .foregroundStyle(.orange)
                    }
                    .disabled(message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    Button {
                        copyFeedbackToClipboard()
                    } label: {
                        Label("Mesajı Panoya Kopyala", systemImage: "doc.on.doc")
                    }
                    .disabled(message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                } footer: {
                    Text("Geri bildirimleriniz doğrudan geliştiriciye (\(developerEmail)) iletilir.")
                }
            }
            .navigationTitle("Geliştiriciye Bildir")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Kapat") {
                        dismiss()
                    }
                }
            }
            .alert("ÇEK ÇEK", isPresented: Binding(
                get: { alertMessage != nil },
                set: { if !$0 { alertMessage = nil } }
            )) {
                Button("Tamam", role: .cancel) {}
            } message: {
                Text(alertMessage ?? "")
            }
        }
    }

    private func sendViaMailApp() {
        let subject = "[ÇEK ÇEK] \(category.rawValue)"
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = developerEmail
        components.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: fullEmailBody)
        ]

        guard let url = components.url else {
            alertMessage = "E-posta bağlantısı oluşturulamadı."
            return
        }

        openURL(url) { accepted in
            if accepted {
                dismiss()
            } else {
                copyFeedbackToClipboard()
                alertMessage = "Cihazda varsayılan Mail uygulaması bulunamadı. Mesajınız ve alıcı adresi panoya kopyalandı."
            }
        }
    }

    private func copyFeedbackToClipboard() {
        UIPasteboard.general.string = "Alıcı: \(developerEmail)\nKonu: [ÇEK ÇEK] \(category.rawValue)\n\n\(fullEmailBody)"
        alertMessage = "Geri bildirim metni panoya kopyalandı."
    }
}
