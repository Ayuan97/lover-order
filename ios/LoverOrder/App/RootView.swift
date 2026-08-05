import SwiftUI

// 应用根视图 按登录态切换
struct RootView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            content
        }
        .preferredColorScheme(.light)
    }

    @ViewBuilder
    private var content: some View {
        if appState.isBootstrapping {
            SplashView()
        } else if appState.isLoggedIn {
            // household 已加载或用户已绑家 都进主页 避免只认 hasHousehold 的半状态死胡同
            if appState.currentUser?.hasHousehold == true || appState.household != nil {
                MainTabView()
            } else {
                HouseholdSetupView()
            }
        } else {
            LoginView()
        }
    }
}

// 启动占位 等 bootstrap 拉资料
struct SplashView: View {
    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            Text("我们这顿")
                .font(AppFont.title(34))
                .foregroundStyle(Color.inkPrimary)
            Text("正在准备")
                .font(AppFont.body())
                .foregroundStyle(Color.inkMuted)
            ProgressView().tint(Color.brandGreen)
        }
    }
}
