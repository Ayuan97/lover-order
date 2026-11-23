import Foundation
import SwiftUI

// 全局应用状态 持有当前用户和家信息 跨 tab 共享
@MainActor
final class AppState: ObservableObject {
    @Published var currentUser: AppUser?
    @Published var household: Household?
    @Published var currentScene: MealScene = .household
    @Published var currentMood: Mood = .easy
    @Published var isBootstrapping: Bool = true
    // 有 token 但 profile 临时失败：停在 Splash 可重试，不当成登出
    @Published var bootstrapFailed: Bool = false
    // hasHousehold 但 info 拉失败：主界面可重试，别静默当成没家
    @Published var householdLoadFailed: Bool = false
    // 建家后弹出餐券；挂在 Root 避免 Setup 被卸掉后 sheet 一起没了
    @Published var pendingInviteTicket: Household?
    @Published var loginError: String?
    // 跟随当前画布底面明暗，让底部悬浮主导航与顶部状态栏在实景照/暗台上自动切换高对比样式。
    @Published var canvasIsLightSurface: Bool = false
    @Published var isMealTabActive: Bool = true
    @Published var activeTab: Int = 0
    @Published var isProfileHeroVisible: Bool = true
    @Published private var hiddenTabBarTokens: Set<UUID> = []

    // MARK: - 程序外深链与未读消息状态
    struct DeepLinkedHistoryMeal: Identifiable {
        let id = UUID()
        let mealId: UInt
    }

    struct DeepLinkedDiningRoom: Identifiable {
        let id = UUID()
        let code: String
    }

    @Published var pendingDeepLink: AppDeepLink?
    @Published var deepLinkedHistoryMeal: DeepLinkedHistoryMeal?
    @Published var deepLinkedDiningRoom: DeepLinkedDiningRoom?
    @Published var pendingJoinHomeCode: String?
    @Published var deepLinkToast: String?
    @Published var unreadNotificationCount: Int = 0

    var prefersDarkStatusBar: Bool {
        (isMealTabActive && !canvasIsLightSurface) || (activeTab == 3 && isProfileHeroVisible && !hidesFloatingTabBar)
    }

    var hidesFloatingTabBar: Bool {
        !hiddenTabBarTokens.isEmpty
    }

    func setTabBarHidden(_ hidden: Bool, token: UUID) {
        if hidden {
            hiddenTabBarTokens.insert(token)
        } else {
            hiddenTabBarTokens.remove(token)
        }
    }

    func switchToMealTab() {
        hiddenTabBarTokens.removeAll()
        activeTab = 0
        isMealTabActive = true
    }

    func switchToProfileTab() {
        hiddenTabBarTokens.removeAll()
        activeTab = 3
        isMealTabActive = false
    }

    func handleOpenURL(_ url: URL) {
        guard let link = AppDeepLink.parse(url: url) else { return }
        handleDeepLink(link)
    }

    func handleDeepLink(_ link: AppDeepLink) {
        guard isLoggedIn, !isBootstrapping else {
            pendingDeepLink = link
            return
        }
        routeDeepLink(link)
    }

    func consumePendingDeepLinkIfReady() {
        guard isLoggedIn, !isBootstrapping, let link = pendingDeepLink else { return }
        pendingDeepLink = nil
        routeDeepLink(link)
    }

    private func routeDeepLink(_ link: AppDeepLink) {
        switch link {
        case .meal:
            deepLinkedHistoryMeal = nil
            deepLinkedDiningRoom = nil
            switchToMealTab()
            AppNotifications.mealChanged()
        case .history(let mealId):
            guard currentUser?.hasHousehold == true || household != nil else {
                deepLinkToast = "先创建或加入一个家，就能看这顿饭记录了"
                return
            }
            deepLinkedDiningRoom = nil
            deepLinkedHistoryMeal = DeepLinkedHistoryMeal(mealId: mealId)
        case .room(let code):
            deepLinkedHistoryMeal = nil
            deepLinkedDiningRoom = DeepLinkedDiningRoom(code: code)
        case .home(let code):
            if currentUser?.hasHousehold == true || household != nil {
                let name = household?.name ?? "我们家"
                deepLinkToast = "你已经在「\(name)」里啦"
            } else {
                pendingJoinHomeCode = code
            }
        case .household:
            deepLinkedHistoryMeal = nil
            deepLinkedDiningRoom = nil
            if currentUser?.hasHousehold == true || household != nil {
                switchToProfileTab()
                Task { await refreshHousehold() }
            }
        }
    }

    var isLoggedIn: Bool {
        currentUser != nil
    }

    // 401 时 token 已被 APIClient 清掉 这里把人送回登录页 不然会留在主界面无限报错
    init() {
        NotificationCenter.default.addObserver(forName: .sessionExpired, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.currentUser = nil
                self?.household = nil
                self?.householdLoadFailed = false
                self?.bootstrapFailed = false
                self?.pendingInviteTicket = nil
            }
        }
    }

    // 启动时拉一次资料 据此决定走登录页还是主界面
    func bootstrap() async {
        defer { isBootstrapping = false }
        guard TokenStorage.shared.isLoggedIn else {
            bootstrapFailed = false
            return
        }
        do {
            let user = try await AuthService.shared.profile()
            currentUser = user
            bootstrapFailed = false
            // 产品主轴固定家庭餐次我们这顿
            currentScene = .household
            if let mood = user.defaultMood { currentMood = mood }
            if user.hasHousehold {
                await loadHousehold(markFailure: true)
            } else {
                household = nil
                householdLoadFailed = false
            }
        } catch let error as APIError {
            switch error {
            case .unauthorized:
                // token 已由 APIClient 清掉；确认未登录才回 Login
                currentUser = nil
                household = nil
                householdLoadFailed = false
                bootstrapFailed = false
            default:
                // 弱网/超时：不清 user、不踢登录；冷启动无 user 时靠 bootstrapFailed 留在 Splash
                bootstrapFailed = currentUser == nil
            }
        } catch {
            bootstrapFailed = currentUser == nil
        }
    }

    // Apple 登录成功后 写入令牌并拉资料
    func didLogin(_ result: LoginResult) async {
        TokenStorage.shared.access = result.accessToken
        TokenStorage.shared.refresh = result.refreshToken
        currentUser = result.user
        bootstrapFailed = false
        currentScene = .household
        if let mood = result.user.defaultMood { currentMood = mood }
        if result.user.hasHousehold {
            await loadHousehold(markFailure: true)
        } else {
            household = nil
            householdLoadFailed = false
        }
    }

    func didLogout() async {
        await NotificationManager.shared.handleLogout()
        try? await AuthService.shared.logout()
        TokenStorage.shared.clear()
        currentUser = nil
        household = nil
        householdLoadFailed = false
        bootstrapFailed = false
        pendingInviteTicket = nil
        pendingDeepLink = nil
        deepLinkedHistoryMeal = nil
        deepLinkedDiningRoom = nil
        pendingJoinHomeCode = nil
        unreadNotificationCount = 0
    }

    func refreshHousehold() async {
        await loadHousehold(markFailure: currentUser?.hasHousehold == true)
    }

    // 拉家信息；失败时保留旧 household，并在应有家时打失败标
    private func loadHousehold(markFailure: Bool) async {
        do {
            let h = try await HouseholdService.shared.info()
            household = h
            householdLoadFailed = false
        } catch {
            if markFailure {
                householdLoadFailed = true
            }
        }
    }

    // 返回是否成功 调用方需要可见错误时用返回值 避免 try? 半状态
    @discardableResult
    func refreshProfile() async -> Bool {
        do {
            currentUser = try await AuthService.shared.profile()
            return true
        } catch {
            return false
        }
    }

    // 建家/加入成功后立刻写入 避免 refresh 失败卡在引导页
    func applyHouseholdMembership(_ h: Household) {
        household = h
        householdLoadFailed = false
        if var u = currentUser {
            u.householdId = h.id
            currentUser = u
        }
    }

    // 同步资料 + 家 引导页半状态重试用
    @discardableResult
    func resyncMembership() async -> Bool {
        let ok = await refreshProfile()
        if currentUser?.hasHousehold == true {
            await loadHousehold(markFailure: true)
        } else {
            household = nil
            householdLoadFailed = false
        }
        return ok
    }
}
