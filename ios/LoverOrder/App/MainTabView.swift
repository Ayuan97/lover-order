import SwiftUI

// 主框架底部四个入口。使用系统 TabBar 让安全区、Home Indicator 和切换动画保持为一层。
struct MainTabView: View {
    @State private var selection: Tab = .meal

    enum Tab: Hashable, CaseIterable {
        case meal
        case menu
        case history
        case profile

        var title: String {
            switch self {
            case .meal: return "这一顿"
            case .menu: return "菜谱"
            case .history: return "记录"
            case .profile: return "我的"
            }
        }

        var icon: String {
            switch self {
            case .meal: return "fork.knife"
            case .menu: return "book.closed"
            case .history: return "clock.arrow.circlepath"
            case .profile: return "person"
            }
        }
    }

    var body: some View {
        TabView(selection: $selection) {
            MealNowView()
                .tabItem { Label(Tab.meal.title, systemImage: Tab.meal.icon) }
                .tag(Tab.meal)

            MenuView()
                .tabItem { Label(Tab.menu.title, systemImage: Tab.menu.icon) }
                .tag(Tab.menu)

            HistoryView()
                .tabItem { Label(Tab.history.title, systemImage: Tab.history.icon) }
                .tag(Tab.history)

            ProfileView()
                .tabItem { Label(Tab.profile.title, systemImage: Tab.profile.icon) }
                .tag(Tab.profile)
        }
        .tint(Color.brandGreen)
        .toolbarBackground(.visible, for: .tabBar)
        .toolbarBackground(Color.cardBackground, for: .tabBar)
        .toolbarColorScheme(.light, for: .tabBar)
    }
}
