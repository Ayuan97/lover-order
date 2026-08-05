import Foundation
import SwiftUI

// 全局应用状态 持有当前用户和家信息 跨 tab 共享
@MainActor
final class AppState: ObservableObject {
    @Published var currentUser: AppUser?
    @Published var household: Household?
    @Published var currentScene: MealScene = .pair
    @Published var currentMood: Mood = .easy
    @Published var isBootstrapping: Bool = true
    // 有 token 但 profile 临时失败：停在 Splash 可重试，不当成登出
    @Published var bootstrapFailed: Bool = false
    // hasHousehold 但 info 拉失败：主界面可重试，别静默当成没家
    @Published var householdLoadFailed: Bool = false
    // 建家后弹出餐券；挂在 Root 避免 Setup 被卸掉后 sheet 一起没了
    @Published var pendingInviteTicket: Household?
    @Published var loginError: String?

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
            // 产品主轴固定情侣日常我们这顿
            currentScene = .pair
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
        currentScene = .pair
        if let mood = result.user.defaultMood { currentMood = mood }
        if result.user.hasHousehold {
            await loadHousehold(markFailure: true)
        } else {
            household = nil
            householdLoadFailed = false
        }
    }

    func didLogout() async {
        try? await AuthService.shared.logout()
        TokenStorage.shared.clear()
        currentUser = nil
        household = nil
        householdLoadFailed = false
        bootstrapFailed = false
        pendingInviteTicket = nil
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
