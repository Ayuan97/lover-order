import Foundation

struct RecipeListQuery {
    var categoryId: UInt?
    var mood: Mood?
    var scene: MealScene?
    var keyword: String?
    var favorite: Bool = false
    var page: Int = 1
    var pageSize: Int = 20

    func toQuery() -> [String: String] {
        var q: [String: String] = ["page": "\(page)", "page_size": "\(pageSize)"]
        if let id = categoryId { q["category_id"] = "\(id)" }
        if let m = mood { q["mood"] = m.rawValue }
        if let s = scene { q["scene"] = s.rawValue }
        if let k = keyword, !k.isEmpty { q["keyword"] = k }
        if favorite { q["favorite"] = "1" }
        return q
    }
}

struct RecipeInput: Encodable {
    var name: String
    var description: String?
    var coverImage: String?
    var images: [String]?
    var categoryId: UInt?
    var cookingTime: Int?
    var difficulty: Difficulty?
    var servings: Int?
    var ingredients: [Ingredient]?
    var steps: [CookingStep]?
    var tips: String?
    var tags: [String]?
    var moodTags: [Mood]?
    var sceneTags: [MealScene]?

    enum CodingKeys: String, CodingKey {
        case name
        case description
        case coverImage = "cover_image"
        case images
        case categoryId = "category_id"
        case cookingTime = "cooking_time"
        case difficulty
        case servings
        case ingredients
        case steps
        case tips
        case tags
        case moodTags = "mood_tags"
        case sceneTags = "scene_tags"
    }
}

struct FavoriteResult: Decodable {
    let favored: Bool
}

final class RecipeService {
    static let shared = RecipeService()
    private let api = APIClient.shared

    func list(_ query: RecipeListQuery = .init()) async throws -> RecipeListResult {
        try await api.get("recipes/list", query: query.toQuery())
    }

    func detail(id: UInt) async throws -> Recipe {
        try await api.get("recipes/\(id)")
    }

    func create(_ req: RecipeInput) async throws -> Recipe {
        try await api.post("recipes/create", body: req)
    }

    func update(id: UInt, req: RecipeInput) async throws -> Recipe {
        try await api.post("recipes/\(id)/update", body: req)
    }

    func delete(id: UInt) async throws {
        let _: EmptyResponse = try await api.post("recipes/\(id)/delete")
    }

    func toggleFavorite(id: UInt) async throws -> Bool {
        let r: FavoriteResult = try await api.post("recipes/\(id)/favorite")
        return r.favored
    }
}
