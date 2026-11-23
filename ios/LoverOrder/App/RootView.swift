import SwiftUI
import UIKit

// 应用根视图：开屏动画帘幕 + 登录态切换
struct RootView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.scenePhase) private var scenePhase
    @State private var launchConfig: LaunchCurtainConfig = LaunchCurtainStore.load()
    @State private var launchPayload: LaunchCanvasDocumentPayload = LaunchCanvasStore.loadOrDefaultPayload()
    @State private var showLaunchCurtain: Bool = LaunchCurtainStore.load().enabled

    private var prefersLightTextStatusBar: Bool {
        if showLaunchCurtain {
            return !launchPayload.isLightSurface
        }
        return appState.prefersDarkStatusBar
    }

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            content

            if showLaunchCurtain {
                LaunchCurtainView(
                    config: launchConfig,
                    previewPayload: launchPayload,
                    canDismiss: !appState.isBootstrapping,
                    allowTapToSkip: true,
                    holdMilliseconds: launchConfig.holdSpeed.milliseconds
                ) {
                    withAnimation(.easeOut(duration: 0.25)) {
                        showLaunchCurtain = false
                    }
                }
                .zIndex(100)
                .transition(.opacity)
            }
        }
        .preferredColorScheme(prefersLightTextStatusBar ? .dark : .light)
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
            .preferredColorScheme(.light)
        }
        .sheet(item: $appState.deepLinkedHistoryMeal) { item in
            NavigationStack {
                HistoryDetailView(mealId: item.mealId)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("关闭") {
                                appState.deepLinkedHistoryMeal = nil
                            }
                        }
                    }
            }
            .environmentObject(appState)
            .preferredColorScheme(.light)
        }
        .sheet(item: $appState.deepLinkedDiningRoom) { item in
            DiningJoinView(initialRoomCode: item.code)
                .environmentObject(appState)
                .preferredColorScheme(.light)
        }
        .tipToast($appState.deepLinkToast)
        .onAppear {
            NotificationManager.shared.onUnreadCountChange = { count in
                appState.unreadNotificationCount = count
            }
            NotificationManager.shared.onDeepLink = { link in
                if showLaunchCurtain {
                    withAnimation(.easeOut(duration: 0.2)) {
                        showLaunchCurtain = false
                    }
                }
                appState.handleDeepLink(link)
            }
        }
        .onChange(of: appState.pendingDeepLink) { _, next in
            if next != nil, showLaunchCurtain {
                withAnimation(.easeOut(duration: 0.2)) {
                    showLaunchCurtain = false
                }
            }
        }
        .task(id: "\(appState.currentUser?.id ?? 0)-\(appState.isBootstrapping)") {
            guard !appState.isBootstrapping, let uid = appState.currentUser?.id else { return }
            await NotificationManager.shared.onAuthenticated(userId: uid)
            appState.consumePendingDeepLinkIfReady()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active, appState.isLoggedIn else { return }
            Task {
                await NotificationManager.shared.refreshAuthorizationStatus()
                await NotificationManager.shared.syncServerNotifications(allowLocalBanner: true)
            }
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
            Image("StickerEmoji_food_cheers")
                .resizable()
                .scaledToFit()
                .frame(width: 78, height: 78)
                .shadow(color: Color.black.opacity(0.10), radius: 10, y: 4)
            Text("我们这顿")
                .font(AppFont.title(32))
                .foregroundStyle(Color.inkPrimary)
            if showRetry {
                Text("网有点不稳，暂时进不去")
                    .font(AppFont.body())
                    .foregroundStyle(Color.inkMuted)
                PrimaryButton(title: "再试一次", action: { onRetry?() })
                    .padding(.horizontal, AppSpacing.xxl)
            } else {
                Text("正在摆上桌")
                    .font(AppFont.body())
                    .foregroundStyle(Color.inkMuted)
                ProgressView().tint(Color.brandGreen)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackground.ignoresSafeArea())
    }
}

// MARK: - DIY 开屏动画配置与全屏帘幕

enum LaunchCurtainMotion: String, CaseIterable, Identifiable, Codable {
    case fadeZoom
    case curtainUp
    case polaroidDrop
    case bloom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fadeZoom: return "柔焦淡出"
        case .curtainUp: return "拉开帘幕"
        case .polaroidDrop: return "拍立得飞入"
        case .bloom: return "轻盈落星"
        }
    }

    var icon: String {
        switch self {
        case .fadeZoom: return "sparkles"
        case .curtainUp: return "arrow.up.to.line"
        case .polaroidDrop: return "photo.artframe"
        case .bloom: return "sun.max"
        }
    }
}

enum LaunchHoldSpeed: String, CaseIterable, Identifiable, Codable {
    case brisk
    case standard
    case leisurely

    var id: String { rawValue }

    var title: String {
        switch self {
        case .brisk: return "轻快"
        case .standard: return "标准"
        case .leisurely: return "慢赏"
        }
    }

    var subtitle: String {
        switch self {
        case .brisk: return "1.1s"
        case .standard: return "1.5s"
        case .leisurely: return "2.2s"
        }
    }

    var milliseconds: Int {
        switch self {
        case .brisk: return 1100
        case .standard: return 1500
        case .leisurely: return 2200
        }
    }
}

struct LaunchCurtainConfig: Codable, Equatable {
    var enabled: Bool = true
    var motion: LaunchCurtainMotion = .fadeZoom
    var holdSpeed: LaunchHoldSpeed = .standard

    static let defaultConfig = LaunchCurtainConfig()

    private enum CodingKeys: String, CodingKey {
        case enabled, motion, holdSpeed
    }

    init(
        enabled: Bool = true,
        motion: LaunchCurtainMotion = .fadeZoom,
        holdSpeed: LaunchHoldSpeed = .standard
    ) {
        self.enabled = enabled
        self.motion = motion
        self.holdSpeed = holdSpeed
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        motion = try container.decodeIfPresent(LaunchCurtainMotion.self, forKey: .motion) ?? .fadeZoom
        holdSpeed = try container.decodeIfPresent(LaunchHoldSpeed.self, forKey: .holdSpeed) ?? .standard
    }
}

enum LaunchCurtainStore {
    private static let key = "launch.curtain.config.v1"

    static func load() -> LaunchCurtainConfig {
        guard let data = UserDefaults.standard.data(forKey: key),
              let config = try? JSONDecoder().decode(LaunchCurtainConfig.self, from: data) else {
            return .defaultConfig
        }
        return config
    }

    static func save(_ config: LaunchCurtainConfig) {
        if let data = try? JSONEncoder().encode(config) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}

struct LaunchCurtainView: View {
    let config: LaunchCurtainConfig
    var previewPayload: LaunchCanvasDocumentPayload? = nil
    var canDismiss: Bool = true
    var allowTapToSkip: Bool = true
    var holdMilliseconds: Int = 1500
    let onFinished: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var entered = false
    @State private var exiting = false
    @State private var didComplete = false
    @State private var minHoldElapsed = false

    private var exitOpacity: Double {
        exiting ? 0 : 1
    }

    private var exitOffsetY: CGFloat {
        guard exiting, config.motion == .curtainUp else { return 0 }
        return -UIScreen.main.bounds.height
    }

    private var fullBleedScale: CGFloat {
        let usesZoom = config.motion == .fadeZoom || config.motion == .bloom
        if exiting && usesZoom { return 1.06 }
        if !entered && usesZoom { return 1.05 }
        return 1.0
    }

    var body: some View {
        let payload = previewPayload ?? LaunchCanvasStore.loadOrDefaultPayload()
        let isLight = payload.isLightSurface
        let backdropFill = isLight ? Color.white : Color(red: 0.06, green: 0.06, blue: 0.07)

        ZStack(alignment: .topTrailing) {
            backdropFill.ignoresSafeArea()

            LaunchCanvasPlaybackView(
                payload: payload,
                isLiveActive: entered,
                inPolaroidFrame: config.motion == .polaroidDrop,
                isExiting: exiting,
                motionScale: fullBleedScale
            )
            .opacity(entered ? 1 : 0.92)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.72), value: entered)
            .ignoresSafeArea()
            .contentShape(Rectangle())
            .onTapGesture {
                if allowTapToSkip && canDismiss {
                    triggerDismiss(quick: true)
                }
            }

            if config.motion == .bloom {
                bloomSparkles(isLight: isLight)
                    .opacity(entered ? 0.92 : 0)
                    .scaleEffect(entered ? 1 : 0.82)
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.85), value: entered)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
        }
        .overlay(alignment: .topTrailing) {
            if allowTapToSkip && canDismiss {
                Button {
                    triggerDismiss(quick: true)
                } label: {
                    Text("跳过")
                        .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(isLight ? Color(red: 0.067, green: 0.067, blue: 0.075) : .white)
                        .padding(.horizontal, 13)
                        .frame(height: 32)
                        .background(
                            isLight ? Color.white.opacity(0.76) : Color.black.opacity(0.34),
                            in: Capsule()
                        )
                        .overlay {
                            Capsule()
                                .strokeBorder(
                                    isLight ? Color.black.opacity(0.10) : Color.white.opacity(0.32),
                                    lineWidth: 0.8
                                )
                        }
                }
                .buttonStyle(SoftPressStyle())
                .padding(.top, 10)
                .padding(.trailing, 18)
                .accessibilityLabel("跳过开屏动画")
            }
        }
        .offset(y: exitOffsetY)
        .opacity(exitOpacity)
        .task {
            try? await Task.sleep(for: .milliseconds(40))
            entered = true
            let holdDuration: Duration = reduceMotion ? .milliseconds(450) : .milliseconds(holdMilliseconds)
            try? await Task.sleep(for: holdDuration)
            minHoldElapsed = true
        }
        .onChange(of: minHoldElapsed) { _, elapsed in
            if elapsed && canDismiss {
                triggerDismiss(quick: false)
            }
        }
        .onChange(of: canDismiss) { _, ready in
            if ready && minHoldElapsed {
                triggerDismiss(quick: false)
            }
        }
    }

    private func bloomSparkles(isLight: Bool) -> some View {
        let tint = isLight ? Color(red: 0.067, green: 0.067, blue: 0.075).opacity(0.22) : Color.white.opacity(0.72)
        let points: [(CGFloat, CGFloat, CGFloat)] = [
            (-0.35, -0.30, 8), (0.34, -0.25, 6), (-0.30, 0.25, 6),
            (0.36, 0.30, 9), (0.06, -0.37, 5), (-0.14, 0.36, 5)
        ]
        return GeometryReader { proxy in
            ForEach(points.indices, id: \.self) { idx in
                let pt = points[idx]
                Image(systemName: "sparkle")
                    .font(.system(size: pt.2, weight: .semibold))
                    .foregroundStyle(tint)
                    .position(
                        x: proxy.size.width * (0.5 + pt.0),
                        y: proxy.size.height * (0.5 + pt.1)
                    )
            }
        }
    }

    private func triggerDismiss(quick: Bool) {
        guard !didComplete else { return }
        didComplete = true
        let duration: Double = reduceMotion ? 0.25 : (quick ? 0.26 : (config.motion == .curtainUp ? 0.44 : 0.38))
        withAnimation(.easeInOut(duration: duration)) {
            exiting = true
        }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(duration + 0.02))
            onFinished()
        }
    }
}

struct LaunchIntroSettingsView: View {
    var body: some View {
        LaunchCanvasStudioView()
    }
}
