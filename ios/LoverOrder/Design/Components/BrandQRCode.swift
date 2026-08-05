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

// 定制二维码 墨绿码点 + 透明底 + 中心心形 不做成白底黑码
struct BrandQRCode: View {
    let content: String
    var size: CGFloat = 200

    var body: some View {
        ZStack {
            if let img = Self.render(content) {
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
            // 中心心形 米底圆压住中央码点 高容错下不影响扫描
            ZStack {
                Circle()
                    .fill(Color.cardBackground)
                    .frame(width: size * 0.24, height: size * 0.24)
                Image(systemName: "heart.fill")
                    .font(.system(size: size * 0.12))
                    .foregroundStyle(Color.brandGreen)
            }
        }
    }

    private static func render(_ string: String) -> UIImage? {
        let ctx = CIContext()
        let qr = CIFilter.qrCodeGenerator()
        qr.message = Data(string.utf8)
        qr.correctionLevel = "H"
        guard let base = qr.outputImage else { return nil }
        let scaled = base.transformed(by: CGAffineTransform(scaleX: 12, y: 12))

        let color = CIFilter.falseColor()
        color.inputImage = scaled
        color.color0 = CIColor(red: 0.318, green: 0.420, blue: 0.290) // 墨绿码点 #516B4A
        color.color1 = CIColor(red: 0, green: 0, blue: 0, alpha: 0)   // 透明底 透出米色卡片
        guard let out = color.outputImage,
              let cg = ctx.createCGImage(out, from: out.extent) else { return nil }
        return UIImage(cgImage: cg)
    }
}
