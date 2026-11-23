import SwiftUI
import CoreImage.CIFilterBuiltins

// 进家餐券 vs 蹭饭房间：QR 只认 lo:// 前缀，不认裸串（无兼容旧码）
enum LoverScanLink {
    static let homePrefix = "lo://home/"
    static let roomPrefix = "lo://room/"

    static func homePayload(_ code: String) -> String {
        homePrefix + code.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func roomPayload(_ code: String) -> String {
        roomPrefix + code.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    enum Kind: Equatable {
        case home(String)
        case room(String)
    }

    // 仅解析带前缀的扫描结果；裸码返回 nil（手输邀请码/房间号走各自文本框，不经此）
    static func parse(_ raw: String) -> Kind? {
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = s.lowercased()
        if lower.hasPrefix(homePrefix) {
            let code = String(s.dropFirst(homePrefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !code.isEmpty else { return nil }
            return .home(code)
        }
        if lower.hasPrefix(roomPrefix) {
            let code = String(s.dropFirst(roomPrefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !code.isEmpty else { return nil }
            return .room(code)
        }
        return nil
    }
}

// 定制二维码 曜石黑码点 + 透明底 + 中心徽标（入伙心形 / 聚餐餐具）
struct BrandQRCode: View {
    enum BadgeStyle {
        case heart
        case dining

        var systemImage: String {
            switch self {
            case .heart: return "heart.fill"
            case .dining: return "fork.knife"
            }
        }
    }

    let content: String
    var size: CGFloat = 200
    var badge: BadgeStyle = .heart
    var dotColor: CIColor = CIColor(red: 0.078, green: 0.078, blue: 0.086)

    var body: some View {
        ZStack {
            if let img = Self.render(content, dotColor: dotColor) {
                Image(uiImage: img)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: size, height: size)
            } else {
                RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                    .fill(Color.appBackground)
                    .frame(width: size, height: size)
            }
            // 中心白底圆徽标压住中央码点 高容错下不影响扫描
            ZStack {
                Circle()
                    .fill(Color.white)
                    .frame(width: size * 0.24, height: size * 0.24)
                    .overlay {
                        Circle()
                            .strokeBorder(Color.black.opacity(0.08), lineWidth: 0.8)
                    }
                Image(systemName: badge.systemImage)
                    .font(.system(size: size * 0.115, weight: .semibold))
                    .foregroundStyle(Color.actionInk)
            }
        }
    }

    private static func render(_ string: String, dotColor: CIColor) -> UIImage? {
        let ctx = CIContext()
        let qr = CIFilter.qrCodeGenerator()
        qr.message = Data(string.utf8)
        qr.correctionLevel = "H"
        guard let base = qr.outputImage else { return nil }
        let scaled = base.transformed(by: CGAffineTransform(scaleX: 12, y: 12))

        let color = CIFilter.falseColor()
        color.inputImage = scaled
        color.color0 = dotColor
        color.color1 = CIColor(red: 0, green: 0, blue: 0, alpha: 0)   // 透明底
        guard let out = color.outputImage,
              let cg = ctx.createCGImage(out, from: out.extent) else { return nil }
        return UIImage(cgImage: cg)
    }
}
