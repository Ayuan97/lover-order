import UIKit
import Vision
import CoreImage

struct ImageCutout {
    let source: UIImage
    let foreground: UIImage
    let cropped: UIImage
    let pngData: Data
}

// 两处拍照入口共用系统主体分割，输出保留透明通道的 PNG。
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
