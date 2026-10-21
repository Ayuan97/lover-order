import SwiftUI
import UIKit

// 全尺寸前景与原图对齐，分离后再换成裁去空白的贴图。
struct CutoutRevealView: View {
    let photo: UIImage
    let cutout: ImageCutout?
    let phase: Int

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.paperWarm
                transparencyPattern.opacity(phase >= 2 ? 1 : 0)

                Image(uiImage: cutout?.source ?? photo)
                    .resizable().scaledToFit()
                    .blur(radius: phase >= 1 ? 2 : 0)
                    .opacity(phase >= 2 ? 0 : phase >= 1 ? 0.38 : 1)

                if let cutout {
                    Image(uiImage: cutout.foreground)
                        .resizable().scaledToFit()
                        .shadow(color: .white.opacity(phase >= 1 ? 0.9 : 0), radius: 3)
                        .shadow(color: .black.opacity(phase >= 2 ? 0.14 : 0), radius: 12, y: 10)
                        .scaleEffect(phase >= 2 ? 1.035 : 1)
                        .offset(y: phase >= 2 ? -10 : 0)
                        .opacity(phase >= 1 && phase < 3 ? 1 : 0)

                    Image(uiImage: cutout.cropped)
                        .resizable().scaledToFit()
                        .padding(min(geometry.size.width, geometry.size.height) * 0.14)
                        .shadow(color: Color.inkPrimary.opacity(0.16), radius: 16, y: 14)
                        .rotationEffect(.degrees(phase >= 3 ? -3 : 0))
                        .scaleEffect(phase >= 3 ? 1 : 0.92)
                        .opacity(phase >= 3 ? 1 : 0)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
        }
        .accessibilityLabel(phase >= 3 ? "抠出的透明贴图" : "拍摄的原图与主体分离预览")
    }

    private var transparencyPattern: some View {
        Canvas { context, size in
            let side: CGFloat = 18
            for row in 0..<Int(ceil(size.height / side)) {
                for column in 0..<Int(ceil(size.width / side)) where (row + column).isMultiple(of: 2) {
                    let rect = CGRect(x: CGFloat(column) * side, y: CGFloat(row) * side, width: side, height: side)
                    context.fill(Path(rect), with: .color(Color.inkPrimary.opacity(0.035)))
                }
            }
        }
        .accessibilityHidden(true)
    }
}
