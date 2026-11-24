import PhotosUI
import SwiftUI
import UIKit

// MARK: - 图片加载、归一化、旋转裁剪与透明通道工具

enum RecipeImageEditHelpers {
    @MainActor
    static func loadUIImage(from pathOrURL: String?) async -> UIImage? {
        guard let raw = pathOrURL?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty,
              let url = APIConfig.imageURL(raw) else {
            return nil
        }
        if let cached = RemoteImageCache.shared.cachedImage(for: url) {
            return cached
        }
        return await RemoteImageCache.shared.load(url: url)
    }

    static func normalizedUpImage(_ image: UIImage, maxSide: CGFloat = 1600, opaque: Bool = false) -> UIImage {
        let srcW = image.size.width
        let srcH = image.size.height
        guard srcW > 0, srcH > 0 else { return image }
        let ratio = min(1.0, maxSide / max(srcW, srcH))
        let targetSize = CGSize(
            width: max(1, (srcW * ratio).rounded()),
            height: max(1, (srcH * ratio).rounded())
        )
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = opaque
        return UIGraphicsImageRenderer(size: targetSize, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }

    static func rotate90(_ image: UIImage, clockwise: Bool, opaque: Bool = false) -> UIImage {
        let normalized = normalizedUpImage(image, maxSide: max(image.size.width, image.size.height), opaque: opaque)
        let w = normalized.size.width
        let h = normalized.size.height
        guard w > 0, h > 0 else { return normalized }
        let newSize = CGSize(width: h, height: w)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = opaque
        return UIGraphicsImageRenderer(size: newSize, format: format).image { ctx in
            let cg = ctx.cgContext
            cg.translateBy(x: newSize.width * 0.5, y: newSize.height * 0.5)
            cg.rotate(by: clockwise ? (.pi / 2) : (-.pi / 2))
            normalized.draw(in: CGRect(x: -w * 0.5, y: -h * 0.5, width: w, height: h))
        }
    }

    static func flipHorizontal(_ image: UIImage, opaque: Bool = false) -> UIImage {
        let normalized = normalizedUpImage(image, maxSide: max(image.size.width, image.size.height), opaque: opaque)
        let size = normalized.size
        guard size.width > 0, size.height > 0 else { return normalized }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = opaque
        return UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            let cg = ctx.cgContext
            cg.translateBy(x: size.width, y: 0)
            cg.scaleBy(x: -1, y: 1)
            normalized.draw(in: CGRect(origin: .zero, size: size))
        }
    }

    static func paddedTransparentCanvas(_ image: UIImage, marginRatio: CGFloat = 0.12, maxSide: CGFloat = 1400) -> UIImage {
        let norm = normalizedUpImage(image, maxSide: maxSide * (1 - marginRatio * 2), opaque: false)
        let padX = max(16, (norm.size.width * marginRatio).rounded())
        let padY = max(16, (norm.size.height * marginRatio).rounded())
        let total = CGSize(width: norm.size.width + padX * 2, height: norm.size.height + padY * 2)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        return UIGraphicsImageRenderer(size: total, format: format).image { _ in
            norm.draw(in: CGRect(x: padX, y: padY, width: norm.size.width, height: norm.size.height))
        }
    }

    /// 裁去四周全透明留白；若整张图已被擦空则返回 nil
    static func trimTransparentPixels(_ image: UIImage, padding: Int = 8) -> UIImage? {
        let norm = normalizedUpImage(image, maxSide: 1600, opaque: false)
        guard let cg = norm.cgImage else { return nil }
        let width = cg.width
        let height = cg.height
        guard width > 0, height > 0 else { return nil }

        let bytesPerRow = width * 4
        var pixels = [UInt8](repeating: 0, count: height * bytesPerRow)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        guard let ctx = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            return norm
        }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))

        var minX = width
        var minY = height
        var maxX = -1
        var maxY = -1
        let threshold: UInt8 = 6

        for y in 0..<height {
            let rowOffset = y * bytesPerRow
            for x in 0..<width {
                let alpha = pixels[rowOffset + x * 4 + 3]
                if alpha > threshold {
                    if x < minX { minX = x }
                    if x > maxX { maxX = x }
                    if y < minY { minY = y }
                    if y > maxY { maxY = y }
                }
            }
        }

        guard maxX >= minX, maxY >= minY else {
            return nil
        }

        let cropMinX = max(0, minX - padding)
        let cropMinY = max(0, minY - padding)
        let cropMaxX = min(width - 1, maxX + padding)
        let cropMaxY = min(height - 1, maxY + padding)
        let cropRect = CGRect(
            x: cropMinX,
            y: cropMinY,
            width: cropMaxX - cropMinX + 1,
            height: cropMaxY - cropMinY + 1
        )
        guard let cropped = cg.cropping(to: cropRect) else {
            return norm
        }
        return UIImage(cgImage: cropped, scale: 1, orientation: .up)
    }

    /// 判断选入图片是否本身已带明显透明背景（如现成 PNG 贴图）
    static func hasSignificantTransparency(_ image: UIImage) -> Bool {
        guard let cg = image.cgImage else { return false }
        let alphaInfo = cg.alphaInfo
        let supportsAlpha: Bool = {
            switch alphaInfo {
            case .first, .last, .premultipliedFirst, .premultipliedLast, .alphaOnly:
                return true
            default:
                return false
            }
        }()
        guard supportsAlpha else { return false }

        let sampleSide = 64
        let bytesPerRow = sampleSide * 4
        var pixels = [UInt8](repeating: 0, count: sampleSide * bytesPerRow)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        guard let ctx = CGContext(
            data: &pixels,
            width: sampleSide,
            height: sampleSide,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            return false
        }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: sampleSide, height: sampleSide))
        var transparentCount = 0
        let total = sampleSide * sampleSide
        for i in 0..<total {
            if pixels[i * 4 + 3] < 220 {
                transparentCount += 1
            }
        }
        return Double(transparentCount) / Double(total) >= 0.04
    }

    static func compressedJPEG(_ image: UIImage, maxSide: CGFloat = 1600, quality: CGFloat = 0.85) -> Data? {
        let norm = normalizedUpImage(image, maxSide: maxSide, opaque: true)
        return norm.jpegData(compressionQuality: quality)
    }
}

// MARK: - 棋盘格透明预览背景

struct TransparencyCheckerboard: View {
    var cellSize: CGFloat = 12
    var lightColor: Color = Color.white
    var darkColor: Color = Color.inkPrimary.opacity(0.065)

    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(lightColor))
            let rows = Int(ceil(size.height / cellSize))
            let cols = Int(ceil(size.width / cellSize))
            for r in 0..<rows {
                for c in 0..<cols where (r + c).isMultiple(of: 2) {
                    let rect = CGRect(x: CGFloat(c) * cellSize, y: CGFloat(r) * cellSize, width: cellSize, height: cellSize)
                    context.fill(Path(rect), with: .color(darkColor))
                }
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - 1. 图片裁剪与旋转编辑器（支持主图和透明贴图）

struct ImageCropRotateSheet: View {
    enum AspectPreset: String, CaseIterable, Identifiable {
        case free = "自由"
        case square = "1:1"
        case fourThree = "4:3"
        case threeFour = "3:4"
        case sixteenNine = "16:9"

        var id: String { rawValue }

        /// 宽高比 width / height
        var ratio: CGFloat? {
            switch self {
            case .free: return nil
            case .square: return 1.0
            case .fourThree: return 4.0 / 3.0
            case .threeFour: return 3.0 / 4.0
            case .sixteenNine: return 16.0 / 9.0
            }
        }
    }

    private enum DragHandle {
        case move
        case topLeft, topRight, bottomLeft, bottomRight
    }

    let initialImage: UIImage
    var title: String = "裁剪与调整"
    var preservesAlpha: Bool = false
    var onConfirm: (UIImage) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var workingImage: UIImage
    @State private var aspectPreset: AspectPreset = .free
    /// 归一化 [0, 1] 裁剪框
    @State private var cropRect = CGRect(x: 0.0, y: 0.0, width: 1.0, height: 1.0)
    @State private var dragStartRect: CGRect?
    @State private var activeHandle: DragHandle?

    init(
        initialImage: UIImage,
        title: String = "裁剪与调整",
        preservesAlpha: Bool = false,
        onConfirm: @escaping (UIImage) -> Void
    ) {
        self.initialImage = initialImage
        self.title = title
        self.preservesAlpha = preservesAlpha
        self.onConfirm = onConfirm
        let normalized = RecipeImageEditHelpers.normalizedUpImage(initialImage, maxSide: 1600, opaque: !preservesAlpha)
        _workingImage = State(initialValue: normalized)
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            cropStage
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            bottomPanel
        }
        .background(Color(red: 0.08, green: 0.08, blue: 0.09).ignoresSafeArea())
        .preferredColorScheme(.dark)
    }

    private var topBar: some View {
        HStack {
            Button("取消") {
                dismiss()
            }
            .font(AppFont.body(15))
            .foregroundStyle(.white.opacity(0.85))
            .frame(minHeight: 44)

            Spacer()

            Text(title)
                .font(AppFont.headline(16))
                .foregroundStyle(.white)

            Spacer()

            Button("复原") {
                Haptics.light()
                workingImage = RecipeImageEditHelpers.normalizedUpImage(initialImage, maxSide: 1600, opaque: !preservesAlpha)
                aspectPreset = .free
                cropRect = CGRect(x: 0, y: 0, width: 1, height: 1)
            }
            .font(AppFont.body(14))
            .foregroundStyle(.white.opacity(0.82))
            .frame(minHeight: 44)
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
    }

    private var cropStage: some View {
        GeometryReader { geo in
            let fitted = fittedImageRect(in: geo.size, imageSize: workingImage.size)
            let box = CGRect(
                x: fitted.minX + cropRect.minX * fitted.width,
                y: fitted.minY + cropRect.minY * fitted.height,
                width: cropRect.width * fitted.width,
                height: cropRect.height * fitted.height
            )

            ZStack {
                if preservesAlpha {
                    TransparencyCheckerboard(
                        cellSize: 12,
                        lightColor: Color(white: 0.24),
                        darkColor: Color(white: 0.17)
                    )
                    .frame(width: fitted.width, height: fitted.height)
                    .position(x: fitted.midX, y: fitted.midY)
                }

                Image(uiImage: workingImage)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: fitted.width, height: fitted.height)
                    .position(x: fitted.midX, y: fitted.midY)

                // 外部暗角遮罩
                Path { p in
                    p.addRect(fitted)
                    p.addRect(box)
                }
                .fill(Color.black.opacity(0.56), style: FillStyle(eoFill: true))
                .allowsHitTesting(false)

                // 三分线与边框
                cropOverlay(box: box)
                    .allowsHitTesting(false)

                // 交互手势层
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 1)
                            .onChanged { value in
                                handleDragChanged(value: value, fitted: fitted, currentBox: box)
                            }
                            .onEnded { _ in
                                dragStartRect = nil
                                activeHandle = nil
                            }
                    )
            }
        }
    }

    private func cropOverlay(box: CGRect) -> some View {
        ZStack {
            // 三分辅助线
            Path { path in
                for i in 1...2 {
                    let x = box.minX + box.width * CGFloat(i) / 3.0
                    path.move(to: CGPoint(x: x, y: box.minY))
                    path.addLine(to: CGPoint(x: x, y: box.maxY))
                    let y = box.minY + box.height * CGFloat(i) / 3.0
                    path.move(to: CGPoint(x: box.minX, y: y))
                    path.addLine(to: CGPoint(x: box.maxX, y: y))
                }
            }
            .stroke(Color.white.opacity(0.35), lineWidth: 0.7)

            Rectangle()
                .strokeBorder(Color.white, lineWidth: 1.6)
                .frame(width: box.width, height: box.height)
                .position(x: box.midX, y: box.midY)

            // 四角手柄
            ForEach(0..<4, id: \.self) { idx in
                let pt: CGPoint = {
                    switch idx {
                    case 0: return CGPoint(x: box.minX, y: box.minY)
                    case 1: return CGPoint(x: box.maxX, y: box.minY)
                    case 2: return CGPoint(x: box.minX, y: box.maxY)
                    default: return CGPoint(x: box.maxX, y: box.maxY)
                    }
                }()
                Circle()
                    .fill(Color.white)
                    .frame(width: 14, height: 14)
                    .shadow(color: .black.opacity(0.45), radius: 3, y: 1)
                    .position(pt)
            }
        }
    }

    private var bottomPanel: some View {
        VStack(spacing: 14) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(AspectPreset.allCases) { preset in
                        let selected = aspectPreset == preset
                        Button {
                            Haptics.light()
                            aspectPreset = preset
                            applyAspectPreset(preset)
                        } label: {
                            Text(preset.rawValue)
                                .font(.system(size: 12.5, weight: selected ? .semibold : .medium, design: .rounded))
                                .foregroundStyle(selected ? Color.actionInk : .white.opacity(0.85))
                                .padding(.horizontal, 13)
                                .frame(height: 32)
                                .background(selected ? Color.white : Color.white.opacity(0.12), in: Capsule())
                        }
                        .buttonStyle(SoftPressStyle())
                    }
                }
                .padding(.horizontal, 20)
            }

            HStack(spacing: 18) {
                transformButton(icon: "rotate.left", label: "左转") {
                    workingImage = RecipeImageEditHelpers.rotate90(workingImage, clockwise: false, opaque: !preservesAlpha)
                    resetCropForCurrentPreset()
                }
                transformButton(icon: "rotate.right", label: "右转") {
                    workingImage = RecipeImageEditHelpers.rotate90(workingImage, clockwise: true, opaque: !preservesAlpha)
                    resetCropForCurrentPreset()
                }
                transformButton(icon: "arrow.left.and.right.righttriangle.left.righttriangle.right", label: "翻转") {
                    workingImage = RecipeImageEditHelpers.flipHorizontal(workingImage, opaque: !preservesAlpha)
                }
            }

            Button {
                Haptics.light()
                confirmCrop()
            } label: {
                Text("应用裁剪")
                    .font(.system(size: 15.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.actionInk)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            }
            .buttonStyle(SoftPressStyle())
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
        .padding(.top, 12)
        .background(Color.black.opacity(0.45))
    }

    private func transformButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.light()
            action()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 13.5, weight: .semibold))
                Text(label)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .frame(height: 36)
            .background(Color.white.opacity(0.12), in: Capsule())
        }
        .buttonStyle(SoftPressStyle())
    }

    private func fittedImageRect(in container: CGSize, imageSize: CGSize) -> CGRect {
        guard container.width > 0, container.height > 0, imageSize.width > 0, imageSize.height > 0 else {
            return .zero
        }
        let scale = min(container.width / imageSize.width, container.height / imageSize.height)
        let w = imageSize.width * scale
        let h = imageSize.height * scale
        return CGRect(
            x: (container.width - w) * 0.5,
            y: (container.height - h) * 0.5,
            width: w,
            height: h
        )
    }

    private func resetCropForCurrentPreset() {
        if aspectPreset == .free {
            cropRect = CGRect(x: 0, y: 0, width: 1, height: 1)
        } else {
            applyAspectPreset(aspectPreset)
        }
    }

    private func applyAspectPreset(_ preset: AspectPreset) {
        guard let targetRatio = preset.ratio,
              workingImage.size.width > 0,
              workingImage.size.height > 0 else {
            return
        }
        let imgW = workingImage.size.width
        let imgH = workingImage.size.height
        // normalizedWidth * imgW / (normalizedHeight * imgH) == targetRatio
        let normRatio = targetRatio * (imgH / imgW)
        var w: CGFloat = 1.0
        var h: CGFloat = w / normRatio
        if h > 1.0 {
            h = 1.0
            w = h * normRatio
        }
        cropRect = CGRect(
            x: (1.0 - w) * 0.5,
            y: (1.0 - h) * 0.5,
            width: w,
            height: h
        )
    }

    private func handleDragChanged(value: DragGesture.Value, fitted: CGRect, currentBox: CGRect) {
        guard fitted.width > 1, fitted.height > 1 else { return }

        if dragStartRect == nil {
            dragStartRect = cropRect
            let start = value.startLocation
            let hitRadius: CGFloat = 34
            let corners: [(DragHandle, CGPoint)] = [
                (.topLeft, CGPoint(x: currentBox.minX, y: currentBox.minY)),
                (.topRight, CGPoint(x: currentBox.maxX, y: currentBox.minY)),
                (.bottomLeft, CGPoint(x: currentBox.minX, y: currentBox.maxY)),
                (.bottomRight, CGPoint(x: currentBox.maxX, y: currentBox.maxY))
            ]
            if let matched = corners.min(by: { hypot($0.1.x - start.x, $0.1.y - start.y) < hypot($1.1.x - start.x, $1.1.y - start.y) }),
               hypot(matched.1.x - start.x, matched.1.y - start.y) <= hitRadius {
                activeHandle = matched.0
            } else {
                activeHandle = .move
            }
        }

        guard let startRect = dragStartRect, let handle = activeHandle else { return }
        let dx = value.translation.width / fitted.width
        let dy = value.translation.height / fitted.height
        let minSide: CGFloat = 0.14

        if handle == .move {
            let nx = min(max(0, startRect.minX + dx), 1 - startRect.width)
            let ny = min(max(0, startRect.minY + dy), 1 - startRect.height)
            cropRect = CGRect(x: nx, y: ny, width: startRect.width, height: startRect.height)
            return
        }

        if let targetRatio = aspectPreset.ratio, workingImage.size.width > 0, workingImage.size.height > 0 {
            let normRatio = targetRatio * (workingImage.size.height / workingImage.size.width)
            let baseMinW = max(minSide, minSide * normRatio)
            switch handle {
            case .bottomRight:
                let maxW = min(1 - startRect.minX, (1 - startRect.minY) * normRatio)
                let minW = min(baseMinW, maxW)
                let w = min(max(minW, startRect.width + dx), maxW)
                let h = w / normRatio
                cropRect = CGRect(x: startRect.minX, y: startRect.minY, width: w, height: h)
            case .topLeft:
                let anchorX = startRect.maxX
                let anchorY = startRect.maxY
                let maxW = min(anchorX, anchorY * normRatio)
                let minW = min(baseMinW, maxW)
                let w = min(max(minW, startRect.width - dx), maxW)
                let h = w / normRatio
                cropRect = CGRect(x: anchorX - w, y: anchorY - h, width: w, height: h)
            case .topRight:
                let anchorX = startRect.minX
                let anchorY = startRect.maxY
                let maxW = min(1 - anchorX, anchorY * normRatio)
                let minW = min(baseMinW, maxW)
                let w = min(max(minW, startRect.width + dx), maxW)
                let h = w / normRatio
                cropRect = CGRect(x: anchorX, y: anchorY - h, width: w, height: h)
            case .bottomLeft:
                let anchorX = startRect.maxX
                let anchorY = startRect.minY
                let maxW = min(anchorX, (1 - anchorY) * normRatio)
                let minW = min(baseMinW, maxW)
                let w = min(max(minW, startRect.width - dx), maxW)
                let h = w / normRatio
                cropRect = CGRect(x: anchorX - w, y: anchorY, width: w, height: h)
            case .move:
                break
            }
        } else {
            var minX = startRect.minX
            var maxX = startRect.maxX
            var minY = startRect.minY
            var maxY = startRect.maxY

            switch handle {
            case .topLeft:
                minX = min(max(0, startRect.minX + dx), maxX - minSide)
                minY = min(max(0, startRect.minY + dy), maxY - minSide)
            case .topRight:
                maxX = max(min(1, startRect.maxX + dx), minX + minSide)
                minY = min(max(0, startRect.minY + dy), maxY - minSide)
            case .bottomLeft:
                minX = min(max(0, startRect.minX + dx), maxX - minSide)
                maxY = max(min(1, startRect.maxY + dy), minY + minSide)
            case .bottomRight:
                maxX = max(min(1, startRect.maxX + dx), minX + minSide)
                maxY = max(min(1, startRect.maxY + dy), minY + minSide)
            case .move:
                break
            }
            cropRect = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
        }
    }

    private func confirmCrop() {
        guard let cg = workingImage.cgImage else {
            onConfirm(workingImage)
            dismiss()
            return
        }
        let pxW = CGFloat(cg.width)
        let pxH = CGFloat(cg.height)
        let rect = CGRect(
            x: max(0, (cropRect.minX * pxW).rounded(.down)),
            y: max(0, (cropRect.minY * pxH).rounded(.down)),
            width: max(1, (cropRect.width * pxW).rounded()),
            height: max(1, (cropRect.height * pxH).rounded())
        ).intersection(CGRect(x: 0, y: 0, width: pxW, height: pxH))

        if rect.width >= 1, rect.height >= 1, let croppedCG = cg.cropping(to: rect) {
            let result = UIImage(cgImage: croppedCG, scale: 1, orientation: .up)
            onConfirm(result)
        } else {
            onConfirm(workingImage)
        }
        dismiss()
    }
}

// MARK: - 2. 抠图贴图涂抹精修编辑器（擦除多余背景 + 恢复主体 + 双指缩放）

enum CutoutBrushMode: String, CaseIterable, Identifiable {
    case erase = "擦除"
    case restore = "恢复"

    var id: String { rawValue }
    var icon: String {
        switch self {
        case .erase: return "eraser.fill"
        case .restore: return "paintbrush.pointed.fill"
        }
    }
}

enum CutoutPreviewBackdrop: String, CaseIterable, Identifiable {
    case checker = "透明格"
    case warmPaper = "暖白底"
    case dark = "深色底"

    var id: String { rawValue }
}

@MainActor
final class CutoutMaskCanvasController: ObservableObject {
    @Published private(set) var canUndo = false
    @Published private(set) var canRedo = false
    @Published var zoomScale: CGFloat = 1.0

    fileprivate weak var canvasView: CutoutBrushCanvasUIView?
    private var pendingLoad: (working: UIImage, restoreReference: UIImage, ghostImage: UIImage?)?
    private var pendingGhost: (image: UIImage?, visible: Bool)?

    fileprivate func attach(_ view: CutoutBrushCanvasUIView) {
        let isNewAttachment = (canvasView !== view)
        canvasView = view
        view.controller = self
        if let load = pendingLoad {
            pendingLoad = nil
            view.loadImages(working: load.working, restoreReference: load.restoreReference, ghostImage: load.ghostImage)
        } else if isNewAttachment {
            view.setNeedsDisplay()
        }
        if let ghost = pendingGhost {
            pendingGhost = nil
            view.setGhost(image: ghost.image, visible: ghost.visible)
        }
    }

    func configure(working: UIImage, restoreReference: UIImage, ghostImage: UIImage?) {
        if let canvasView {
            pendingLoad = nil
            canvasView.loadImages(working: working, restoreReference: restoreReference, ghostImage: ghostImage)
        } else {
            pendingLoad = (working, restoreReference, ghostImage)
        }
    }

    func updateGhost(_ ghostImage: UIImage?, visible: Bool) {
        if let canvasView {
            pendingGhost = nil
            canvasView.setGhost(image: ghostImage, visible: visible)
        } else {
            pendingGhost = (ghostImage, visible)
        }
    }

    func undo() {
        canvasView?.performUndo()
    }

    func redo() {
        canvasView?.performRedo()
    }

    func resetViewport() {
        canvasView?.resetZoomAndPan()
    }

    func replaceWorkingImage(_ image: UIImage, restoreReference: UIImage? = nil, pushUndo: Bool = true) {
        canvasView?.replaceWorkingImage(image, restoreReference: restoreReference, pushUndo: pushUndo)
    }

    func exportImage() -> UIImage? {
        canvasView?.currentWorkingUIImage()
    }

    fileprivate func syncHistory(canUndo: Bool, canRedo: Bool) {
        if self.canUndo != canUndo { self.canUndo = canUndo }
        if self.canRedo != canRedo { self.canRedo = canRedo }
    }

    fileprivate func syncZoom(_ scale: CGFloat) {
        if abs(zoomScale - scale) > 0.02 {
            zoomScale = scale
        }
    }
}

struct CutoutMaskEditorSheet: View {
    let sourceImageURL: String?
    let initialCutoutURL: String?
    var initialCutoutImage: UIImage? = nil
    var onSavedPNG: (Data) async throws -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var controller = CutoutMaskCanvasController()

    @State private var brushMode: CutoutBrushMode = .erase
    @State private var brushSize: CGFloat = 26
    @State private var backdrop: CutoutPreviewBackdrop = .checker
    @State private var showSourceGhost: Bool = false

    @State private var loadedSourceImage: UIImage?
    @State private var isAlignedWithSource: Bool = false
    @State private var isLoading = true
    @State private var isProcessing = false
    @State private var processingText = "正在准备画布"
    @State private var errorMessage: String?
    @State private var croppingImage: IdentifiableUIImage?

    private struct IdentifiableUIImage: Identifiable {
        let id = UUID()
        let image: UIImage
    }

    var body: some View {
        ZStack {
            Color(red: 0.09, green: 0.09, blue: 0.10).ignoresSafeArea()

            VStack(spacing: 0) {
                headerBar
                stageToolbar
                canvasArea
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                bottomControls
            }

            if isLoading || isProcessing {
                Color.black.opacity(0.42).ignoresSafeArea()
                VStack(spacing: 10) {
                    ProgressView().tint(.white)
                    Text(processingText)
                        .font(AppFont.caption(13))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 16)
                .background(Color.actionInk.opacity(0.92), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
        .preferredColorScheme(.dark)
        .interactiveDismissDisabled(isProcessing)
        .toast($errorMessage)
        .task {
            await bootstrapImages()
        }
        .onChange(of: showSourceGhost) { _, visible in
            controller.updateGhost(isAlignedWithSource ? loadedSourceImage : nil, visible: visible)
        }
        .fullScreenCover(item: $croppingImage) { item in
            ImageCropRotateSheet(
                initialImage: item.image,
                title: "裁剪透明贴图",
                preservesAlpha: true
            ) { cropped in
                let padded = RecipeImageEditHelpers.paddedTransparentCanvas(cropped)
                isAlignedWithSource = false
                showSourceGhost = false
                controller.replaceWorkingImage(padded, restoreReference: padded, pushUndo: true)
            }
        }
    }

    private var headerBar: some View {
        HStack(spacing: 12) {
            Button("取消") {
                dismiss()
            }
            .font(AppFont.body(15))
            .foregroundStyle(.white.opacity(0.85))
            .disabled(isProcessing)

            Spacer()

            Text("精修抠图贴图")
                .font(AppFont.headline(16))
                .foregroundStyle(.white)

            Spacer()

            HStack(spacing: 12) {
                Button {
                    Haptics.light()
                    controller.undo()
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(controller.canUndo ? .white : .white.opacity(0.28))
                        .frame(width: 34, height: 34)
                }
                .disabled(!controller.canUndo || isProcessing)
                .accessibilityLabel("撤销")

                Button {
                    Haptics.light()
                    controller.redo()
                } label: {
                    Image(systemName: "arrow.uturn.forward")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(controller.canRedo ? .white : .white.opacity(0.28))
                        .frame(width: 34, height: 34)
                }
                .disabled(!controller.canRedo || isProcessing)
                .accessibilityLabel("重做")
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
    }

    private var stageToolbar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(CutoutPreviewBackdrop.allCases) { item in
                    let active = backdrop == item
                    Button {
                        Haptics.light()
                        backdrop = item
                    } label: {
                        Text(item.rawValue)
                            .font(.system(size: 12, weight: active ? .semibold : .medium, design: .rounded))
                            .foregroundStyle(active ? Color.actionInk : .white.opacity(0.82))
                            .padding(.horizontal, 11)
                            .frame(height: 28)
                            .background(active ? Color.white : Color.white.opacity(0.11), in: Capsule())
                    }
                    .buttonStyle(SoftPressStyle())
                }

                if loadedSourceImage != nil {
                    Divider()
                        .frame(height: 16)
                        .overlay(Color.white.opacity(0.2))

                    Button {
                        Haptics.light()
                        if !isAlignedWithSource {
                            Task { await reCutoutFromSource(enableGhost: true) }
                        } else {
                            showSourceGhost.toggle()
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: showSourceGhost && isAlignedWithSource ? "eye.fill" : "eye")
                                .font(.system(size: 11.5, weight: .semibold))
                            Text(isAlignedWithSource ? "原图对照" : "对照原图补全")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                        }
                        .foregroundStyle(showSourceGhost && isAlignedWithSource ? Color.actionInk : .white.opacity(0.88))
                        .padding(.horizontal, 11)
                        .frame(height: 28)
                        .background(
                            showSourceGhost && isAlignedWithSource ? Color.white : Color.white.opacity(0.12),
                            in: Capsule()
                        )
                    }
                    .buttonStyle(SoftPressStyle())

                    Button {
                        Haptics.light()
                        Task { await reCutoutFromSource(enableGhost: showSourceGhost) }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "wand.and.stars")
                                .font(.system(size: 11.5, weight: .semibold))
                            Text("智能重抠")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                        }
                        .foregroundStyle(.white.opacity(0.88))
                        .padding(.horizontal, 11)
                        .frame(height: 28)
                        .background(Color.white.opacity(0.12), in: Capsule())
                    }
                    .buttonStyle(SoftPressStyle())
                }

                Button {
                    Haptics.light()
                    if let current = controller.exportImage(),
                       let trimmed = RecipeImageEditHelpers.trimTransparentPixels(current, padding: 8) {
                        croppingImage = IdentifiableUIImage(image: trimmed)
                    } else if let current = controller.exportImage() {
                        croppingImage = IdentifiableUIImage(image: current)
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "crop")
                            .font(.system(size: 11.5, weight: .semibold))
                        Text("裁剪")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                    }
                    .foregroundStyle(.white.opacity(0.88))
                    .padding(.horizontal, 11)
                    .frame(height: 28)
                    .background(Color.white.opacity(0.12), in: Capsule())
                }
                .buttonStyle(SoftPressStyle())
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 6)
        }
    }

    private var canvasArea: some View {
        ZStack(alignment: .bottomTrailing) {
            Group {
                switch backdrop {
                case .checker:
                    TransparencyCheckerboard(
                        cellSize: 14,
                        lightColor: Color(white: 0.24),
                        darkColor: Color(white: 0.17)
                    )
                case .warmPaper:
                    Color.paperWarm
                case .dark:
                    Color(white: 0.06)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.14), lineWidth: 0.8)
            }

            CutoutBrushCanvasRepresentable(
                controller: controller,
                brushMode: brushMode,
                brushSize: brushSize
            )
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

            if controller.zoomScale > 1.05 {
                Button {
                    Haptics.light()
                    controller.resetViewport()
                } label: {
                    Text(String(format: "%.1fx · 复位", controller.zoomScale))
                        .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .padding(.horizontal, 11)
                        .frame(height: 28)
                        .background(Color.black.opacity(0.62), in: Capsule())
                        .overlay {
                            Capsule().strokeBorder(Color.white.opacity(0.28), lineWidth: 0.6)
                        }
                }
                .buttonStyle(SoftPressStyle())
                .padding(12)
            }
        }
    }

    private var bottomControls: some View {
        VStack(spacing: 14) {
            Text("单指涂抹\(brushMode == .erase ? "擦除多余背景" : "恢复菜品边缘") · 双指捏合放大精修")
                .font(AppFont.caption(11.5))
                .foregroundStyle(.white.opacity(0.62))

            HStack(spacing: 10) {
                ForEach(CutoutBrushMode.allCases) { mode in
                    let selected = brushMode == mode
                    Button {
                        Haptics.light()
                        brushMode = mode
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: mode.icon)
                                .font(.system(size: 13.5, weight: .semibold))
                            Text(mode.rawValue)
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                        }
                        .foregroundStyle(selected ? Color.actionInk : .white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background(selected ? Color.white : Color.white.opacity(0.12), in: Capsule())
                    }
                    .buttonStyle(SoftPressStyle())
                }
            }
            .padding(.horizontal, 20)

            HStack(spacing: 12) {
                Circle()
                    .fill(Color.white.opacity(0.75))
                    .frame(width: 7, height: 7)
                Slider(value: $brushSize, in: 8...64)
                    .tint(.white)
                Circle()
                    .fill(Color.white.opacity(0.9))
                    .frame(width: 20, height: 20)
            }
            .padding(.horizontal, 22)

            Button {
                Task { await saveEditedCutout() }
            } label: {
                Text("保存贴图")
                    .font(.system(size: 15.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.actionInk)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            }
            .buttonStyle(SoftPressStyle())
            .disabled(isLoading || isProcessing)
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
        .padding(.top, 10)
        .background(Color.black.opacity(0.48))
    }

    @MainActor
    private func bootstrapImages() async {
        isLoading = true
        processingText = "正在读取图片"
        defer { isLoading = false }

        async let fetchedSource = RecipeImageEditHelpers.loadUIImage(from: sourceImageURL)
        let fetchedCutout: UIImage?
        if let initialCutoutImage {
            fetchedCutout = initialCutoutImage
        } else {
            fetchedCutout = await RecipeImageEditHelpers.loadUIImage(from: initialCutoutURL)
        }
        let source = await fetchedSource
        if let source {
            loadedSourceImage = RecipeImageEditHelpers.normalizedUpImage(source, maxSide: 1400, opaque: false)
        }

        if let cutout = fetchedCutout {
            let padded = RecipeImageEditHelpers.paddedTransparentCanvas(cutout, marginRatio: 0.12, maxSide: 1400)
            isAlignedWithSource = false
            showSourceGhost = false
            controller.configure(working: padded, restoreReference: padded, ghostImage: nil)
        } else if let src = loadedSourceImage {
            // 尚未有抠图时，先尝试基于主图自动分离全尺寸前景，失败则直接放入原图供手涂擦除
            isAlignedWithSource = true
            if let autoCutout = try? await ImageCutoutService.shared.makeCutout(from: src) {
                let normSource = RecipeImageEditHelpers.normalizedUpImage(autoCutout.source, maxSide: 1400, opaque: false)
                let normFG = RecipeImageEditHelpers.normalizedUpImage(autoCutout.foreground, maxSide: 1400, opaque: false)
                loadedSourceImage = normSource
                showSourceGhost = true
                controller.configure(working: normFG, restoreReference: normSource, ghostImage: normSource)
                controller.updateGhost(normSource, visible: true)
            } else {
                showSourceGhost = false
                controller.configure(working: src, restoreReference: src, ghostImage: src)
            }
        } else {
            errorMessage = "未找到可编辑的图片"
        }
    }

    @MainActor
    private func reCutoutFromSource(enableGhost: Bool) async {
        guard let src = loadedSourceImage, !isProcessing else { return }
        isProcessing = true
        processingText = "正在从主图提取主体"
        defer { isProcessing = false }

        do {
            let result = try await ImageCutoutService.shared.makeCutout(from: src)
            let normSource = RecipeImageEditHelpers.normalizedUpImage(result.source, maxSide: 1400, opaque: false)
            let normFG = RecipeImageEditHelpers.normalizedUpImage(result.foreground, maxSide: 1400, opaque: false)
            loadedSourceImage = normSource
            isAlignedWithSource = true
            showSourceGhost = enableGhost
            controller.configure(working: normFG, restoreReference: normSource, ghostImage: normSource)
            controller.updateGhost(normSource, visible: enableGhost)
            Haptics.light()
        } catch {
            // 即便自动识别不到主体，也切换为原图底供手动涂抹擦除
            isAlignedWithSource = true
            showSourceGhost = false
            controller.configure(working: src, restoreReference: src, ghostImage: src)
            errorMessage = "未自动识别到明显主体，已载入原图供手动擦除背景"
        }
    }

    @MainActor
    private func saveEditedCutout() async {
        guard !isProcessing else { return }
        guard let exported = controller.exportImage() else {
            errorMessage = "无法导出贴图"
            return
        }
        guard let trimmed = RecipeImageEditHelpers.trimTransparentPixels(exported, padding: 8),
              let pngData = trimmed.pngData() else {
            errorMessage = "贴图已全部擦空，若不想要贴图可在上一步点「清除贴图」"
            return
        }

        isProcessing = true
        processingText = "正在保存精修贴图"
        defer { isProcessing = false }
        do {
            try await onSavedPNG(pngData)
            Haptics.success()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct CutoutBrushCanvasRepresentable: UIViewRepresentable {
    let controller: CutoutMaskCanvasController
    let brushMode: CutoutBrushMode
    let brushSize: CGFloat

    func makeUIView(context: Context) -> CutoutBrushCanvasUIView {
        let view = CutoutBrushCanvasUIView()
        view.brushMode = brushMode
        view.brushSizePt = brushSize
        controller.attach(view)
        return view
    }

    func updateUIView(_ uiView: CutoutBrushCanvasUIView, context: Context) {
        uiView.brushMode = brushMode
        uiView.brushSizePt = brushSize
        controller.attach(uiView)
    }
}

final class CutoutBrushCanvasUIView: UIView, UIGestureRecognizerDelegate {
    weak var controller: CutoutMaskCanvasController?
    var brushMode: CutoutBrushMode = .erase
    var brushSizePt: CGFloat = 26

    private var workingCG: CGImage?
    private var restoreRefCG: CGImage?
    private var ghostCG: CGImage?
    private var showGhost: Bool = false
    private var pixelSize: CGSize = .zero

    private var undoStack: [CGImage] = []
    private var redoStack: [CGImage] = []
    private let maxHistory = 15

    // 当前单指涂抹笔迹（使用持久位图上下文做 O(1) 增量绘制）
    private var isDrawingStroke = false
    private var strokeStartCG: CGImage?
    private var strokeContext: CGContext?
    private var strokePoints: [CGPoint] = []
    private var cursorPointInView: CGPoint?

    // 视图缩放与平移
    private var zoomScale: CGFloat = 1.0
    private var panOffset: CGPoint = .zero
    private var pinchStartScale: CGFloat = 1.0
    private var panStartOffset: CGPoint = .zero

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
        isMultipleTouchEnabled = true
        contentMode = .redraw

        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        pinch.delegate = self
        addGestureRecognizer(pinch)

        let twoFingerPan = UIPanGestureRecognizer(target: self, action: #selector(handleTwoFingerPan(_:)))
        twoFingerPan.minimumNumberOfTouches = 2
        twoFingerPan.maximumNumberOfTouches = 2
        twoFingerPan.delegate = self
        addGestureRecognizer(twoFingerPan)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        true
    }

    func loadImages(working: UIImage, restoreReference: UIImage, ghostImage: UIImage?) {
        let normWorking = RecipeImageEditHelpers.normalizedUpImage(working, maxSide: 1400, opaque: false)
        let size = normWorking.size
        guard size.width > 0, size.height > 0, let wCG = normWorking.cgImage else { return }

        let alignedRestore = Self.renderToExactSize(restoreReference, size: size)
        let alignedGhost = ghostImage.flatMap { Self.renderToExactSize($0, size: size) }

        pixelSize = size
        workingCG = wCG
        restoreRefCG = alignedRestore?.cgImage ?? wCG
        ghostCG = alignedGhost?.cgImage
        undoStack.removeAll()
        redoStack.removeAll()
        zoomScale = 1.0
        panOffset = .zero
        notifyState()
        setNeedsDisplay()
    }

    func setGhost(image: UIImage?, visible: Bool) {
        if let image, pixelSize.width > 0 {
            ghostCG = Self.renderToExactSize(image, size: pixelSize)?.cgImage
        }
        showGhost = visible
        setNeedsDisplay()
    }

    func replaceWorkingImage(_ image: UIImage, restoreReference: UIImage?, pushUndo: Bool) {
        let norm = RecipeImageEditHelpers.normalizedUpImage(image, maxSide: 1400, opaque: false)
        guard norm.size.width > 0, norm.size.height > 0, let cg = norm.cgImage else { return }
        if pushUndo, let prev = workingCG, prev.width == cg.width, prev.height == cg.height {
            pushUndoSnapshot(prev)
        } else {
            undoStack.removeAll()
        }
        redoStack.removeAll()
        pixelSize = norm.size
        workingCG = cg
        if let restoreReference {
            restoreRefCG = Self.renderToExactSize(restoreReference, size: norm.size)?.cgImage ?? cg
        }
        zoomScale = 1.0
        panOffset = .zero
        notifyState()
        setNeedsDisplay()
    }

    func currentWorkingUIImage() -> UIImage? {
        guard let workingCG else { return nil }
        return UIImage(cgImage: workingCG, scale: 1, orientation: .up)
    }

    func performUndo() {
        guard let prev = undoStack.popLast(), let current = workingCG else { return }
        redoStack.append(current)
        workingCG = prev
        notifyState()
        setNeedsDisplay()
    }

    func performRedo() {
        guard let next = redoStack.popLast(), let current = workingCG else { return }
        undoStack.append(current)
        workingCG = next
        notifyState()
        setNeedsDisplay()
    }

    func resetZoomAndPan() {
        zoomScale = 1.0
        panOffset = .zero
        notifyState()
        setNeedsDisplay()
    }

    // MARK: - Touch Handling (Single-Finger Brush)

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        let allTouches = event?.allTouches ?? touches
        if allTouches.count > 1 {
            cancelActiveStroke()
            return
        }
        guard let touch = touches.first, let currentCG = workingCG, pixelSize.width > 0 else { return }
        let viewPt = touch.location(in: self)
        let imgPt = viewPointToImagePoint(viewPt)
        isDrawingStroke = true
        strokeStartCG = currentCG
        strokeContext = makeBitmapContext(initialImage: currentCG)
        strokePoints = [imgPt]
        cursorPointInView = viewPt
        appendLatestStrokeSegment()
        setNeedsDisplay()
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        let allTouches = event?.allTouches ?? touches
        if allTouches.count > 1 {
            cancelActiveStroke()
            return
        }
        guard isDrawingStroke, let touch = touches.first else { return }
        let viewPt = touch.location(in: self)
        let imgPt = viewPointToImagePoint(viewPt)
        if let last = strokePoints.last, hypot(imgPt.x - last.x, imgPt.y - last.y) < 1.2 {
            cursorPointInView = viewPt
            setNeedsDisplay()
            return
        }
        strokePoints.append(imgPt)
        cursorPointInView = viewPt
        appendLatestStrokeSegment()
        setNeedsDisplay()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        finishActiveStroke()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        cancelActiveStroke()
    }

    private func cancelActiveStroke() {
        if isDrawingStroke {
            if let start = strokeStartCG {
                workingCG = start
            }
            isDrawingStroke = false
            strokeStartCG = nil
            strokeContext = nil
            strokePoints.removeAll()
            cursorPointInView = nil
            setNeedsDisplay()
        }
    }

    private func finishActiveStroke() {
        guard isDrawingStroke else { return }
        if strokePoints.count >= 2, let ctx = strokeContext {
            let h = pixelSize.height
            let n = strokePoints.count
            let prev = CGPoint(x: strokePoints[n - 2].x, y: h - strokePoints[n - 2].y)
            let last = CGPoint(x: strokePoints[n - 1].x, y: h - strokePoints[n - 1].y)
            let mid = CGPoint(x: (prev.x + last.x) * 0.5, y: (prev.y + last.y) * 0.5)
            let tail = CGMutablePath()
            tail.move(to: mid)
            tail.addLine(to: last)
            strokePathIntoContext(ctx, path: tail)
            if let updated = ctx.makeImage() {
                workingCG = updated
            }
        }
        if let start = strokeStartCG {
            pushUndoSnapshot(start)
            redoStack.removeAll()
        }
        isDrawingStroke = false
        strokeStartCG = nil
        strokeContext = nil
        strokePoints.removeAll()
        cursorPointInView = nil
        notifyState()
        setNeedsDisplay()
    }

    private func pushUndoSnapshot(_ image: CGImage) {
        undoStack.append(image)
        if undoStack.count > maxHistory {
            undoStack.removeFirst()
        }
    }

    // MARK: - Pinch & Pan Gestures

    @objc private func handlePinch(_ recognizer: UIPinchGestureRecognizer) {
        cancelActiveStroke()
        switch recognizer.state {
        case .began:
            pinchStartScale = zoomScale
        case .changed:
            zoomScale = min(max(1.0, pinchStartScale * recognizer.scale), 5.0)
            clampPanOffset()
            notifyState()
            setNeedsDisplay()
        default:
            if zoomScale <= 1.01 {
                zoomScale = 1.0
                panOffset = .zero
                notifyState()
                setNeedsDisplay()
            }
        }
    }

    @objc private func handleTwoFingerPan(_ recognizer: UIPanGestureRecognizer) {
        cancelActiveStroke()
        switch recognizer.state {
        case .began:
            panStartOffset = panOffset
        case .changed:
            let t = recognizer.translation(in: self)
            panOffset = CGPoint(x: panStartOffset.x + t.x, y: panStartOffset.y + t.y)
            clampPanOffset()
            setNeedsDisplay()
        default:
            break
        }
    }

    private func clampPanOffset() {
        let maxPanX = bounds.width * (zoomScale - 1) * 0.55
        let maxPanY = bounds.height * (zoomScale - 1) * 0.55
        panOffset.x = min(max(panOffset.x, -maxPanX), maxPanX)
        panOffset.y = min(max(panOffset.y, -maxPanY), maxPanY)
    }

    // MARK: - Coordinate Mapping & Rendering

    private func baseFittedRect() -> CGRect {
        guard bounds.width > 0, bounds.height > 0, pixelSize.width > 0, pixelSize.height > 0 else {
            return .zero
        }
        let insetBounds = bounds.insetBy(dx: 12, dy: 12)
        let ratio = min(insetBounds.width / pixelSize.width, insetBounds.height / pixelSize.height)
        let w = pixelSize.width * ratio
        let h = pixelSize.height * ratio
        return CGRect(
            x: bounds.midX - w * 0.5,
            y: bounds.midY - h * 0.5,
            width: w,
            height: h
        )
    }

    private func transformedImageRect() -> CGRect {
        let base = baseFittedRect()
        let w = base.width * zoomScale
        let h = base.height * zoomScale
        return CGRect(
            x: bounds.midX - w * 0.5 + panOffset.x,
            y: bounds.midY - h * 0.5 + panOffset.y,
            width: w,
            height: h
        )
    }

    private func viewPointToImagePoint(_ pt: CGPoint) -> CGPoint {
        let rect = transformedImageRect()
        guard rect.width > 0, rect.height > 0 else { return .zero }
        let nx = (pt.x - rect.minX) / rect.width
        let ny = (pt.y - rect.minY) / rect.height
        return CGPoint(x: nx * pixelSize.width, y: ny * pixelSize.height)
    }

    private func brushWidthInImagePixels() -> CGFloat {
        let rect = transformedImageRect()
        guard rect.width > 0 else { return brushSizePt }
        let pxPerPt = pixelSize.width / rect.width
        return max(2, brushSizePt * pxPerPt)
    }

    private func makeBitmapContext(initialImage: CGImage) -> CGContext? {
        let w = Int(pixelSize.width)
        let h = Int(pixelSize.height)
        guard w > 0, h > 0 else { return nil }
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        guard let ctx = CGContext(
            data: nil,
            width: w,
            height: h,
            bitsPerComponent: 8,
            bytesPerRow: w * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            return nil
        }
        ctx.draw(initialImage, in: CGRect(x: 0, y: 0, width: CGFloat(w), height: CGFloat(h)))
        return ctx
    }

    private func appendLatestStrokeSegment() {
        guard let ctx = strokeContext, !strokePoints.isEmpty else { return }
        let h = pixelSize.height
        let segment = CGMutablePath()
        let count = strokePoints.count

        if count == 1 {
            let p0 = CGPoint(x: strokePoints[0].x, y: h - strokePoints[0].y)
            segment.move(to: p0)
            segment.addLine(to: CGPoint(x: p0.x + 0.01, y: p0.y + 0.01))
        } else if count == 2 {
            let p0 = CGPoint(x: strokePoints[0].x, y: h - strokePoints[0].y)
            let p1 = CGPoint(x: strokePoints[1].x, y: h - strokePoints[1].y)
            let mid = CGPoint(x: (p0.x + p1.x) * 0.5, y: (p0.y + p1.y) * 0.5)
            segment.move(to: p0)
            segment.addLine(to: mid)
        } else {
            let pPrev2 = CGPoint(x: strokePoints[count - 3].x, y: h - strokePoints[count - 3].y)
            let pPrev1 = CGPoint(x: strokePoints[count - 2].x, y: h - strokePoints[count - 2].y)
            let pCurr = CGPoint(x: strokePoints[count - 1].x, y: h - strokePoints[count - 1].y)
            let mid1 = CGPoint(x: (pPrev2.x + pPrev1.x) * 0.5, y: (pPrev2.y + pPrev1.y) * 0.5)
            let mid2 = CGPoint(x: (pPrev1.x + pCurr.x) * 0.5, y: (pPrev1.y + pCurr.y) * 0.5)
            segment.move(to: mid1)
            segment.addQuadCurve(to: mid2, control: pPrev1)
        }

        strokePathIntoContext(ctx, path: segment)
        if let updated = ctx.makeImage() {
            workingCG = updated
        }
    }

    private func strokePathIntoContext(_ ctx: CGContext, path: CGPath) {
        let fullRect = CGRect(origin: .zero, size: pixelSize)
        let lineWidth = brushWidthInImagePixels()

        switch brushMode {
        case .erase:
            ctx.saveGState()
            ctx.setBlendMode(.destinationOut)
            ctx.setLineCap(.round)
            ctx.setLineJoin(.round)
            ctx.setLineWidth(lineWidth)
            ctx.setStrokeColor(UIColor.black.cgColor)
            ctx.addPath(path)
            ctx.strokePath()
            ctx.restoreGState()

        case .restore:
            guard let restoreRefCG else { break }
            // 先清掉笔迹区域旧半透像素，再将原图/参考图按笔迹蒙版精准贴回，防止边缘 alpha 叠加变脏
            ctx.saveGState()
            ctx.setBlendMode(.destinationOut)
            ctx.setLineCap(.round)
            ctx.setLineJoin(.round)
            ctx.setLineWidth(lineWidth)
            ctx.setStrokeColor(UIColor.black.cgColor)
            ctx.addPath(path)
            ctx.strokePath()
            ctx.restoreGState()

            ctx.saveGState()
            ctx.setBlendMode(.normal)
            ctx.beginTransparencyLayer(auxiliaryInfo: nil)
            ctx.setLineCap(.round)
            ctx.setLineJoin(.round)
            ctx.setLineWidth(lineWidth)
            ctx.setStrokeColor(UIColor.white.cgColor)
            ctx.addPath(path)
            ctx.strokePath()
            ctx.setBlendMode(.sourceIn)
            ctx.draw(restoreRefCG, in: fullRect)
            ctx.endTransparencyLayer()
            ctx.restoreGState()
        }
    }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        let drawRect = transformedImageRect()
        guard drawRect.width > 0, drawRect.height > 0 else { return }

        if showGhost, let ghostCG {
            ctx.saveGState()
            ctx.setAlpha(0.28)
            UIImage(cgImage: ghostCG, scale: 1, orientation: .up).draw(in: drawRect)
            ctx.restoreGState()
        }

        if let workingCG {
            UIImage(cgImage: workingCG, scale: 1, orientation: .up).draw(in: drawRect)
        }

        if let cursor = cursorPointInView {
            let r = brushSizePt * 0.5
            let ringRect = CGRect(x: cursor.x - r, y: cursor.y - r, width: r * 2, height: r * 2)
            ctx.saveGState()
            ctx.setStrokeColor(UIColor.white.cgColor)
            ctx.setLineWidth(2.0)
            ctx.strokeEllipse(in: ringRect)
            ctx.setStrokeColor(UIColor.black.withAlphaComponent(0.55).cgColor)
            ctx.setLineWidth(1.0)
            ctx.strokeEllipse(in: ringRect.insetBy(dx: -1, dy: -1))
            ctx.restoreGState()
        }
    }

    private func notifyState() {
        let u = !undoStack.isEmpty
        let r = !redoStack.isEmpty
        let z = zoomScale
        Task { @MainActor [weak controller] in
            controller?.syncHistory(canUndo: u, canRedo: r)
            controller?.syncZoom(z)
        }
    }

    private static func renderToExactSize(_ image: UIImage, size: CGSize) -> UIImage? {
        guard size.width > 0, size.height > 0 else { return nil }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}

// MARK: - 3. 菜谱主图与抠图独立工作台（详情页 / 列表卡片可直接唤起）

struct RecipePhotoStudioSheet: View {
    let recipe: Recipe
    var onSaved: (Recipe) -> Void = { _ in }

    @Environment(\.dismiss) private var dismiss

    @State private var coverImage: String
    @State private var cutoutImage: String
    @State private var photoChoices: [RecipePhotoChoice]

    @State private var coverPickerItem: PhotosPickerItem?
    @State private var customCutoutPickerItem: PhotosPickerItem?

    private enum FullScreenModal: Identifiable {
        case camera
        case cropCover(UIImage)
        case cropCutout(UIImage)
        case maskEditor
        case preview(PhotoGalleryPresentation)

        var id: String {
            switch self {
            case .camera: return "camera"
            case .cropCover: return "cropCover"
            case .cropCutout: return "cropCutout"
            case .maskEditor: return "maskEditor"
            case .preview(let p): return "preview-\(p.id.uuidString)"
            }
        }
    }

    @State private var activeModal: FullScreenModal?
    @State private var isProcessing = false
    @State private var processingText = "正在处理图片"
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(recipe: Recipe, onSaved: @escaping (Recipe) -> Void = { _ in }) {
        self.recipe = recipe
        self.onSaved = onSaved
        _coverImage = State(initialValue: recipe.coverImage ?? "")
        _cutoutImage = State(initialValue: recipe.cutoutImage ?? "")
        _photoChoices = State(initialValue: recipe.photoChoices)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: AppSpacing.lg) {
                        coverCard
                        cutoutCard
                        if photoChoices.count > 1 {
                            galleryCard
                        }
                        Color.clear.frame(height: 80)
                    }
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.top, AppSpacing.md)
                }
                .background(Color.appBackground.ignoresSafeArea())

                if isProcessing {
                    Color.black.opacity(0.26).ignoresSafeArea()
                    VStack(spacing: 10) {
                        ProgressView().tint(.white)
                        Text(processingText)
                            .font(AppFont.caption(13))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 22)
                    .padding(.vertical, 16)
                    .background(Color.actionInk.opacity(0.92), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
            .safeAreaInset(edge: .bottom) {
                bottomBar
            }
            .navigationTitle("主图与抠图 · \(recipe.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                    .foregroundStyle(Color.inkSecondary)
                    .disabled(isProcessing || isSaving)
                }
            }
            .task {
                if let latest = try? await RecipeService.shared.detail(id: recipe.id) {
                    photoChoices = latest.photoChoices
                }
            }
            .onChange(of: coverPickerItem) { _, item in
                guard let item else { return }
                Task { await handlePickedCover(item) }
            }
            .onChange(of: customCutoutPickerItem) { _, item in
                guard let item else { return }
                Task { await handlePickedCustomCutout(item) }
            }
            .fullScreenCover(item: $activeModal) { modal in
                switch modal {
                case .camera:
                    CameraCaptureView(mode: .dish) { photo in
                        try await handleCapturedPhoto(photo)
                    }
                    .ignoresSafeArea()
                case .cropCover(let img):
                    ImageCropRotateSheet(initialImage: img, title: "裁剪菜谱主图", preservesAlpha: false) { cropped in
                        Task { await uploadCroppedCover(cropped) }
                    }
                case .cropCutout(let img):
                    ImageCropRotateSheet(initialImage: img, title: "裁剪画布贴图", preservesAlpha: true) { cropped in
                        Task { await uploadCroppedCutout(cropped) }
                    }
                case .maskEditor:
                    CutoutMaskEditorSheet(
                        sourceImageURL: coverImage.isEmpty ? nil : coverImage,
                        initialCutoutURL: cutoutImage.isEmpty ? nil : cutoutImage
                    ) { pngData in
                        let uploaded = try await UploadService.shared.uploadImage(pngData, filename: "cutout.png", mime: "image/png")
                        await MainActor.run {
                            cutoutImage = uploaded.path
                        }
                    }
                case .preview(let presentation):
                    PhotoGalleryViewer(slides: presentation.slides, initialIndex: presentation.initialIndex)
                }
            }
            .toast($errorMessage)
        }
        .interactiveDismissDisabled(isProcessing || isSaving)
        .preferredColorScheme(.light)
    }

    private var coverCard: some View {
        SectionCard {
            HStack {
                FieldLabel("菜谱主图")
                Spacer()
                if !coverImage.isEmpty {
                    Button {
                        coverImage = ""
                        cutoutImage = ""
                    } label: {
                        Text("清除")
                            .font(AppFont.caption(12))
                            .foregroundStyle(Color.errorInk)
                    }
                }
            }
            Text("用于菜谱列表卡片和详情页顶部大图，可自由裁剪旋转。")
                .font(AppFont.caption(12))
                .foregroundStyle(Color.inkMuted)

            if !coverImage.isEmpty {
                Button {
                    Haptics.light()
                    activeModal = .preview(PhotoGalleryPresentation(urls: [coverImage], caption: "菜谱主图"))
                } label: {
                    AsyncImageView(url: coverImage, name: recipe.name)
                        .frame(maxWidth: .infinity)
                        .frame(height: 190)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
            } else {
                PhotosPicker(selection: $coverPickerItem, matching: .images) {
                    VStack(spacing: 8) {
                        Image(systemName: "photo.badge.plus")
                            .font(.system(size: 26, weight: .light))
                            .foregroundStyle(Color.brandGreen)
                        Text("选择或拍摄菜谱主图")
                            .font(AppFont.body(14))
                            .foregroundStyle(Color.inkSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 150)
                    .background(Color.appBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Color.dividerLine, style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
                    }
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 8) {
                PhotosPicker(selection: $coverPickerItem, matching: .images) {
                    studioChipLabel(title: coverImage.isEmpty ? "相册选图" : "换主图", icon: "photo.on.rectangle")
                }
                .buttonStyle(SoftPressStyle())

                Button {
                    activeModal = .camera
                } label: {
                    studioChipLabel(title: "拍照", icon: "camera")
                }
                .buttonStyle(SoftPressStyle())

                if !coverImage.isEmpty {
                    Button {
                        Task { await openCoverCropper() }
                    } label: {
                        studioChipLabel(title: "裁剪/旋转", icon: "crop.rotate")
                    }
                    .buttonStyle(SoftPressStyle())
                }
            }
        }
    }

    private var cutoutCard: some View {
        SectionCard {
            HStack {
                FieldLabel("画布透明贴图（抠图）")
                Spacer()
                if !cutoutImage.isEmpty {
                    Button {
                        cutoutImage = ""
                    } label: {
                        Text("清除贴图")
                            .font(AppFont.caption(12))
                            .foregroundStyle(Color.errorInk)
                    }
                }
            }
            Text("加菜到「这一顿」自由画布时展示的透明菜品贴图，支持手动涂抹擦除/恢复或单独上传自定义贴图。")
                .font(AppFont.caption(12))
                .foregroundStyle(Color.inkMuted)

            if !cutoutImage.isEmpty {
                Button {
                    Haptics.light()
                    activeModal = .preview(
                        PhotoGalleryPresentation(urls: [cutoutImage], caption: "画布透明贴图", isTransparent: true)
                    )
                } label: {
                    ZStack {
                        TransparencyCheckerboard(cellSize: 12)
                        AsyncImageView(url: cutoutImage, name: "抠图贴图", fitContent: true)
                            .padding(12)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 165)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Color.dividerLine.opacity(0.8), lineWidth: 0.8)
                    }
                }
                .buttonStyle(.plain)
            } else {
                VStack(spacing: 6) {
                    Image(systemName: "sparkles.rectangle.stack")
                        .font(.system(size: 24, weight: .light))
                        .foregroundStyle(Color.inkMuted)
                    Text("当前没有透明贴图，画布将直接使用原图展示")
                        .font(AppFont.caption(12.5))
                        .foregroundStyle(Color.inkMuted)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 112)
                .background(Color.appBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            FlowLayout(spacing: 8) {
                if !cutoutImage.isEmpty || !coverImage.isEmpty {
                    Button {
                        Haptics.light()
                        activeModal = .maskEditor
                    } label: {
                        studioChipLabel(
                            title: cutoutImage.isEmpty ? "手动抠图精修" : "涂抹擦除/恢复",
                            icon: "paintbrush.pointed",
                            prominent: true
                        )
                    }
                    .buttonStyle(SoftPressStyle())
                }

                if !coverImage.isEmpty {
                    Button {
                        Task { await regenerateCutoutFromCover() }
                    } label: {
                        studioChipLabel(title: "从主图重抠", icon: "wand.and.stars")
                    }
                    .buttonStyle(SoftPressStyle())
                }

                PhotosPicker(selection: $customCutoutPickerItem, matching: .images) {
                    studioChipLabel(title: "单独传贴图", icon: "square.and.arrow.up")
                }
                .buttonStyle(SoftPressStyle())

                if !cutoutImage.isEmpty {
                    Button {
                        Task { await openCutoutCropper() }
                    } label: {
                        studioChipLabel(title: "裁剪贴图", icon: "crop")
                    }
                    .buttonStyle(SoftPressStyle())
                }
            }
        }
    }

    private var galleryCard: some View {
        SectionCard {
            FieldLabel("从往期实拍图库切换")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(photoChoices) { choice in
                        let selected = choice.image == coverImage
                        Button {
                            Haptics.light()
                            coverImage = choice.image
                            cutoutImage = choice.cutoutImage ?? ""
                        } label: {
                            AsyncImageView(url: choice.image, name: recipe.name)
                                .frame(width: 76, height: 76)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .strokeBorder(selected ? Color.actionInk : Color.dividerLine, lineWidth: selected ? 2.5 : 0.7)
                                }
                                .overlay(alignment: .topTrailing) {
                                    if selected {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundStyle(Color.actionInk)
                                            .background(Color.white, in: Circle())
                                            .padding(4)
                                    }
                                }
                        }
                        .buttonStyle(SoftPressStyle())
                    }
                }
            }
        }
    }

    private var bottomBar: some View {
        PrimaryButton(title: "保存主图与贴图", isLoading: isSaving) {
            Task { await saveChanges() }
        }
        .disabled(isProcessing)
        .padding(.horizontal, AppSpacing.lg)
        .padding(.vertical, AppSpacing.sm)
        .background(Color.appBackground)
        .overlay(alignment: .top) {
            Divider().overlay(Color.dividerLine.opacity(0.6))
        }
    }

    private func studioChipLabel(title: String, icon: String, prominent: Bool = false) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
            Text(title)
                .font(.system(size: 12.5, weight: .semibold, design: .rounded))
        }
        .foregroundStyle(prominent ? .white : Color.inkPrimary)
        .padding(.horizontal, 12)
        .frame(height: 34)
        .background(prominent ? Color.actionInk : Color.appBackground, in: Capsule())
        .overlay {
            if !prominent {
                Capsule().strokeBorder(Color.dividerLine.opacity(0.85), lineWidth: 0.7)
            }
        }
    }

    // MARK: - Actions

    @MainActor
    private func handlePickedCover(_ item: PhotosPickerItem) async {
        coverPickerItem = nil
        guard !isProcessing else { return }
        isProcessing = true
        processingText = "正在上传主图并生成贴图"
        defer { isProcessing = false }

        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let img = UIImage(data: data),
                  let jpeg = RecipeImageEditHelpers.compressedJPEG(img) else {
                errorMessage = "无法读取所选图片"
                return
            }
            let uploaded = try await UploadService.shared.uploadImage(jpeg, filename: "cover.jpg", mime: "image/jpeg")
            coverImage = uploaded.path
            cutoutImage = ""
            if let png = try? await ImageCutoutService.shared.makePNG(from: img),
               let uploadedCutout = try? await UploadService.shared.uploadImage(png, filename: "cutout.png", mime: "image/png") {
                cutoutImage = uploadedCutout.path
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func handleCapturedPhoto(_ photo: CameraPhoto) async throws {
        guard let jpeg = RecipeImageEditHelpers.compressedJPEG(photo.image) else {
            throw CocoaError(.fileWriteUnknown)
        }
        isProcessing = true
        processingText = "正在保存拍摄照片"
        defer { isProcessing = false }

        let uploaded = try await UploadService.shared.uploadImage(jpeg, filename: "cover.jpg", mime: "image/jpeg")
        coverImage = uploaded.path
        cutoutImage = ""
        if let png = photo.cutoutData {
            let uploadedCutout = try await UploadService.shared.uploadImage(png, filename: "cutout.png", mime: "image/png")
            cutoutImage = uploadedCutout.path
        }
    }

    @MainActor
    private func handlePickedCustomCutout(_ item: PhotosPickerItem) async {
        customCutoutPickerItem = nil
        guard !isProcessing else { return }
        isProcessing = true
        processingText = "正在处理自定义贴图"
        defer { isProcessing = false }

        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let img = UIImage(data: data) else {
                errorMessage = "无法读取贴图文件"
                return
            }
            let pngData: Data
            if RecipeImageEditHelpers.hasSignificantTransparency(img),
               let trimmed = RecipeImageEditHelpers.trimTransparentPixels(img, padding: 6),
               let rawPNG = trimmed.pngData() {
                pngData = rawPNG
            } else if let extracted = try? await ImageCutoutService.shared.makePNG(from: img) {
                pngData = extracted
            } else if let fallbackPNG = RecipeImageEditHelpers.normalizedUpImage(img, maxSide: 1200, opaque: false).pngData() {
                pngData = fallbackPNG
                errorMessage = "未识别到分离背景，已导入原图，可点「涂抹擦除/恢复」手动擦掉背景"
            } else {
                errorMessage = "贴图编码失败"
                return
            }
            let uploaded = try await UploadService.shared.uploadImage(pngData, filename: "custom_cutout.png", mime: "image/png")
            cutoutImage = uploaded.path
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func openCoverCropper() async {
        guard !isProcessing, !coverImage.isEmpty else { return }
        isProcessing = true
        processingText = "正在读取主图"
        defer { isProcessing = false }
        guard let img = await RecipeImageEditHelpers.loadUIImage(from: coverImage) else {
            errorMessage = "无法加载主图，请重试"
            return
        }
        activeModal = .cropCover(img)
    }

    @MainActor
    private func openCutoutCropper() async {
        guard !isProcessing, !cutoutImage.isEmpty else { return }
        isProcessing = true
        processingText = "正在读取贴图"
        defer { isProcessing = false }
        guard let img = await RecipeImageEditHelpers.loadUIImage(from: cutoutImage) else {
            errorMessage = "无法加载贴图，请重试"
            return
        }
        activeModal = .cropCutout(img)
    }

    @MainActor
    private func uploadCroppedCover(_ cropped: UIImage) async {
        guard let jpeg = RecipeImageEditHelpers.compressedJPEG(cropped) else { return }
        isProcessing = true
        processingText = "正在保存裁剪后的主图"
        defer { isProcessing = false }
        do {
            let uploaded = try await UploadService.shared.uploadImage(jpeg, filename: "cover_crop.jpg", mime: "image/jpeg")
            coverImage = uploaded.path
            // 仅在当前尚无贴图时自动生成，避免覆盖用户已精修或单独上传的自定义贴图
            if cutoutImage.isEmpty,
               let png = try? await ImageCutoutService.shared.makePNG(from: cropped),
               let uploadedCutout = try? await UploadService.shared.uploadImage(png, filename: "cutout.png", mime: "image/png") {
                cutoutImage = uploadedCutout.path
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func uploadCroppedCutout(_ cropped: UIImage) async {
        let finalImg = RecipeImageEditHelpers.trimTransparentPixels(cropped, padding: 6) ?? cropped
        guard let png = finalImg.pngData() else { return }
        isProcessing = true
        processingText = "正在保存裁剪后的贴图"
        defer { isProcessing = false }
        do {
            let uploaded = try await UploadService.shared.uploadImage(png, filename: "cutout_crop.png", mime: "image/png")
            cutoutImage = uploaded.path
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func regenerateCutoutFromCover() async {
        guard !isProcessing, !coverImage.isEmpty else { return }
        isProcessing = true
        processingText = "正在从主图重新抠图"
        defer { isProcessing = false }
        guard let img = await RecipeImageEditHelpers.loadUIImage(from: coverImage) else {
            errorMessage = "主图读取失败"
            return
        }
        do {
            let png = try await ImageCutoutService.shared.makePNG(from: img)
            let uploaded = try await UploadService.shared.uploadImage(png, filename: "cutout.png", mime: "image/png")
            cutoutImage = uploaded.path
            Haptics.light()
        } catch {
            errorMessage = "\(error.localizedDescription)，可点「手动抠图精修」涂抹提取"
        }
    }

    @MainActor
    private func saveChanges() async {
        guard !isSaving, !isProcessing else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            let updated = try await RecipeService.shared.setCover(
                id: recipe.id,
                image: coverImage,
                cutoutImage: cutoutImage,
                allowClear: true
            )
            AppNotifications.mealChanged()
            Haptics.success()
            onSaved(updated)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
