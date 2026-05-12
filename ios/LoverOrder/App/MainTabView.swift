import SwiftUI

// 主框架 底部 4 个 tab 这一顿 / 菜单 / 记录 / 我的
struct MainTabView: View {
    @State private var selection: Tab = .meal

    enum Tab: Hashable {
        case meal
        case menu
        case history
        case profile
    }

    var body: some View {
        TabView(selection: $selection) {
            MealNowView()
                .tabItem {
                    Label("这一顿", systemImage: "fork.knife.circle")
                }
                .tag(Tab.meal)

            MenuView()
                .tabItem {
                    Label("菜单", systemImage: "book.closed")
                }
                .tag(Tab.menu)

            HistoryView()
                .tabItem {
                    Label("记录", systemImage: "clock.arrow.circlepath")
                }
                .tag(Tab.history)

            ProfileView()
                .tabItem {
                    Label("我的", systemImage: "person.circle")
                }
                .tag(Tab.profile)
        }
        .tint(Color.brandGreen)
    }
}
