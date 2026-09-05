import SwiftUI

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
    static let actionInk = Color(red: 0.28, green: 0.30, blue: 0.26)

    static let paperWarm = Color(red: 0.975, green: 0.955, blue: 0.91)
    static let paperGreen = Color(red: 0.92, green: 0.95, blue: 0.86)
    static let clay = Color(red: 0.72, green: 0.43, blue: 0.30)

    // LiveLog home accent: a muted olive sampled from the reference screens.
    static let liveOlive = Color(red: 0.62, green: 0.67, blue: 0.43)
}
