import Foundation

// 难度
enum Difficulty: String, Codable, CaseIterable, Identifiable {
    case easy
    case medium
    case hard

    var id: String { rawValue }

    var label: String {
        switch self {
        case .easy: return "简单"
        case .medium: return "中等"
        case .hard: return "进阶"
        }
    }
}

// 食材项
struct Ingredient: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var name: String
    var amount: String
    var note: String?

    enum CodingKeys: String, CodingKey {
        case name
        case amount
        case note
    }
}

// 做法步骤
struct CookingStep: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var index: Int
    var text: String
    var image: String?

    enum CodingKeys: String, CodingKey {
        case index
        case text
        case image
    }
}

// 菜谱分类
struct RecipeCategory: Codable, Identifiable, Hashable {
    let id: UInt
    var name: String
    var icon: String?
    var color: String?
    var sortOrder: Int

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case icon
        case color
        case sortOrder = "sort_order"
    }
}

// 菜谱
struct Recipe: Codable, Identifiable, Hashable {
    let id: UInt
    var name: String
    var description: String?
    var coverImage: String?
    var images: [String]?
    var categoryId: UInt?
    var category: RecipeCategory?
    var cookingTime: Int?
    var difficulty: Difficulty?
    var servings: Int?
    var ingredients: [Ingredient]?
    var steps: [CookingStep]?
    var tips: String?
    var tags: [String]?
    var moodTags: [Mood]?
    var sceneTags: [MealScene]?
    var viewCount: Int?
    var useCount: Int?
    var lastUsedAt: Date?
    var createdAt: Date?
    var creator: AppUser?
    var isFavored: Bool?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case coverImage = "cover_image"
        case images
        case categoryId = "category_id"
        case category
        case cookingTime = "cooking_time"
        case difficulty
        case servings
        case ingredients
        case steps
        case tips
        case tags
        case moodTags = "mood_tags"
        case sceneTags = "scene_tags"
        case viewCount = "view_count"
        case useCount = "use_count"
        case lastUsedAt = "last_used_at"
        case createdAt = "created_at"
        case creator
        case isFavored = "is_favored"
    }
}

// 列表分页结果
struct RecipeListResult: Codable {
    let total: Int
    let items: [Recipe]
}
