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

    // 低饱和的纸胶带色：只做点缀，不抢内容。
    static let dopaminePink = Color(red: 0.82, green: 0.56, blue: 0.50)
    static let dopamineYellow = Color(red: 0.87, green: 0.76, blue: 0.43)
    static let actionInk = Color(red: 0.169, green: 0.176, blue: 0.153)

    static let paperWarm = Color(red: 0.965, green: 0.965, blue: 0.949)
    static let paperGreen = Color(red: 0.929, green: 0.957, blue: 0.867)
    static let clay = Color(red: 0.72, green: 0.43, blue: 0.30)

    // 用于轻量的选中底色与画布装饰。
    static let liveOlive = Color(red: 0.62, green: 0.67, blue: 0.43)
}
