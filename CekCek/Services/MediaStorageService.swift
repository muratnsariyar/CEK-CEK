import AVFoundation
import Foundation
import UIKit

enum MediaStorageError: LocalizedError {
    case directoryUnavailable
    case imageEncodingFailed
    case fileCopyFailed

    var errorDescription: String? {
        switch self {
        case .directoryUnavailable:
            return "Uygulama depolama klasörüne erişilemedi."
        case .imageEncodingFailed:
            return "Fotoğraf verisi işlenemedi."
        case .fileCopyFailed:
            return "Video dosyası kasaya kaydedilemedi."
        }
    }
}

struct SavedMediaResult {
    let fileName: String
    let thumbnailFileName: String?
    let durationSeconds: Double?
    let fileSizeBytes: Int64
}

final class MediaStorageService {
    static let shared = MediaStorageService()

    private let fileManager = FileManager.default
    private let vaultFolderName = "CekCekMedia"

    private init() {
        _ = try? ensureVaultDirectory()
    }

    func vaultDirectoryURL() throws -> URL {
        guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw MediaStorageError.directoryUnavailable
        }
        return appSupport.appendingPathComponent(vaultFolderName, isDirectory: true)
    }

    @discardableResult
    private func ensureVaultDirectory() throws -> URL {
        var dirURL = try vaultDirectoryURL()
        if !fileManager.fileExists(atPath: dirURL.path) {
            try fileManager.createDirectory(at: dirURL, withIntermediateDirectories: true)
        }
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        try? dirURL.setResourceValues(resourceValues)
        return dirURL
    }

    func fileURL(for fileName: String) -> URL {
        let dir = (try? ensureVaultDirectory()) ?? fileManager.temporaryDirectory
        return dir.appendingPathComponent(fileName)
    }

    func savePhoto(data: Data) throws -> SavedMediaResult {
        let dir = try ensureVaultDirectory()
        let baseID = UUID().uuidString
        let fileName = "\(baseID).jpg"
        let destURL = dir.appendingPathComponent(fileName)

        let outputData: Data
        if let image = UIImage(data: data),
           let normalized = normalizedJPEGData(from: image, compressionQuality: 0.88) {
            outputData = normalized
        } else {
            outputData = data
        }

        try outputData.write(to: destURL, options: [.atomic, .completeFileProtectionUnlessOpen])

        var thumbName: String?
        if let image = UIImage(data: outputData),
           let thumbData = makeThumbnailData(from: image, maxDimension: 480) {
            let candidate = "\(baseID)_thumb.jpg"
            let thumbURL = dir.appendingPathComponent(candidate)
            try? thumbData.write(to: thumbURL, options: [.atomic, .completeFileProtectionUnlessOpen])
            thumbName = candidate
        }

        let size = Int64(outputData.count)
        return SavedMediaResult(
            fileName: fileName,
            thumbnailFileName: thumbName,
            durationSeconds: nil,
            fileSizeBytes: size
        )
    }

    func saveVideo(from tempURL: URL) async throws -> SavedMediaResult {
        let dir = try ensureVaultDirectory()
        let baseID = UUID().uuidString
        let ext = tempURL.pathExtension.isEmpty ? "mov" : tempURL.pathExtension
        let fileName = "\(baseID).\(ext)"
        let destURL = dir.appendingPathComponent(fileName)

        do {
            if fileManager.fileExists(atPath: destURL.path) {
                try fileManager.removeItem(at: destURL)
            }
            try fileManager.copyItem(at: tempURL, to: destURL)
            try? fileManager.removeItem(at: tempURL)
        } catch {
            throw MediaStorageError.fileCopyFailed
        }

        let asset = AVURLAsset(url: destURL)
        let durationCMTime = try? await asset.load(.duration)
        let durationSeconds = durationCMTime.map { CMTimeGetSeconds($0) }.flatMap { $0.isFinite ? $0 : nil }

        var thumbName: String?
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 480, height: 480)
        if let cgImage = try? await generator.image(at: .zero).image {
            let uiImage = UIImage(cgImage: cgImage)
            if let thumbData = uiImage.jpegData(compressionQuality: 0.78) {
                let candidate = "\(baseID)_thumb.jpg"
                let thumbURL = dir.appendingPathComponent(candidate)
                try? thumbData.write(to: thumbURL, options: [.atomic, .completeFileProtectionUnlessOpen])
                thumbName = candidate
            }
        }

        let attributes = try? fileManager.attributesOfItem(atPath: destURL.path)
        let fileSize = (attributes?[.size] as? NSNumber)?.int64Value ?? 0

        return SavedMediaResult(
            fileName: fileName,
            thumbnailFileName: thumbName,
            durationSeconds: durationSeconds,
            fileSizeBytes: fileSize
        )
    }

    func loadImage(fileName: String) -> UIImage? {
        let url = fileURL(for: fileName)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    func deleteFiles(fileName: String, thumbnailFileName: String?) {
        let primaryURL = fileURL(for: fileName)
        try? fileManager.removeItem(at: primaryURL)
        if let thumbnailFileName {
            let thumbURL = fileURL(for: thumbnailFileName)
            try? fileManager.removeItem(at: thumbURL)
        }
    }

    func totalVaultSizeBytes() -> Int64 {
        guard let dir = try? vaultDirectoryURL(),
              let files = try? fileManager.contentsOfDirectory(
                at: dir,
                includingPropertiesForKeys: [.fileSizeKey],
                options: [.skipsHiddenFiles]
              ) else {
            return 0
        }

        var total: Int64 = 0
        for url in files {
            if let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                total += Int64(size)
            }
        }
        return total
    }

    func cleanupOrphanedFiles(validFileNames: Set<String>) {
        guard let dir = try? vaultDirectoryURL(),
              let files = try? fileManager.contentsOfDirectory(
                at: dir,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
              ) else {
            return
        }

        for url in files {
            if !validFileNames.contains(url.lastPathComponent) {
                try? fileManager.removeItem(at: url)
            }
        }
    }

    func generateDemoPhotoData(folderName: String, retentionTitle: String) -> Data? {
        let size = CGSize(width: 1080, height: 1440)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            let colors = [
                UIColor(red: 0.09, green: 0.12, blue: 0.22, alpha: 1.0).cgColor,
                UIColor(red: 0.16, green: 0.24, blue: 0.38, alpha: 1.0).cgColor
            ]
            if let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: colors as CFArray,
                locations: [0.0, 1.0]
            ) {
                context.cgContext.drawLinearGradient(
                    gradient,
                    start: .zero,
                    end: CGPoint(x: size.width, y: size.height),
                    options: []
                )
            }

            let cardRect = CGRect(x: 90, y: 260, width: size.width - 180, height: 920)
            let cardPath = UIBezierPath(roundedRect: cardRect, cornerRadius: 44)
            UIColor.white.withAlphaComponent(0.10).setFill()
            cardPath.fill()

            let titleAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 72, weight: .bold),
                .foregroundColor: UIColor.systemOrange
            ]
            "CEK CEK".draw(at: CGPoint(x: 150, y: 340), withAttributes: titleAttr)

            let subtitleAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 40, weight: .medium),
                .foregroundColor: UIColor.white
            ]
            "Simülatör Demo Çekimi".draw(at: CGPoint(x: 150, y: 445), withAttributes: subtitleAttr)

            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "tr_TR")
            formatter.dateStyle = .medium
            formatter.timeStyle = .medium

            let detailAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.monospacedSystemFont(ofSize: 34, weight: .regular),
                .foregroundColor: UIColor.white.withAlphaComponent(0.85)
            ]
            let body = """
            Klasör: \(folderName)
            Saklama Süresi: \(retentionTitle)
            Tarih: \(formatter.string(from: Date()))

            Bu görüntü kişisel Fotoğraflar
            galerisine kaydedilmedi; yalnızca
            CEK CEK kasasında saklanır.
            """
            body.draw(
                in: CGRect(x: 150, y: 560, width: size.width - 300, height: 500),
                withAttributes: detailAttr
            )
        }
        return image.jpegData(compressionQuality: 0.88)
    }

    private func normalizedJPEGData(from image: UIImage, compressionQuality: CGFloat) -> Data? {
        if image.imageOrientation == .up {
            return image.jpegData(compressionQuality: compressionQuality)
        }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
        let rendered = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
        return rendered.jpegData(compressionQuality: compressionQuality)
    }

    private func makeThumbnailData(from image: UIImage, maxDimension: CGFloat) -> Data? {
        let originalSize = image.size
        guard originalSize.width > 0, originalSize.height > 0 else { return nil }
        let ratio = min(maxDimension / originalSize.width, maxDimension / originalSize.height, 1.0)
        let targetSize = CGSize(width: originalSize.width * ratio, height: originalSize.height * ratio)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        let thumb = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        return thumb.jpegData(compressionQuality: 0.75)
    }
}
