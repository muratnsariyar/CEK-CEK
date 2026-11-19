import Foundation
import Photos
import UIKit

enum PhotoExportError: LocalizedError {
    case permissionDenied
    case fileMissing
    case exportFailed(String)

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Fotoğraflar uygulamasına kaydetme izni verilmedi. Ayarlar > ÇEK ÇEK üzerinden izin verebilirsiniz."
        case .fileMissing:
            return "Medya dosyası kasada bulunamadı."
        case .exportFailed(let detail):
            return "Kişisel galeriye kaydedilemedi: \(detail)"
        }
    }
}

enum PhotoLibraryExportService {
    static func saveToPersonalGallery(item: MediaItem) async throws {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            throw PhotoExportError.permissionDenied
        }

        let fileURL = MediaStorageService.shared.fileURL(for: item.fileName)
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw PhotoExportError.fileMissing
        }

        let mediaType = item.mediaType

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            PHPhotoLibrary.shared().performChanges({
                switch mediaType {
                case .photo:
                    PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: fileURL)
                case .video:
                    PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: fileURL)
                }
            }, completionHandler: { success, error in
                if success {
                    continuation.resume()
                } else {
                    continuation.resume(
                        throwing: PhotoExportError.exportFailed(error?.localizedDescription ?? "Bilinmeyen hata")
                    )
                }
            })
        }
    }
}
