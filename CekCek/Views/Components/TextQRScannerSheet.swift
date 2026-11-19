import SwiftUI
import UIKit

struct TextQRScannerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    let result: ScanAnalysisResult
    let isScanning: Bool

    @State private var editableFullText: String = ""
    @State private var copiedToast: String?

    var body: some View {
        NavigationStack {
            Group {
                if isScanning {
                    VStack(spacing: 14) {
                        ProgressView()
                            .controlSize(.large)
                        Text("Fotoğraftaki metin ve QR kodlar taranıyor...")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if !result.hasAnyContent {
                    ContentUnavailableView {
                        Label("Metin veya QR Bulunamadı", systemImage: "text.viewfinder")
                    } description: {
                        Text("Bu fotoğrafta okunabilir bir yazı veya QR kod algılanmadı.")
                    }
                } else {
                    List {
                        if result.hasQR {
                            Section("Algılanan QR / Barkod") {
                                ForEach(result.qrItems) { qr in
                                    VStack(alignment: .leading, spacing: 10) {
                                        HStack {
                                            Label(qr.typeTitle, systemImage: "qrcode")
                                                .font(.caption.bold())
                                                .foregroundStyle(.orange)
                                            Spacer()
                                        }

                                        Text(qr.payload)
                                            .font(.subheadline.monospaced())
                                            .textSelection(.enabled)

                                        HStack(spacing: 12) {
                                            Button {
                                                copyToClipboard(qr.payload, label: "\(qr.typeTitle) kopyalandı")
                                            } label: {
                                                Label("Kopyala", systemImage: "doc.on.doc")
                                                    .font(.caption.bold())
                                            }
                                            .buttonStyle(.borderedProminent)
                                            .tint(.orange)

                                            if let url = qr.webURL {
                                                Button {
                                                    openURL(url)
                                                } label: {
                                                    Label("Bağlantıyı Aç", systemImage: "safari")
                                                        .font(.caption.bold())
                                                }
                                                .buttonStyle(.bordered)
                                            }
                                        }
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                        }

                        if result.hasText {
                            Section {
                                Button {
                                    copyToClipboard(editableFullText, label: "Tüm metin kopyalandı")
                                } label: {
                                    HStack {
                                        Label("Tüm Metni Kopyala", systemImage: "doc.on.doc.fill")
                                            .font(.subheadline.bold())
                                        Spacer()
                                        Text("\(result.textLines.count) satır")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .tint(.orange)

                                TextEditor(text: $editableFullText)
                                    .font(.subheadline)
                                    .frame(minHeight: 130)
                            } header: {
                                Text("Algılanan Metin (Seçilebilir / Düzenlenebilir)")
                            }

                            Section("Satır Satır Kopyala (Dokun)") {
                                ForEach(Array(result.textLines.enumerated()), id: \.offset) { _, line in
                                    Button {
                                        copyToClipboard(line, label: "Satır kopyalandı")
                                    } label: {
                                        HStack {
                                            Text(line)
                                                .font(.subheadline)
                                                .foregroundStyle(.primary)
                                                .multilineTextAlignment(.leading)
                                            Spacer()
                                            Image(systemName: "doc.on.doc")
                                                .font(.caption)
                                                .foregroundStyle(.orange)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .overlay(alignment: .bottom) {
                if let toast = copiedToast {
                    Text(toast)
                        .font(.footnote.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 9)
                        .background(.black.opacity(0.82), in: Capsule())
                        .padding(.bottom, 16)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .navigationTitle("Metin & QR Algılama")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Bitti") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                editableFullText = result.fullText
            }
            .onChange(of: result.fullText) { _, newValue in
                editableFullText = newValue
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func copyToClipboard(_ text: String, label: String) {
        UIPasteboard.general.string = text
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        withAnimation(.spring(duration: 0.25)) {
            copiedToast = "\(label) ✓"
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            withAnimation(.easeOut(duration: 0.2)) {
                if copiedToast == "\(label) ✓" {
                    copiedToast = nil
                }
            }
        }
    }
}
