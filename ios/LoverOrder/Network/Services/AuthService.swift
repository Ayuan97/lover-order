import Foundation

// Apple 登录入参
struct AppleLoginRequest: Encodable {
    let identityToken: String
    let nickname: String?
    let avatar: String?

    enum CodingKeys: String, CodingKey {
        case identityToken = "identity_token"
        case nickname
        case avatar
    }
}

// 登录返回
struct LoginResult: Decodable {
    let user: AppUser
    let accessToken: String
    let refreshToken: String

    enum CodingKeys: String, CodingKey {
        case user
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
    }
}

struct RefreshResult: Decodable {
    let accessToken: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
    }
}

// 更新资料入参
struct UpdateProfileRequest: Encodable {
    var nickname: String?
    var avatar: String?
    var gender: Int8?
    var defaultScene: MealScene?
    var defaultMood: Mood?
    var tastePrefs: [String]?

    enum CodingKeys: String, CodingKey {
        case nickname
        case avatar
        case gender
        case defaultScene = "default_scene"
        case defaultMood = "default_mood"
        case tastePrefs = "taste_prefs"
    }
}

final class AuthService {
    static let shared = AuthService()

    private let api = APIClient.shared

    func loginWithApple(identityToken: String, nickname: String?, avatar: String? = nil) async throws -> LoginResult {
        let body = AppleLoginRequest(identityToken: identityToken, nickname: nickname, avatar: avatar)
        return try await api.post("auth/apple", body: body)
    }

    func refresh(refreshToken: String) async throws -> String {
        struct Body: Encodable {
            let refreshToken: String
            enum CodingKeys: String, CodingKey { case refreshToken = "refresh_token" }
        }
        let res: RefreshResult = try await api.post("auth/refresh", body: Body(refreshToken: refreshToken))
        return res.accessToken
    }

    func logout() async throws {
        let _: EmptyResponse = try await api.post("auth/logout")
        TokenStorage.shared.clear()
    }

    func profile() async throws -> AppUser {
        try await api.get("user/profile")
    }

    func updateProfile(_ req: UpdateProfileRequest) async throws -> AppUser {
        try await api.post("user/profile", body: req)
    }
}
