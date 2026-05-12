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

    var displayName: String {
        nickname.isEmpty ? "美食家" : nickname
    }

    var hasHousehold: Bool {
        if let id = householdId { return id > 0 }
        return false
    }
}
