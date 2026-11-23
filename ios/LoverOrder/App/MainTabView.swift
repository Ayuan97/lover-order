import SwiftUI

// 底部浮动液态玻璃导航：懒加载并保活四个根页面，彻底替代系统 TabBar。
struct MainTabView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selection: Tab = .meal
    @State private var visited: Set<Tab> = [.meal]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var tabIndicator

    private var usePhotoGlass: Bool {
        selection == .meal && !appState.canvasIsLightSurface
    }

    enum Tab: Hashable, CaseIterable {
        case meal
        case menu
        case history
        case profile

        init(index: Int) {
            switch index {
            case 1: self = .menu
            case 2: self = .history
            case 3: self = .profile
            default: self = .meal
            }
        }

        var index: Int {
            switch self {
            case .meal: return 0
            case .menu: return 1
            case .history: return 2
            case .profile: return 3
            }
        }

        var title: String {
            switch self {
            case .meal: return "这一顿"
            case .menu: return "菜谱"
            case .history: return "记录"
            case .profile: return "我的"
            }
        }

        func symbolName(active: Bool) -> String {
            switch self {
            case .meal: return "fork.knife"
            case .menu: return active ? "book.closed.fill" : "book.closed"
            case .history: return active ? "clock.fill" : "clock"
            case .profile: return active ? "person.fill" : "person"
            }
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ZStack {
                tabContent(.meal) { MealNowView() }
                if visited.contains(.menu) {
                    tabContent(.menu) { MenuView().preferredColorScheme(.light) }
                }
                if visited.contains(.history) {
                    tabContent(.history) { HistoryView().preferredColorScheme(.light) }
                }
                if visited.contains(.profile) {
                    tabContent(.profile) { ProfileView().environment(\.colorScheme, .light) }
                }
            }

            navigationBar
                .offset(y: appState.hidesFloatingTabBar ? 110 : 0)
                .opacity(appState.hidesFloatingTabBar ? 0 : 1)
                .allowsHitTesting(!appState.hidesFloatingTabBar)
                .animation(reduceMotion ? nil : .spring(response: 0.30, dampingFraction: 0.86), value: appState.hidesFloatingTabBar)
        }
        .tint(CanvasTheme.ink)
        .onAppear {
            appState.isMealTabActive = (selection == .meal)
            appState.activeTab = selection.index
        }
        .onChange(of: selection) { _, next in
            appState.isMealTabActive = (next == .meal)
            if appState.activeTab != next.index {
                appState.activeTab = next.index
            }
            visited.insert(next)
        }
        .onChange(of: appState.activeTab) { _, nextIndex in
            let target = Tab(index: nextIndex)
            if selection != target {
                selection = target
            }
            visited.insert(target)
        }
    }

    @ViewBuilder
    private func tabContent<Content: View>(_ tab: Tab, @ViewBuilder content: () -> Content) -> some View {
        let isActive = selection == tab
        content()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .opacity(isActive ? 1 : 0)
            .allowsHitTesting(isActive)
            .accessibilityHidden(!isActive)
            .zIndex(isActive ? 1 : 0)
    }

    private var navigationBar: some View {
        let activeColor = usePhotoGlass ? Color.white : Color(red: 0.067, green: 0.067, blue: 0.075)
        let inactiveColor = usePhotoGlass ? Color.white.opacity(0.76) : Color(red: 0.557, green: 0.557, blue: 0.576)
        let activePill = usePhotoGlass ? Color.white.opacity(0.24) : Color.black.opacity(0.075)

        return HStack(spacing: 2) {
            ForEach(Tab.allCases, id: \.self) { tab in
                let isSelected = selection == tab
                Button {
                    guard selection != tab else { return }
                    Haptics.light()
                    selection = tab
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: tab.symbolName(active: isSelected))
                            .font(.system(size: 16, weight: isSelected ? .semibold : .regular))
                            .frame(width: 24, height: 20)
                            .overlay(alignment: .topTrailing) {
                                if tab == .profile && appState.unreadNotificationCount > 0 {
                                    Circle()
                                        .fill(Color(red: 0.90, green: 0.30, blue: 0.25))
                                        .frame(width: 7, height: 7)
                                        .overlay {
                                            Circle().stroke(Color.white, lineWidth: 1.2)
                                        }
                                        .offset(x: 4, y: -2)
                                }
                            }
                            .accessibilityHidden(true)

                        Text(tab.title)
                            .font(.system(size: 10, weight: isSelected ? .semibold : .regular, design: .rounded))
                            .lineLimit(1)
                    }
                    .foregroundStyle(isSelected ? activeColor : inactiveColor)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background {
                        if isSelected {
                            Capsule()
                                .fill(activePill)
                                .matchedGeometryEffect(id: "selectedTab", in: tabIndicator)
                        }
                    }
                    .contentShape(Capsule())
                }
                .buttonStyle(SoftPressStyle())
                .accessibilityLabel(tab.title)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .animation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.82), value: selection)
        .padding(5)
        .frame(height: 58)
        .background {
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay {
                    Capsule().fill(usePhotoGlass ? Color.black.opacity(0.24) : Color.white.opacity(0.68))
                }
        }
        .overlay {
            Capsule().strokeBorder(
                usePhotoGlass ? Color.white.opacity(0.42) : Color.white.opacity(0.92),
                lineWidth: 0.9
            )
        }
        .overlay {
            Capsule().strokeBorder(
                usePhotoGlass ? Color.black.opacity(0.18) : Color.black.opacity(0.08),
                lineWidth: 0.6
            )
        }
        .shadow(color: Color.black.opacity(usePhotoGlass ? 0.24 : 0.10), radius: 18, y: 6)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: usePhotoGlass)
        .padding(.horizontal, 20)
        .padding(.bottom, 6)
    }
}
