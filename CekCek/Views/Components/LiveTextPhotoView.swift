import SwiftUI
import UIKit
import VisionKit

/// Apple Fotoğraflar (Live Text) benzeri fotoğraf üzerinde basılı tutarak metin seçme,
/// kopyalama, bağlantı/QR etkileşimi ve yakınlaştırma sağlayan bileşen.
struct LiveTextPhotoView: UIViewRepresentable {
    let image: UIImage
    let isActive: Bool
    @Binding var zoomScale: CGFloat
    let onToggleChrome: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(zoomScale: $zoomScale, onToggleChrome: onToggleChrome)
    }

    func makeUIView(context: Context) -> LiveTextContainerView {
        let view = LiveTextContainerView()
        view.configure(with: image, coordinator: context.coordinator)
        context.coordinator.analyze(image: image)
        return view
    }

    func updateUIView(_ uiView: LiveTextContainerView, context: Context) {
        context.coordinator.zoomScale = $zoomScale
        context.coordinator.onToggleChrome = onToggleChrome
        if uiView.imageView.image !== image {
            uiView.imageView.image = image
            uiView.setNeedsLayout()
            context.coordinator.analyze(image: image)
        }
        if !isActive && uiView.scrollView.zoomScale > 1.0 {
            uiView.scrollView.setZoomScale(1.0, animated: false)
        }
    }

    @MainActor
    final class Coordinator: NSObject, UIScrollViewDelegate {
        private static let sharedAnalyzer = ImageAnalyzer()

        var zoomScale: Binding<CGFloat>
        var onToggleChrome: () -> Void
        weak var containerView: LiveTextContainerView?
        let interaction = ImageAnalysisInteraction()
        private var analysisTask: Task<Void, Never>?

        init(zoomScale: Binding<CGFloat>, onToggleChrome: @escaping () -> Void) {
            self.zoomScale = zoomScale
            self.onToggleChrome = onToggleChrome
            super.init()
            interaction.preferredInteractionTypes = .automatic
        }

        func analyze(image: UIImage) {
            analysisTask?.cancel()
            interaction.analysis = nil

            guard ImageAnalyzer.isSupported else { return }

            analysisTask = Task {
                let configuration = ImageAnalyzer.Configuration([.text, .machineReadableCode])
                guard let analysis = try? await Self.sharedAnalyzer.analyze(image, configuration: configuration),
                      !Task.isCancelled else {
                    return
                }
                self.interaction.analysis = analysis
                self.interaction.preferredInteractionTypes = .automatic
            }
        }

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            containerView?.imageView
        }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            containerView?.centerImageIfNeeded()
            zoomScale.wrappedValue = scrollView.zoomScale
        }

        @objc func handleSingleTap(_ recognizer: UITapGestureRecognizer) {
            if interaction.hasActiveTextSelection {
                return
            }
            onToggleChrome()
        }

        @objc func handleDoubleTap(_ recognizer: UITapGestureRecognizer) {
            guard let scrollView = containerView?.scrollView else { return }
            if scrollView.zoomScale > 1.05 {
                scrollView.setZoomScale(1.0, animated: true)
            } else {
                let point = recognizer.location(in: containerView?.imageView)
                let zoomRect = CGRect(
                    x: point.x - 60,
                    y: point.y - 60,
                    width: 120,
                    height: 120
                )
                scrollView.zoom(to: zoomRect, animated: true)
            }
        }
    }
}

final class LiveTextContainerView: UIView {
    let scrollView = UIScrollView()
    let imageView = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear

        scrollView.backgroundColor = .clear
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 4.0
        scrollView.bouncesZoom = true
        scrollView.contentInsetAdjustmentBehavior = .never
        addSubview(scrollView)

        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = true
        scrollView.addSubview(imageView)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with image: UIImage, coordinator: LiveTextPhotoView.Coordinator) {
        coordinator.containerView = self
        scrollView.delegate = coordinator
        imageView.image = image
        imageView.addInteraction(coordinator.interaction)

        let doubleTap = UITapGestureRecognizer(target: coordinator, action: #selector(LiveTextPhotoView.Coordinator.handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        doubleTap.cancelsTouchesInView = false
        scrollView.addGestureRecognizer(doubleTap)

        let singleTap = UITapGestureRecognizer(target: coordinator, action: #selector(LiveTextPhotoView.Coordinator.handleSingleTap(_:)))
        singleTap.numberOfTapsRequired = 1
        singleTap.cancelsTouchesInView = false
        singleTap.require(toFail: doubleTap)
        scrollView.addGestureRecognizer(singleTap)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.width > 0, bounds.height > 0 else { return }

        if scrollView.frame != bounds {
            scrollView.frame = bounds
            scrollView.setZoomScale(1.0, animated: false)
            imageView.frame = bounds
            scrollView.contentSize = bounds.size
        }
        centerImageIfNeeded()
    }

    func centerImageIfNeeded() {
        let boundsSize = scrollView.bounds.size
        var frameToCenter = imageView.frame

        if frameToCenter.size.width < boundsSize.width {
            frameToCenter.origin.x = (boundsSize.width - frameToCenter.size.width) / 2.0
        } else {
            frameToCenter.origin.x = 0
        }

        if frameToCenter.size.height < boundsSize.height {
            frameToCenter.origin.y = (boundsSize.height - frameToCenter.size.height) / 2.0
        } else {
            frameToCenter.origin.y = 0
        }

        imageView.frame = frameToCenter
    }
}
