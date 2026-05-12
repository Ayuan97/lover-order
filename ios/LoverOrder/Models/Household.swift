import Foundation

// 与后端 Household 对应
struct Household: Codable, Identifiable, Hashable {
    let id: UInt
    var name: String
    var inviteCode: String
    var description: String?
    var createdBy: UInt
    var members: [AppUser]?
    var createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case inviteCode = "invite_code"
        case description
        case createdBy = "created_by"
        case members
        case createdAt = "created_at"
    }
}

struct HouseholdInvite: Codable, Identifiable, Hashable {
    let id: UInt
    var householdId: UInt
    var code: String
    var expiresAt: Date?
    var maxUses: Int
    var usedCount: Int
    var isActive: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case householdId = "household_id"
        case code
        case expiresAt = "expires_at"
        case maxUses = "max_uses"
        case usedCount = "used_count"
        case isActive = "is_active"
    }
}
