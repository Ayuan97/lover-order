import SwiftUI

// TabView 保留四个页面的状态，底部图标提供四个主要入口。
struct MainTabView: View {
    @State private var selection: Tab = .meal
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var tabIndicator

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

        var glyph: ProductIcon.Kind {
            switch self {
            case .meal: return .meal
            case .menu: return .recipes
            case .history: return .history
            case .profile: return .profile
            }
        }

        var icon: String {
            switch self {
            case .meal: return "square.on.square"
            case .menu: return "book.closed"
            case .history: return "clock"
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
        .tint(CanvasTheme.accent)
        .toolbar(.hidden, for: .tabBar)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            navigationBar
        }
    }

    private var navigationBar: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases, id: \.self) { tab in
                Button {
                    guard selection != tab else { return }
                    Haptics.light()
                    selection = tab
                } label: {
                    VStack(spacing: 6) {
                        ProductIcon(kind: tab.glyph)
                            .foregroundStyle(selection == tab ? CanvasTheme.accent : CanvasTheme.secondary)
                            .offset(y: selection == tab ? -1 : 0)
                        Circle()
                            .fill(.clear)
                            .frame(width: 3, height: 3)
                            .overlay {
                                if selection == tab {
                                    Circle()
                                        .fill(CanvasTheme.accent)
                                        .matchedGeometryEffect(id: "selectedTab", in: tabIndicator)
                                }
                            }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .contentShape(Rectangle())
                }
                .buttonStyle(SoftPressStyle())
                .accessibilityLabel(tab.title)
                .accessibilityAddTraits(selection == tab ? .isSelected : [])
            }
        }
        .animation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.82), value: selection)
        .padding(.horizontal, 20)
        .background(CanvasTheme.page.ignoresSafeArea(edges: .bottom))
    }
}
