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
            }
        }
    }

    // 启动时拉一次资料 据此决定走登录页还是主界面
    func bootstrap() async {
        defer { isBootstrapping = false }
        guard TokenStorage.shared.isLoggedIn else { return }
        do {
            let user = try await AuthService.shared.profile()
            currentUser = user
            if let scene = user.defaultScene { currentScene = scene }
            if let mood = user.defaultMood { currentMood = mood }
            if user.hasHousehold {
                let h = try? await HouseholdService.shared.info()
                household = h
            }
        } catch {
            // 断网等临时错误不清 token 下次启动还能直接进;真 401 由 APIClient 统一清
            currentUser = nil
            household = nil
        }
    }

    // Apple 登录成功后 写入令牌并拉资料
    func didLogin(_ result: LoginResult) async {
        TokenStorage.shared.access = result.accessToken
        TokenStorage.shared.refresh = result.refreshToken
        currentUser = result.user
        if let scene = result.user.defaultScene { currentScene = scene }
        if let mood = result.user.defaultMood { currentMood = mood }
        if result.user.hasHousehold {
            household = try? await HouseholdService.shared.info()
        }
    }

    func didLogout() async {
        try? await AuthService.shared.logout()
        TokenStorage.shared.clear()
        currentUser = nil
        household = nil
    }

    func refreshHousehold() async {
        household = try? await HouseholdService.shared.info()
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
            await refreshHousehold()
        } else {
            household = nil
        }
        return ok
    }
}
