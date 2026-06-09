import UIKit

// 轻量触觉反馈 只在关键正向操作上用 保持克制
enum Haptics {
    // 加菜等轻动作
    static func light() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    // 定下这一顿 / 做好啦 等有仪式感的确认
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}
