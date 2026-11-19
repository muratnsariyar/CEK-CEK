import Foundation
import UIKit
import Vision

struct DetectedQRItem: Identifiable, Equatable {
    let id = UUID()
    let payload: String
    let typeTitle: String

    var webURL: URL? {
        guard let url = URL(string: payload.trimmingCharacters(in: .whitespacesAndNewlines)),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else {
            return nil
        }
        return url
    }
}

struct ScanAnalysisResult: Equatable {
    let textLines: [String]
    let qrItems: [DetectedQRItem]

    var fullText: String {
        textLines.joined(separator: "\n")
    }

    var hasText: Bool {
        !textLines.isEmpty
    }

    var hasQR: Bool {
        !qrItems.isEmpty
    }

    var hasAnyContent: Bool {
        hasText || hasQR
    }

    static let empty = ScanAnalysisResult(textLines: [], qrItems: [])
}

enum TextAndQRScannerService {
    static func analyze(image: UIImage) async -> ScanAnalysisResult {
        guard let cgImage = image.cgImage else {
            return .empty
        }

        return await Task.detached(priority: .userInitiated) {
            var recognizedLines: [String] = []
            var detectedQRs: [DetectedQRItem] = []

            let textRequest = VNRecognizeTextRequest()
            textRequest.recognitionLevel = .accurate
            textRequest.usesLanguageCorrection = true
            textRequest.recognitionLanguages = ["tr-TR", "en-US"]

            let barcodeRequest = VNDetectBarcodesRequest()

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try? handler.perform([textRequest, barcodeRequest])

            if let textObservations = textRequest.results {
                for observation in textObservations {
                    if let candidate = observation.topCandidates(1).first?.string.trimmingCharacters(in: .whitespacesAndNewlines),
                       !candidate.isEmpty {
                        recognizedLines.append(candidate)
                    }
                }
            }

            if let barcodeObservations = barcodeRequest.results {
                var seenPayloads = Set<String>()
                for observation in barcodeObservations {
                    guard let payload = observation.payloadStringValue?.trimmingCharacters(in: .whitespacesAndNewlines),
                          !payload.isEmpty,
                          !seenPayloads.contains(payload) else {
                        continue
                    }
                    seenPayloads.insert(payload)
                    let label = (observation.symbology == .qr) ? "QR Kod" : "Barkod"
                    detectedQRs.append(DetectedQRItem(payload: payload, typeTitle: label))
                }
            }

            return ScanAnalysisResult(textLines: recognizedLines, qrItems: detectedQRs)
        }.value
    }
}
