import AVFoundation
import CoreImage
import CoreMedia
import CryptoKit
import ImageIO
import Photos
import UIKit
import UniformTypeIdentifiers
import Vision

struct ImageCutout {
    let source: UIImage
    let foreground: UIImage
    let cropped: UIImage
    let pngData: Data
}

// 两处拍照入口及画布自动抠图共用系统主体分割，输出保留透明通道的 PNG。
actor ImageCutoutService {
    static let shared = ImageCutoutService()
    private let context = CIContext()

    func makePNG(from image: UIImage) throws -> Data {
        try makeCutout(from: image).pngData
    }

    func makeCutout(from image: UIImage) throws -> ImageCutout {
        try Task.checkCancellation()
        let maxSide: CGFloat = 1600
        let scale = min(1, maxSide / max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        guard size.width > 0, size.height > 0 else { throw CutoutError.invalidImage }

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let normalized = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        guard let source = normalized.cgImage else { throw CutoutError.invalidImage }

        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: source)
        try handler.perform([request])
        try Task.checkCancellation()
        guard let observation = request.results?.first, !observation.allInstances.isEmpty else {
            throw CutoutError.noSubject
        }
        let foregroundBuffer = try observation.generateMaskedImage(
            ofInstances: observation.allInstances,
            from: handler,
            croppedToInstancesExtent: false
        )
        let croppedBuffer = try observation.generateMaskedImage(
            ofInstances: observation.allInstances,
            from: handler,
            croppedToInstancesExtent: true
        )
        let foreground = CIImage(cvPixelBuffer: foregroundBuffer)
        let cropped = CIImage(cvPixelBuffer: croppedBuffer)
        guard let fullImage = context.createCGImage(foreground, from: foreground.extent),
              let croppedImage = context.createCGImage(cropped, from: cropped.extent),
              let data = UIImage(cgImage: croppedImage).pngData() else {
            throw CutoutError.encodingFailed
        }
        return ImageCutout(
            source: normalized, foreground: UIImage(cgImage: fullImage),
            cropped: UIImage(cgImage: croppedImage), pngData: data
        )
    }
}

/// 画布自动抠图共享缓存（L1 内存 + L2 磁盘 PNG），避免重复分割同一菜品图。
@MainActor
final class DishCutoutCache {
    static let shared = DishCutoutCache()

    private let memory = NSCache<NSURL, UIImage>()
    private var inFlight: [URL: Task<UIImage?, Never>] = [:]
    private let diskDirectory: URL?

    private init() {
        memory.countLimit = 80
        if let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first {
            let dir = caches.appendingPathComponent("DishCutouts", isDirectory: true)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            diskDirectory = dir
        } else {
            diskDirectory = nil
        }
    }

    func cachedCutout(for url: URL) -> UIImage? {
        if let hit = memory.object(forKey: url as NSURL) {
            return hit
        }
        guard let file = diskFileURL(for: url),
              let data = try? Data(contentsOf: file),
              let image = UIImage(data: data) else {
            return nil
        }
        memory.setObject(image, forKey: url as NSURL)
        return image
    }

    func cutout(for url: URL, sourceImage: UIImage) async -> UIImage? {
        if let cached = cachedCutout(for: url) {
            return cached
        }
        if let running = inFlight[url] {
            return await running.value
        }
        let diskURL = diskFileURL(for: url)
        let task = Task<UIImage?, Never> { [weak self] in
            defer {
                self?.inFlight[url] = nil
            }
            do {
                let result = try await ImageCutoutService.shared.makeCutout(from: sourceImage)
                if let diskURL {
                    try? result.pngData.write(to: diskURL, options: .atomic)
                }
                self?.memory.setObject(result.cropped, forKey: url as NSURL)
                return result.cropped
            } catch {
                #if DEBUG
                print("[Cutout] failed for \(url.lastPathComponent): \(error.localizedDescription)")
                #endif
                return nil
            }
        }
        inFlight[url] = task
        return await task.value
    }

    private func diskFileURL(for url: URL) -> URL? {
        guard let diskDirectory else { return nil }
        let digest = SHA256.hash(data: Data(url.absoluteString.utf8))
        let name = digest.map { String(format: "%02x", $0) }.joined() + ".png"
        return diskDirectory.appendingPathComponent(name)
    }
}

private enum CutoutError: LocalizedError {
    case invalidImage
    case noSubject
    case encodingFailed

    var errorDescription: String? {
        switch self {
        case .invalidImage: return "无法读取照片，请重新选择"
        case .noSubject: return "没有识别到清晰主体，请让物体占据画面中心后重拍"
        case .encodingFailed: return "无法生成透明图，请重试"
        }
    }
}

/// 沿着透明前景实际边缘生成 Crisp 白边模切或半透晶透贴纸效果并缓存。
actor StickerBorderRenderer {
    static let shared = StickerBorderRenderer()

    private let context = CIContext()
    private nonisolated(unsafe) let cache = NSCache<NSString, UIImage>()

    init() {
        cache.countLimit = 80
    }

    nonisolated func cached(forKey key: String) -> UIImage? {
        cache.object(forKey: key as NSString)
    }

    nonisolated func cachedCrystal(forKey key: String) -> UIImage? {
        cache.object(forKey: "\(key)#crystal" as NSString)
    }

    private func alphaMask(from ciBase: CIImage, extent: CGRect, radius: CGFloat) -> CIImage {
        let dilated = ciBase
            .applyingFilter("CIMorphologyMaximum", parameters: [kCIInputRadiusKey: radius])
            .cropped(to: extent)
        let smoothed = dilated
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 1.3])
            .cropped(to: extent)
        return smoothed.applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": CIVector(x: 0, y: 0, z: 0, w: 0),
            "inputGVector": CIVector(x: 0, y: 0, z: 0, w: 0),
            "inputBVector": CIVector(x: 0, y: 0, z: 0, w: 0),
            "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 2.4),
            "inputBiasVector": CIVector(x: 0, y: 0, z: 0, w: -0.35)
        ]).applyingFilter("CIColorClamp", parameters: [
            "inputMinComponents": CIVector(x: 0, y: 0, z: 0, w: 0),
            "inputMaxComponents": CIVector(x: 1, y: 1, z: 1, w: 1)
        ])
    }

    func makeDieCutSticker(from image: UIImage, cacheKey: String) -> UIImage {
        if let hit = cached(forKey: cacheKey) {
            return hit
        }
        guard image.size.width > 0, image.size.height > 0 else { return image }

        let maxSide: CGFloat = 900
        let ratio = min(1, maxSide / max(image.size.width, image.size.height))
        let sw = max(1, (image.size.width * ratio).rounded())
        let sh = max(1, (image.size.height * ratio).rounded())
        let strokePx = max(12, min(26, (min(sw, sh) * 0.032).rounded()))
        let pad = strokePx + 6
        let paddedSize = CGSize(width: sw + pad * 2, height: sh + pad * 2)

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let padded = UIGraphicsImageRenderer(size: paddedSize, format: format).image { _ in
            image.draw(in: CGRect(x: pad, y: pad, width: sw, height: sh))
        }
        guard let ciBase = CIImage(image: padded) else { return image }
        let extent = ciBase.extent

        let crispAlpha = alphaMask(from: ciBase, extent: extent, radius: strokePx)
        // 将 alpha 映射为合法的 premultiplied white (R=A, G=A, B=A, A=A)，绝不能把 RGB bias 设为 1
        let whiteRim = crispAlpha.applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": CIVector(x: 0, y: 0, z: 0, w: 1),
            "inputGVector": CIVector(x: 0, y: 0, z: 0, w: 1),
            "inputBVector": CIVector(x: 0, y: 0, z: 0, w: 1),
            "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 1),
            "inputBiasVector": CIVector(x: 0, y: 0, z: 0, w: 0)
        ])
        let composed = ciBase.composited(over: whiteRim).cropped(to: extent)
        guard let cgImage = context.createCGImage(composed, from: extent) else { return image }
        let rendered = UIImage(cgImage: cgImage, scale: 1, orientation: .up)
        cache.setObject(rendered, forKey: cacheKey as NSString)
        return rendered
    }

    /// 沿透明前景生成半透磨砂亚克力光边 + 细锐高光轮廓 + 对角晶面高光（完全透明底）。
    func makeCrystalSticker(from image: UIImage, cacheKey: String) -> UIImage {
        if let hit = cachedCrystal(forKey: cacheKey) {
            return hit
        }
        guard image.size.width > 0, image.size.height > 0 else { return image }

        let maxSide: CGFloat = 900
        let ratio = min(1, maxSide / max(image.size.width, image.size.height))
        let sw = max(1, (image.size.width * ratio).rounded())
        let sh = max(1, (image.size.height * ratio).rounded())
        let strokePx = max(14, min(28, (min(sw, sh) * 0.036).rounded()))
        let pad = strokePx + 8
        let paddedSize = CGSize(width: sw + pad * 2, height: sh + pad * 2)

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let padded = UIGraphicsImageRenderer(size: paddedSize, format: format).image { _ in
            image.draw(in: CGRect(x: pad, y: pad, width: sw, height: sh))
        }
        guard let ciBase = CIImage(image: padded) else { return image }
        let extent = ciBase.extent

        let outerMask = alphaMask(from: ciBase, extent: extent, radius: strokePx)
        let innerMask = alphaMask(from: ciBase, extent: extent, radius: max(strokePx - 3, 2))
        let invertedInner = innerMask.applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": CIVector(x: 0, y: 0, z: 0, w: 0),
            "inputGVector": CIVector(x: 0, y: 0, z: 0, w: 0),
            "inputBVector": CIVector(x: 0, y: 0, z: 0, w: 0),
            "inputAVector": CIVector(x: 0, y: 0, z: 0, w: -1),
            "inputBiasVector": CIVector(x: 0, y: 0, z: 0, w: 1)
        ]).applyingFilter("CIColorClamp", parameters: [
            "inputMinComponents": CIVector(x: 0, y: 0, z: 0, w: 0),
            "inputMaxComponents": CIVector(x: 1, y: 1, z: 1, w: 1)
        ])
        let rimMask = outerMask.applyingFilter("CISourceInCompositing", parameters: [
            kCIInputBackgroundImageKey: invertedInner
        ]).cropped(to: extent)

        // 严格 premultiplied RGBA：RGB <= A，bias = 0
        let haloAlpha: CGFloat = 0.34
        let frostedHalo = outerMask.applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": CIVector(x: 0, y: 0, z: 0, w: 0.94 * haloAlpha),
            "inputGVector": CIVector(x: 0, y: 0, z: 0, w: 0.97 * haloAlpha),
            "inputBVector": CIVector(x: 0, y: 0, z: 0, w: 1.00 * haloAlpha),
            "inputAVector": CIVector(x: 0, y: 0, z: 0, w: haloAlpha),
            "inputBiasVector": CIVector(x: 0, y: 0, z: 0, w: 0)
        ])

        let rimAlpha: CGFloat = 0.84
        let rimBand = rimMask.applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": CIVector(x: 0, y: 0, z: 0, w: 0.96 * rimAlpha),
            "inputGVector": CIVector(x: 0, y: 0, z: 0, w: 0.99 * rimAlpha),
            "inputBVector": CIVector(x: 0, y: 0, z: 0, w: 1.00 * rimAlpha),
            "inputAVector": CIVector(x: 0, y: 0, z: 0, w: rimAlpha),
            "inputBiasVector": CIVector(x: 0, y: 0, z: 0, w: 0)
        ])

        let composed = ciBase.composited(over: rimBand.composited(over: frostedHalo)).cropped(to: extent)
        guard let composedCG = context.createCGImage(composed, from: extent) else { return image }

        let rendered = UIGraphicsImageRenderer(size: paddedSize, format: format).image { ctx in
            let baseImage = UIImage(cgImage: composedCG, scale: 1, orientation: .up)
            baseImage.draw(in: CGRect(origin: .zero, size: paddedSize))

            let cg = ctx.cgContext
            cg.saveGState()
            cg.setBlendMode(.sourceAtop)
            let colors = [
                UIColor.white.withAlphaComponent(0.0).cgColor,
                UIColor.white.withAlphaComponent(0.22).cgColor,
                UIColor.white.withAlphaComponent(0.05).cgColor,
                UIColor.white.withAlphaComponent(0.0).cgColor
            ] as CFArray
            let locations: [CGFloat] = [0.0, 0.36, 0.56, 1.0]
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: locations) {
                cg.drawLinearGradient(
                    gradient,
                    start: CGPoint(x: 0, y: 0),
                    end: CGPoint(x: paddedSize.width, y: paddedSize.height),
                    options: []
                )
            }
            cg.restoreGState()
        }

        cache.setObject(rendered, forKey: "\(cacheKey)#crystal" as NSString)
        return rendered
    }
}

/// 将动态画布渲染为配对的 Apple Live Photo（JPEG + QuickTime MOV），写入系统相册。
enum LivePhotoExporter {
    enum ExportError: LocalizedError {
        case permissionDenied
        case writerSetupFailed
        case frameRenderFailed
        case saveFailed(String)

        var errorDescription: String? {
            switch self {
            case .permissionDenied: return "请在设置中允许添加照片后再保存实况照片"
            case .writerSetupFailed: return "实况照片编码器初始化失败，请重试"
            case .frameRenderFailed: return "实况画面生成失败，请重试"
            case .saveFailed(let message): return message.isEmpty ? "实况照片保存失败，请重试" : message
            }
        }
    }

    static func exportAndSave(
        pixelSize: CGSize,
        frameCount: Int = 72,
        fps: Int32 = 24,
        keyframeIndex: Int = 12,
        onProgress: @escaping @MainActor (Double) -> Void,
        renderFrame: @escaping @MainActor (Int) -> CGImage?
    ) async throws {
        let authorization = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard authorization == .authorized || authorization == .limited else {
            throw ExportError.permissionDenied
        }

        let width = max(2, Int(pixelSize.width.rounded()) & ~1)
        let height = max(2, Int(pixelSize.height.rounded()) & ~1)
        let safeCount = max(2, frameCount)
        let safeKeyframe = min(max(0, keyframeIndex), safeCount - 1)
        let assetID = UUID().uuidString

        let tempDir = FileManager.default.temporaryDirectory
        let stillURL = tempDir.appendingPathComponent("live_still_\(assetID).jpg")
        let movURL = tempDir.appendingPathComponent("live_video_\(assetID).mov")
        defer {
            try? FileManager.default.removeItem(at: stillURL)
            try? FileManager.default.removeItem(at: movURL)
        }

        let writer = try AVAssetWriter(outputURL: movURL, fileType: .mov)
        let idMetadata = AVMutableMetadataItem()
        idMetadata.key = "com.apple.quicktime.content.identifier" as NSString
        idMetadata.keySpace = .quickTimeMetadata
        idMetadata.value = assetID as NSString
        idMetadata.dataType = kCMMetadataBaseDataType_UTF8 as String
        writer.metadata = [idMetadata]

        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: 6_000_000,
                AVVideoExpectedSourceFrameRateKey: Int(fps)
            ]
        ]
        let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        videoInput.expectsMediaDataInRealTime = false
        guard writer.canAdd(videoInput) else { throw ExportError.writerSetupFailed }
        writer.add(videoInput)

        let bufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
        ]
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: videoInput,
            sourcePixelBufferAttributes: bufferAttributes
        )

        let metadataSpec: [CFString: Any] = [
            kCMMetadataFormatDescriptionMetadataSpecificationKey_Identifier: "mdta/com.apple.quicktime.still-image-time",
            kCMMetadataFormatDescriptionMetadataSpecificationKey_DataType: kCMMetadataBaseDataType_SInt8
        ]
        var metadataDesc: CMFormatDescription?
        let descStatus = CMMetadataFormatDescriptionCreateWithMetadataSpecifications(
            allocator: kCFAllocatorDefault,
            metadataType: kCMMetadataFormatType_Boxed,
            metadataSpecifications: [metadataSpec] as CFArray,
            formatDescriptionOut: &metadataDesc
        )
        guard descStatus == noErr, let metadataDesc else {
            throw ExportError.writerSetupFailed
        }

        let metadataInput = AVAssetWriterInput(mediaType: .metadata, outputSettings: nil, sourceFormatHint: metadataDesc)
        metadataInput.expectsMediaDataInRealTime = false
        guard writer.canAdd(metadataInput) else { throw ExportError.writerSetupFailed }
        writer.add(metadataInput)
        let metadataAdaptor = AVAssetWriterInputMetadataAdaptor(assetWriterInput: metadataInput)

        guard writer.startWriting() else { throw ExportError.writerSetupFailed }
        writer.startSession(atSourceTime: .zero)

        let stillTimeItem = AVMutableMetadataItem()
        stillTimeItem.key = "com.apple.quicktime.still-image-time" as NSString
        stillTimeItem.keySpace = .quickTimeMetadata
        stillTimeItem.value = 0 as NSNumber
        stillTimeItem.dataType = kCMMetadataBaseDataType_SInt8 as String
        let timedGroup = AVTimedMetadataGroup(
            items: [stillTimeItem],
            timeRange: CMTimeRange(start: CMTime(value: Int64(safeKeyframe), timescale: fps), duration: CMTime(value: 1, timescale: fps))
        )
        if metadataInput.isReadyForMoreMediaData {
            metadataAdaptor.append(timedGroup)
        }
        metadataInput.markAsFinished()

        var heroCGImage: CGImage?
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue

        for index in 0..<safeCount {
            try Task.checkCancellation()
            guard let frameCG = await renderFrame(index) else {
                writer.cancelWriting()
                throw ExportError.frameRenderFailed
            }
            if index == safeKeyframe || (heroCGImage == nil && index == 0) {
                heroCGImage = frameCG
            }
            while !videoInput.isReadyForMoreMediaData {
                try Task.checkCancellation()
                try await Task.sleep(for: .milliseconds(4))
            }
            guard let pool = adaptor.pixelBufferPool else {
                writer.cancelWriting()
                throw ExportError.writerSetupFailed
            }
            var maybeBuffer: CVPixelBuffer?
            let poolStatus = CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &maybeBuffer)
            guard poolStatus == kCVReturnSuccess, let pixelBuffer = maybeBuffer else {
                writer.cancelWriting()
                throw ExportError.writerSetupFailed
            }
            CVPixelBufferLockBaseAddress(pixelBuffer, [])
            if let base = CVPixelBufferGetBaseAddress(pixelBuffer),
               let cgContext = CGContext(
                   data: base,
                   width: width,
                   height: height,
                   bitsPerComponent: 8,
                   bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
                   space: colorSpace,
                   bitmapInfo: bitmapInfo
               ) {
                cgContext.clear(CGRect(x: 0, y: 0, width: width, height: height))
                cgContext.draw(frameCG, in: CGRect(x: 0, y: 0, width: width, height: height))
            }
            CVPixelBufferUnlockBaseAddress(pixelBuffer, [])
            let pts = CMTime(value: Int64(index), timescale: fps)
            if !adaptor.append(pixelBuffer, withPresentationTime: pts) {
                writer.cancelWriting()
                throw ExportError.frameRenderFailed
            }
            await onProgress(Double(index + 1) / Double(safeCount))
        }

        videoInput.markAsFinished()
        await writer.finishWriting()
        guard writer.status == .completed, let heroCGImage else {
            throw ExportError.saveFailed(writer.error?.localizedDescription ?? "")
        }

        guard let destination = CGImageDestinationCreateWithURL(
            stillURL as CFURL,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else {
            throw ExportError.saveFailed("无法生成实况封面图")
        }
        let imageProperties: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: 0.92,
            kCGImagePropertyMakerAppleDictionary: ["17": assetID]
        ]
        CGImageDestinationAddImage(destination, heroCGImage, imageProperties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            throw ExportError.saveFailed("无法写入实况封面图")
        }

        try await PHPhotoLibrary.shared().performChanges {
            let request = PHAssetCreationRequest.forAsset()
            let photoOptions = PHAssetResourceCreationOptions()
            photoOptions.shouldMoveFile = false
            let videoOptions = PHAssetResourceCreationOptions()
            videoOptions.shouldMoveFile = false
            request.addResource(with: .photo, fileURL: stillURL, options: photoOptions)
            request.addResource(with: .pairedVideo, fileURL: movURL, options: videoOptions)
        }
    }
}
