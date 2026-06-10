import SwiftUI

// 字体规范 沿用系统 PingFang 配合 SF 数字 视觉上贴近设计稿
enum AppFont {
    // system(design:.serif) 对中文无效(仍渲染苹方) 中文衬线必须显式用宋体
    static func title(_ size: CGFloat = 28) -> Font {
        .custom("STSongti-SC-Bold", size: size)
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
