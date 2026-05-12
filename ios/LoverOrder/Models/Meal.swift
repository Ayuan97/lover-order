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
    var scene: MealScene
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

// 购物清单
struct ShoppingList: Codable {
    let mealId: UInt
    let items: [ShoppingItem]

    enum CodingKeys: String, CodingKey {
        case mealId = "meal_id"
        case items
    }
}

struct ShoppingItem: Codable, Identifiable, Hashable {
    var id: String { name }
    let name: String
    let amounts: [String]?
    let from: [String]?
}

// 一个家的累积统计
struct HouseholdStats: Codable {
    let totalMeals: Int
    let totalDishes: Int
    let recentDays: Int
    let recentMeals: Int
    let topDishes: [TopDish]
    let sceneBreakdown: [SceneCount]

    enum CodingKeys: String, CodingKey {
        case totalMeals = "total_meals"
        case totalDishes = "total_dishes"
        case recentDays = "recent_days"
        case recentMeals = "recent_meals"
        case topDishes = "top_dishes"
        case sceneBreakdown = "scene_breakdown"
    }
}

struct TopDish: Codable, Identifiable, Hashable {
    var id: String { name }
    let name: String
    let image: String?
    let count: Int
}

struct SceneCount: Codable, Identifiable, Hashable {
    var id: String { scene }
    let scene: String
    let count: Int

    var sceneLabel: String {
        MealScene(rawValue: scene)?.label ?? scene
    }
}
