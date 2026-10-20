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
    // 分组的轻量层次。
    static let card = ShadowStyle(
        color: Color.black.opacity(0.035),
        radius: 8,
        x: 0,
        y: 3
    )
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
