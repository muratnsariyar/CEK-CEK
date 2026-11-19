@preconcurrency import AVFoundation
import Foundation
import UIKit

enum CameraCaptureMode: String, CaseIterable, Identifiable {
    case photo
    case video

    var id: String { rawValue }

    var title: String {
        switch self {
        case .photo: return "FOTOĞRAF"
        case .video: return "VİDEO"
        }
    }
}

final class CameraManager: NSObject, ObservableObject {
    let session = AVCaptureSession()

    @Published var captureMode: CameraCaptureMode = .photo
    @Published var flashMode: AVCaptureDevice.FlashMode = .auto
    @Published var cameraPosition: AVCaptureDevice.Position = .back
    @Published var isRecording: Bool = false
    @Published var recordingElapsedSeconds: Int = 0
    @Published var isCameraUnavailable: Bool = false
    @Published var permissionDenied: Bool = false
    @Published var zoomFactor: CGFloat = 1.0
    @Published var errorMessage: String?

    var onPhotoCaptured: ((Data) -> Void)?
    var onVideoCaptured: ((URL) -> Void)?

    private let sessionQueue = DispatchQueue(label: "com.cekcek.camera.session")
    private let photoOutput = AVCapturePhotoOutput()
    private let movieOutput = AVCaptureMovieFileOutput()
    private var videoDeviceInput: AVCaptureDeviceInput?
    private var audioDeviceInput: AVCaptureDeviceInput?
    private var isConfigured = false
    private var recordingTimer: Timer?

    override init() {
        super.init()
        #if targetEnvironment(simulator)
        isCameraUnavailable = true
        #endif
    }

    func checkPermissionsAndStart() {
        #if targetEnvironment(simulator)
        DispatchQueue.main.async {
            self.isCameraUnavailable = true
        }
        return
        #else
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            requestMicrophoneIfNeeded()
            configureAndStartSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.permissionDenied = false
                        self?.requestMicrophoneIfNeeded()
                        self?.configureAndStartSession()
                    } else {
                        self?.permissionDenied = true
                    }
                }
            }
        case .denied, .restricted:
            DispatchQueue.main.async {
                self.permissionDenied = true
            }
        @unknown default:
            DispatchQueue.main.async {
                self.isCameraUnavailable = true
            }
        }
        #endif
    }

    private func requestMicrophoneIfNeeded() {
        if AVCaptureDevice.authorizationStatus(for: .audio) == .notDetermined {
            AVCaptureDevice.requestAccess(for: .audio) { _ in }
        }
    }

    private func configureAndStartSession() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if !self.isConfigured {
                self.configureSession()
            }
            if !self.session.isRunning && !self.isCameraUnavailable {
                self.session.startRunning()
            }
        }
    }

    func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if self.movieOutput.isRecording {
                self.movieOutput.stopRecording()
            }
            if self.session.isRunning {
                self.session.stopRunning()
            }
        }
        stopRecordingTimer()
    }

    private func configureSession() {
        session.beginConfiguration()
        session.sessionPreset = .high

        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: cameraPosition),
              let videoInput = try? AVCaptureDeviceInput(device: videoDevice),
              session.canAddInput(videoInput) else {
            session.commitConfiguration()
            DispatchQueue.main.async {
                self.isCameraUnavailable = true
            }
            return
        }

        session.addInput(videoInput)
        videoDeviceInput = videoInput

        if let audioDevice = AVCaptureDevice.default(for: .audio),
           let audioInput = try? AVCaptureDeviceInput(device: audioDevice),
           session.canAddInput(audioInput) {
            session.addInput(audioInput)
            audioDeviceInput = audioInput
        }

        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
        }

        if session.canAddOutput(movieOutput) {
            session.addOutput(movieOutput)
        }

        session.commitConfiguration()
        isConfigured = true
    }

    func toggleFlash() {
        switch flashMode {
        case .auto: flashMode = .on
        case .on: flashMode = .off
        case .off: flashMode = .auto
        @unknown default: flashMode = .auto
        }
    }

    func switchCamera() {
        let newPosition: AVCaptureDevice.Position = (cameraPosition == .back) ? .front : .back
        sessionQueue.async { [weak self] in
            guard let self, self.isConfigured else { return }
            guard let newDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: newPosition),
                  let newInput = try? AVCaptureDeviceInput(device: newDevice) else {
                return
            }

            self.session.beginConfiguration()
            if let currentInput = self.videoDeviceInput {
                self.session.removeInput(currentInput)
            }
            if self.session.canAddInput(newInput) {
                self.session.addInput(newInput)
                self.videoDeviceInput = newInput
                DispatchQueue.main.async {
                    self.cameraPosition = newPosition
                    self.zoomFactor = 1.0
                }
            } else if let currentInput = self.videoDeviceInput, self.session.canAddInput(currentInput) {
                self.session.addInput(currentInput)
            }
            self.session.commitConfiguration()
        }
    }

    func setZoom(factor: CGFloat) {
        sessionQueue.async { [weak self] in
            guard let self, let device = self.videoDeviceInput?.device else { return }
            let maxZoom = min(device.activeFormat.videoMaxZoomFactor, 6.0)
            let clamped = max(1.0, min(factor, maxZoom))
            do {
                try device.lockForConfiguration()
                device.videoZoomFactor = clamped
                device.unlockForConfiguration()
                DispatchQueue.main.async {
                    self.zoomFactor = clamped
                }
            } catch {
                // Ignore zoom lock errors
            }
        }
    }

    func focus(at devicePoint: CGPoint) {
        sessionQueue.async { [weak self] in
            guard let self, let device = self.videoDeviceInput?.device else { return }
            do {
                try device.lockForConfiguration()
                if device.isFocusPointOfInterestSupported {
                    device.focusPointOfInterest = devicePoint
                    device.focusMode = .autoFocus
                }
                if device.isExposurePointOfInterestSupported {
                    device.exposurePointOfInterest = devicePoint
                    device.exposureMode = .autoExpose
                }
                device.unlockForConfiguration()
            } catch {
                // Ignore focus errors
            }
        }
    }

    func capturePhoto() {
        let currentFlash = flashMode
        sessionQueue.async { [weak self] in
            guard let self, self.session.isRunning else { return }
            let settings = AVCapturePhotoSettings()
            if let device = self.videoDeviceInput?.device, device.hasFlash {
                settings.flashMode = currentFlash
            }
            self.photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }

    func toggleVideoRecording() {
        if isRecording {
            stopVideoRecording()
        } else {
            startVideoRecording()
        }
    }

    private func startVideoRecording() {
        sessionQueue.async { [weak self] in
            guard let self, self.session.isRunning, !self.movieOutput.isRecording else { return }
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("cekcek_\(UUID().uuidString).mov")
            if FileManager.default.fileExists(atPath: tempURL.path) {
                try? FileManager.default.removeItem(at: tempURL)
            }
            self.movieOutput.startRecording(to: tempURL, recordingDelegate: self)
            DispatchQueue.main.async {
                self.isRecording = true
                self.recordingElapsedSeconds = 0
                self.startRecordingTimer()
            }
        }
    }

    private func stopVideoRecording() {
        sessionQueue.async { [weak self] in
            guard let self, self.movieOutput.isRecording else { return }
            self.movieOutput.stopRecording()
        }
        stopRecordingTimer()
    }

    private func startRecordingTimer() {
        stopRecordingTimer()
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.recordingElapsedSeconds += 1
            }
        }
    }

    private func stopRecordingTimer() {
        DispatchQueue.main.async {
            self.recordingTimer?.invalidate()
            self.recordingTimer = nil
        }
    }

    var formattedRecordingTime: String {
        let mins = recordingElapsedSeconds / 60
        let secs = recordingElapsedSeconds % 60
        return String(format: "%02d:%02d", mins, secs)
    }
}

extension CameraManager: AVCapturePhotoCaptureDelegate {
    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        if let error {
            DispatchQueue.main.async {
                self.errorMessage = "Fotoğraf çekilemedi: \(error.localizedDescription)"
            }
            return
        }
        guard let data = photo.fileDataRepresentation() else { return }
        DispatchQueue.main.async {
            self.onPhotoCaptured?(data)
        }
    }
}

extension CameraManager: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(
        _ output: AVCaptureFileOutput,
        didFinishRecordingTo outputFileURL: URL,
        from connections: [AVCaptureConnection],
        error: Error?
    ) {
        stopRecordingTimer()
        DispatchQueue.main.async {
            self.isRecording = false
            if let error {
                self.errorMessage = "Video kaydedilemedi: \(error.localizedDescription)"
                try? FileManager.default.removeItem(at: outputFileURL)
                return
            }
            self.onVideoCaptured?(outputFileURL)
        }
    }
}
