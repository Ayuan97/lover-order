import UIKit

// 轻量触觉反馈 只在关键正向操作上用 保持克制
enum Haptics {
    // 加菜等轻动作
    static func light() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    // 柔和触碰（选色、落笔、微交互）
    static func soft() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    }

    // 中等弹性反馈（贴纸落桌、排版切换）
    static func medium() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    // 清脆印章按压（手绘盖章）
    static func rigid() {
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
    }

    // 选项切换与磁吸微振
    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }

    // Q 弹双段节奏（先柔触后回弹轻落）
    static func popSequence() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.78)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.075) {
            UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.92)
        }
    }

    // 就这些 / 吃完了 等有仪式感的确认
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}
