import SwiftUI

enum CanvasTheme {
    static let page = Color.appBackground
    static let surface = Color.cardBackground
    static let ink = Color.inkPrimary
    static let secondary = Color.inkMuted
    static let accent = Color.brandGreen
    static let line = Color.dividerLine
}

// 设计系统色板 与 Assets.xcassets 中的颜色资源一一对应
extension Color {
    static let appBackground = Color("AppBackground")
    static let cardBackground = Color("CardBackground")
    static let brandGreen = Color("BrandGreen")
    static let accentInk = Color("AccentInk")
    static let inkPrimary = Color("InkPrimary")
    static let inkSecondary = Color("InkSecondary")
    static let inkMuted = Color("InkMuted")
    static let dividerLine = Color("Divider")
    static let errorInk = Color("ErrorInk")
    static let accentWarm = Color("AccentWarm")

    // 极简低饱和辅助色：冷银、曜石黑、微暖点缀
    static let dopaminePink = Color(red: 0.82, green: 0.56, blue: 0.50)
    static let dopamineYellow = Color(red: 0.87, green: 0.76, blue: 0.43)
    static let actionInk = Color(red: 0.067, green: 0.067, blue: 0.075)

    static let paperWarm = Color(red: 0.969, green: 0.969, blue: 0.976)
    static let paperGreen = Color(red: 0.929, green: 0.929, blue: 0.941)
    static let clay = Color(red: 0.52, green: 0.48, blue: 0.45)

    // 轻量选中指示与次级强调
    static let liveOlive = Color(red: 0.45, green: 0.45, blue: 0.48)
}
