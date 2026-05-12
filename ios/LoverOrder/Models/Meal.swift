import Foundation

// 一顿的状态
enum MealStatus: String, Codable {
    case planning
    case confirmed
    case completed
    case cancelled

    var label: String {
        switch self {
        case .planning: return "想好吃啥"
        case .confirmed: return "已定下"
        case .completed: return "已尝过"
        case .cancelled: return "已取消"
        }
    }

    var tint: String {
        switch self {
        case .planning: return "#A07E4F"
        case .confirmed: return "#516B4A"
        case .completed: return "#8F5A2C"
        case .cancelled: return "#9A9897"
        }
    }
}

// 一顿
struct MealSession: Codable, Identifiable, Hashable {
    let id: UInt
    var title: String?
    var scene: Scene
    var mood: Mood
    var plannedAt: Date?
    var confirmedAt: Date?
    var completedAt: Date?
    var status: MealStatus
    var note: String?
    var dishes: [MealDish]?
    var reviews: [MealReview]?
    var creator: AppUser?
    var createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case scene
        case mood
        case plannedAt = "planned_at"
        case confirmedAt = "confirmed_at"
        case completedAt = "completed_at"
        case status
        case note
        case dishes
        case reviews
        case creator
        case createdAt = "created_at"
    }
}

// 一顿里的某道菜 含快照
struct MealDish: Codable, Identifiable, Hashable {
    let id: UInt
    var mealSessionId: UInt
    var recipeId: UInt?
    var recipeName: String
    var recipeImage: String?
    var note: String?
    var sortOrder: Int

    enum CodingKeys: String, CodingKey {
        case id
        case mealSessionId = "meal_session_id"
        case recipeId = "recipe_id"
        case recipeName = "recipe_name"
        case recipeImage = "recipe_image"
        case note
        case sortOrder = "sort_order"
    }
}

// 一顿的评价
struct MealReview: Codable, Identifiable, Hashable {
    let id: UInt
    var mealSessionId: UInt
    var userId: UInt
    var rating: Int
    var comment: String?
    var photos: [String]?
    var user: AppUser?
    var createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case mealSessionId = "meal_session_id"
        case userId = "user_id"
        case rating
        case comment
        case photos
        case user
        case createdAt = "created_at"
    }
}

struct MealListResult: Codable {
    let total: Int
    let items: [MealSession]
}
