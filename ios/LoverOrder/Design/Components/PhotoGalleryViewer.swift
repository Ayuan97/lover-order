import SwiftUI
import UIKit

struct PhotoGallerySlide: Identifiable, Hashable {
    let id: String
    let url: String
    let caption: String?
    let isTransparent: Bool

    init(id: String? = nil, url: String, caption: String? = nil, isTransparent: Bool = false) {
        self.id = id ?? url
        self.url = url
        self.caption = caption
        self.isTransparent = isTransparent
    }
}

struct PhotoGalleryPresentation: Identifiable {
    let id = UUID()
    let slides: [PhotoGallerySlide]
    let initialIndex: Int

    init(slides: [PhotoGallerySlide], initialIndex: Int = 0) {
        self.slides = slides
        if slides.isEmpty {
            self.initialIndex = 0
        } else {
            self.initialIndex = min(max(0, initialIndex), slides.count - 1)
        }
    }

    init(urls: [String], initialIndex: Int = 0, caption: String? = nil, isTransparent: Bool = false) {
        let normalized = urls.enumerated().compactMap { idx, raw -> PhotoGallerySlide? in
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            return PhotoGallerySlide(
                id: "\(idx)-\(trimmed)",
                url: trimmed,
                caption: caption,
                isTransparent: isTransparent
            )
        }
        self.init(slides: normalized, initialIndex: initialIndex)
    }
}

struct PhotoGalleryViewer: View {
    let slides: [PhotoGallerySlide]
    var initialIndex: Int = 0
    var onIndexChanged: ((Int) -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var currentIndex: Int
    @State private var chromeVisible: Bool = true

    init(slides: [PhotoGallerySlide], initialIndex: Int = 0, onIndexChanged: ((Int) -> Void)? = nil) {
        self.slides = slides
        self.initialIndex = initialIndex
        self.onIndexChanged = onIndexChanged
        let clamped = slides.isEmpty ? 0 : min(max(0, initialIndex), slides.count - 1)
        _currentIndex = State(initialValue: clamped)
    }

    private var activeCaption: String? {
        guard slides.indices.contains(currentIndex) else { return nil }
        guard let raw = slides[currentIndex].caption?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty else {
            return nil
        }
        return raw
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if !slides.isEmpty {
                TabView(selection: $currentIndex) {
                    ForEach(Array(slides.enumerated()), id: \.offset) { index, slide in
                        PhotoGalleryPageView(
                            slide: slide,
                            isActive: currentIndex == index,
                            onSingleTap: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    chromeVisible.toggle()
                                }
                            },
                            onDismiss: {
                                dismiss()
                            }
                        )
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .ignoresSafeArea()
                .onChange(of: currentIndex) { _, newValue in
                    onIndexChanged?(newValue)
                }
            }

            VStack {
                topBar
                    .opacity(chromeVisible ? 1 : 0)
                    .allowsHitTesting(chromeVisible)

                Spacer()

                if let caption = activeCaption {
                    Text(caption)
                        .font(AppFont.caption(13))
                        .foregroundStyle(.white.opacity(0.95))
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(Color.black.opacity(0.52), in: Capsule())
                        .overlay {
                            Capsule().strokeBorder(Color.white.opacity(0.22), lineWidth: 0.6)
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 26)
                        .opacity(chromeVisible ? 1 : 0)
                        .allowsHitTesting(false)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var topBar: some View {
        HStack {
            if slides.count > 1 {
                Text("\(min(currentIndex + 1, slides.count)) / \(slides.count)")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .frame(height: 34)
                    .background(Color.black.opacity(0.45), in: Capsule())
                    .overlay {
                        Capsule().strokeBorder(Color.white.opacity(0.28), lineWidth: 0.7)
                    }
            }
            Spacer()
            Button {
                Haptics.light()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(Color.black.opacity(0.48), in: Circle())
                    .overlay {
                        Circle().strokeBorder(Color.white.opacity(0.32), lineWidth: 0.8)
                    }
            }
            .frame(width: 44, height: 44)
            .contentShape(Circle())
            .accessibilityLabel("关闭大图")
        }
        .padding(.horizontal, 18)
        .padding(.top, 14)
    }
}

private struct PhotoGalleryPageView: View {
    let slide: PhotoGallerySlide
    let isActive: Bool
    let onSingleTap: () -> Void
    let onDismiss: () -> Void

    @State private var loadedImage: UIImage?
    @State private var didFail = false

    private var resolvedURL: URL? { APIConfig.imageURL(slide.url) }

    var body: some View {
        let displayImage = loadedImage ?? resolvedURL.flatMap { RemoteImageCache.shared.cachedImage(for: $0) }
        Group {
            if let displayImage {
                ZoomableUIImageView(
                    image: displayImage,
                    isTransparent: slide.isTransparent,
                    isActive: isActive,
                    onSingleTap: onSingleTap,
                    onSwipeDownDismiss: onDismiss
                )
                .ignoresSafeArea()
            } else if resolvedURL == nil || didFail {
                VStack(spacing: 10) {
                    Image(systemName: "photo")
                        .font(.system(size: 36, weight: .light))
                        .foregroundStyle(.white.opacity(0.45))
                    Text("图片加载失败")
                        .font(AppFont.caption(13))
                        .foregroundStyle(.white.opacity(0.6))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .onTapGesture {
                    onSingleTap()
                }
            } else {
                ZStack {
                    Color.clear
                    ProgressView().tint(.white)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .onTapGesture {
                    onSingleTap()
                }
            }
        }
        .task(id: resolvedURL) {
            didFail = false
            guard let url = resolvedURL else {
                loadedImage = nil
                return
            }
            if let cached = RemoteImageCache.shared.cachedImage(for: url) {
                loadedImage = cached
                return
            }
            loadedImage = nil
            if let fetched = await RemoteImageCache.shared.load(url: url) {
                loadedImage = fetched
            } else if !Task.isCancelled {
                didFail = true
            }
        }
    }
}

private struct ZoomableUIImageView: UIViewRepresentable {
    let image: UIImage
    let isTransparent: Bool
    let isActive: Bool
    let onSingleTap: () -> Void
    let onSwipeDownDismiss: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onSingleTap: onSingleTap, onSwipeDownDismiss: onSwipeDownDismiss)
    }

    func makeUIView(context: Context) -> ZoomablePhotoScrollView {
        let scrollView = ZoomablePhotoScrollView()
        scrollView.delegate = context.coordinator

        let doubleTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2

        let singleTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleSingleTap))
        singleTap.numberOfTapsRequired = 1
        singleTap.require(toFail: doubleTap)

        let swipeDown = UISwipeGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleSwipeDown))
        swipeDown.direction = .down
        swipeDown.delegate = context.coordinator
        context.coordinator.swipeDownGesture = swipeDown

        scrollView.addGestureRecognizer(doubleTap)
        scrollView.addGestureRecognizer(singleTap)
        scrollView.addGestureRecognizer(swipeDown)
        scrollView.configure(image: image, isTransparent: isTransparent)
        return scrollView
    }

    func updateUIView(_ uiView: ZoomablePhotoScrollView, context: Context) {
        context.coordinator.onSingleTap = onSingleTap
        context.coordinator.onSwipeDownDismiss = onSwipeDownDismiss
        uiView.configure(image: image, isTransparent: isTransparent)
        if !isActive, uiView.zoomScale > 1.01 {
            uiView.setZoomScale(1.0, animated: false)
        }
    }

    final class Coordinator: NSObject, UIScrollViewDelegate, UIGestureRecognizerDelegate {
        var onSingleTap: () -> Void
        var onSwipeDownDismiss: () -> Void
        weak var swipeDownGesture: UISwipeGestureRecognizer?

        init(onSingleTap: @escaping () -> Void, onSwipeDownDismiss: @escaping () -> Void) {
            self.onSingleTap = onSingleTap
            self.onSwipeDownDismiss = onSwipeDownDismiss
        }

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            (scrollView as? ZoomablePhotoScrollView)?.imageView
        }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            (scrollView as? ZoomablePhotoScrollView)?.centerImageView()
        }

        @objc func handleSingleTap() {
            onSingleTap()
        }

        @objc func handleDoubleTap(_ recognizer: UITapGestureRecognizer) {
            guard let scrollView = recognizer.view as? ZoomablePhotoScrollView else { return }
            if scrollView.zoomScale > 1.05 {
                scrollView.setZoomScale(1.0, animated: true)
                return
            }
            let targetScale: CGFloat = 2.5
            let imageBounds = scrollView.imageView.bounds
            guard imageBounds.width > 0, imageBounds.height > 0 else { return }
            let rawPoint = recognizer.location(in: scrollView.imageView)
            let clampedX = min(max(rawPoint.x, 0), imageBounds.width)
            let clampedY = min(max(rawPoint.y, 0), imageBounds.height)
            let zoomWidth = imageBounds.width / targetScale
            let zoomHeight = imageBounds.height / targetScale
            let zoomRect = CGRect(
                x: clampedX - zoomWidth * 0.5,
                y: clampedY - zoomHeight * 0.5,
                width: zoomWidth,
                height: zoomHeight
            )
            scrollView.zoom(to: zoomRect, animated: true)
        }

        @objc func handleSwipeDown() {
            Haptics.light()
            onSwipeDownDismiss()
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            if gestureRecognizer === swipeDownGesture {
                guard let scrollView = gestureRecognizer.view as? UIScrollView else { return false }
                return scrollView.zoomScale <= 1.02
            }
            return true
        }
    }
}

private final class ZoomablePhotoScrollView: UIScrollView {
    let imageView = UIImageView()
    private var lastBoundsSize: CGSize = .zero
    private var lastImageSize: CGSize = .zero

    private static let checkerboardColor: UIColor = {
        let cell: CGFloat = 12
        let tile = CGSize(width: cell * 2, height: cell * 2)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: tile, format: format)
        let pattern = renderer.image { ctx in
            UIColor(white: 0.24, alpha: 1).setFill()
            ctx.fill(CGRect(origin: .zero, size: tile))
            UIColor(white: 0.18, alpha: 1).setFill()
            ctx.fill(CGRect(x: cell, y: 0, width: cell, height: cell))
            ctx.fill(CGRect(x: 0, y: cell, width: cell, height: cell))
        }
        return UIColor(patternImage: pattern)
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        minimumZoomScale = 1.0
        maximumZoomScale = 4.0
        showsHorizontalScrollIndicator = false
        showsVerticalScrollIndicator = false
        bouncesZoom = true
        decelerationRate = .fast
        contentInsetAdjustmentBehavior = .never
        backgroundColor = .clear

        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = true
        addSubview(imageView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(image: UIImage, isTransparent: Bool) {
        if imageView.image !== image {
            imageView.image = image
            setNeedsLayout()
        }
        if isTransparent {
            imageView.backgroundColor = Self.checkerboardColor
            imageView.layer.cornerRadius = 12
            imageView.clipsToBounds = true
        } else {
            imageView.backgroundColor = .clear
            imageView.layer.cornerRadius = 0
            imageView.clipsToBounds = false
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard let image = imageView.image,
              bounds.width > 0, bounds.height > 0,
              image.size.width > 0, image.size.height > 0 else {
            return
        }
        if bounds.size != lastBoundsSize || image.size != lastImageSize {
            lastBoundsSize = bounds.size
            lastImageSize = image.size
            let ratio = min(bounds.width / image.size.width, bounds.height / image.size.height)
            let fitted = CGSize(width: image.size.width * ratio, height: image.size.height * ratio)
            zoomScale = 1.0
            imageView.frame = CGRect(origin: .zero, size: fitted)
            contentSize = fitted
        }
        centerImageView()
    }

    func centerImageView() {
        let offsetX = max((bounds.width - contentSize.width) * 0.5, 0)
        let offsetY = max((bounds.height - contentSize.height) * 0.5, 0)
        imageView.center = CGPoint(
            x: contentSize.width * 0.5 + offsetX,
            y: contentSize.height * 0.5 + offsetY
        )
    }
}
