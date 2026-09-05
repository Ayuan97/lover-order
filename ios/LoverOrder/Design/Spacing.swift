import SwiftUI

// 间距 圆角 阴影规范
enum AppSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 20
    static let xxl: CGFloat = 28
    static let xxxl: CGFloat = 40
}

enum AppRadius {
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 18
    static let xl: CGFloat = 24
    static let pill: CGFloat = 999
}

enum AppShadow {
    // 纸片只离开背景一点点，保留手账的轻盈感。
    static let card = ShadowStyle(
        color: Color(red: 0.34, green: 0.27, blue: 0.18).opacity(0.10),
        radius: 12,
        x: 0,
        y: 5
    )
}

/// 全局极轻纸张颗粒。它放在内容上方但不接收触摸，让每个页面都有实体纸张的触感。
struct PaperGrainOverlay: View {
    var body: some View {
        Canvas { context, size in
            let step: CGFloat = 26
            var index = 0
            for y in stride(from: 0, through: size.height, by: step) {
                for x in stride(from: 0, through: size.width, by: step) {
                    let n = CGFloat((index * 31) % 17) / 17
                    let dot = Path(ellipseIn: CGRect(
                        x: x + n * 7,
                        y: y + CGFloat((index * 13) % 9),
                        width: 0.45 + n * 0.8,
                        height: 0.45 + n * 0.8
                    ))
                    context.fill(dot, with: .color(Color.accentInk.opacity(0.010 + n * 0.008)))
                    index += 1
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct ShadowStyle {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

extension View {
    func appCardShadow() -> some View {
        shadow(color: AppShadow.card.color, radius: AppShadow.card.radius, x: AppShadow.card.x, y: AppShadow.card.y)
    }

    // 暖灰细描边 在近白背景上勾出卡片/药丸/输入框的边缘
    func hairline(_ radius: CGFloat, color: Color = Color.dividerLine.opacity(0.7)) -> some View {
        overlay(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(color, lineWidth: 1)
        )
    }

    func capsuleHairline(color: Color = Color.dividerLine.opacity(0.7)) -> some View {
        overlay(Capsule(style: .continuous).strokeBorder(color, lineWidth: 1))
    }
}
