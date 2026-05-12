import Foundation

// 跨页面事件 用 NotificationCenter 广播 让独立的 View 各自决定要不要刷新
extension Notification.Name {
    static let recipesChanged = Notification.Name("lover-order.recipes.changed")
    static let mealChanged = Notification.Name("lover-order.meal.changed")
    static let categoriesChanged = Notification.Name("lover-order.categories.changed")
}

enum AppNotifications {
    static func recipesChanged() {
        NotificationCenter.default.post(name: .recipesChanged, object: nil)
    }
    static func mealChanged() {
        NotificationCenter.default.post(name: .mealChanged, object: nil)
    }
    static func categoriesChanged() {
        NotificationCenter.default.post(name: .categoriesChanged, object: nil)
    }
}
