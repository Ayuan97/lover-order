import SwiftUI

// 字体规范 沿用系统 PingFang 配合 SF 数字 视觉上贴近设计稿
enum AppFont {
    static func title(_ size: CGFloat = 28) -> Font {
        .system(size: size, weight: .semibold, design: .serif)
    }
    static func headline(_ size: CGFloat = 20) -> Font {
        .system(size: size, weight: .semibold)
    }
    static func body(_ size: CGFloat = 15) -> Font {
        .system(size: size, weight: .regular)
    }
    static func caption(_ size: CGFloat = 12) -> Font {
        .system(size: size, weight: .regular)
    }
    static func mono(_ size: CGFloat = 13) -> Font {
        .system(size: size, weight: .medium, design: .monospaced)
    }
}
