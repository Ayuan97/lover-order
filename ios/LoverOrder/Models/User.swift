import Foundation

// 与后端 User 对应
struct AppUser: Codable, Identifiable, Hashable {
    let id: UInt
    var nickname: String
    var avatar: String?
    var email: String?
    var gender: Int8?
    var householdId: UInt?
    var defaultScene: MealScene?
    var defaultMood: Mood?
    var tastePrefs: [String]?
    var isActive: Bool?
    var lastLoginAt: Date?
    var createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case nickname
        case avatar
        case email
        case gender
        case householdId = "household_id"
        case defaultScene = "default_scene"
        case defaultMood = "default_mood"
        case tastePrefs = "taste_prefs"
        case isActive = "is_active"
        case lastLoginAt = "last_login_at"
        case createdAt = "created_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UInt.self, forKey: .id)
        nickname = try c.decode(String.self, forKey: .nickname)
        avatar = try c.decodeIfPresent(String.self, forKey: .avatar)
        email = try c.decodeIfPresent(String.self, forKey: .email)
        gender = try c.decodeIfPresent(Int8.self, forKey: .gender)
        householdId = try c.decodeIfPresent(UInt.self, forKey: .householdId)
        // 保留未知历史场景值为 nil，避免老账号登录或加载成员/菜谱创建者时解码失败
        if let rawScene = try c.decodeIfPresent(String.self, forKey: .defaultScene) {
            defaultScene = MealScene(rawValue: rawScene)
        } else {
            defaultScene = nil
        }
        if let rawMood = try c.decodeIfPresent(String.self, forKey: .defaultMood) {
            defaultMood = Mood(rawValue: rawMood)
        } else {
            defaultMood = nil
        }
        tastePrefs = try c.decodeIfPresent([String].self, forKey: .tastePrefs)
        isActive = try c.decodeIfPresent(Bool.self, forKey: .isActive)
        lastLoginAt = try c.decodeIfPresent(Date.self, forKey: .lastLoginAt)
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt)
    }

    var displayName: String {
        nickname.isEmpty ? "美食家" : nickname
    }

    var hasHousehold: Bool {
        if let id = householdId { return id > 0 }
        return false
    }
}
