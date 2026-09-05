import SwiftUI

// 手账风字体规范：标题保留一点手写感，正文使用圆润系统字，避免数字产品的冷硬感。
enum AppFont {
    static func title(_ size: CGFloat = 28) -> Font {
        .custom("STKaiti-SC-Regular", size: size)
    }
    static func headline(_ size: CGFloat = 20) -> Font {
        .system(size: size, weight: .semibold, design: .rounded)
    }
    static func body(_ size: CGFloat = 15) -> Font {
        .system(size: size, weight: .regular, design: .rounded)
    }
    static func caption(_ size: CGFloat = 12) -> Font {
        .system(size: size, weight: .regular, design: .rounded)
    }
    static func mono(_ size: CGFloat = 13) -> Font {
        .system(size: size, weight: .medium, design: .monospaced)
    }
}
