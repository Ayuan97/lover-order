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
            TokenStorage.shared.clear()
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

    func refreshProfile() async {
        if let u = try? await AuthService.shared.profile() {
            currentUser = u
        }
    }
}
