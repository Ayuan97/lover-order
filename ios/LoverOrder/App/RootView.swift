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
        // 建家餐券挂在根上：Setup 切走后仍能展示，关票只 refresh
        .sheet(item: $appState.pendingInviteTicket, onDismiss: {
            Task {
                if await appState.refreshProfile() {
                    await appState.refreshHousehold()
                }
            }
        }) { h in
            InviteTicketView(
                household: h,
                inviterName: appState.currentUser?.nickname ?? "我"
            )
        }
    }

    @ViewBuilder
    private var content: some View {
        if appState.isBootstrapping || appState.bootstrapFailed {
            // 有 token 但冷启动拉资料失败：留 Splash 再试，别当没登录
            SplashView(showRetry: appState.bootstrapFailed) {
                Task {
                    appState.isBootstrapping = true
                    appState.bootstrapFailed = false
                    await appState.bootstrap()
                }
            }
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

// 启动占位 等 bootstrap 拉资料；临时失败可再试一次
struct SplashView: View {
    var showRetry: Bool = false
    var onRetry: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            Text("我们这顿")
                .font(AppFont.title(34))
                .foregroundStyle(Color.inkPrimary)
            if showRetry {
                Text("网有点不稳 进不去")
                    .font(AppFont.body())
                    .foregroundStyle(Color.inkMuted)
                PrimaryButton(title: "再试一次", action: { onRetry?() })
                    .padding(.horizontal, AppSpacing.xxl)
            } else {
                Text("正在准备")
                    .font(AppFont.body())
                    .foregroundStyle(Color.inkMuted)
                ProgressView().tint(Color.brandGreen)
            }
        }
    }
}
