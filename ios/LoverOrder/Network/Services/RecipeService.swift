import Foundation

struct RecipeListQuery {
    var categoryId: UInt?
    var uncategorized: Bool = false
    var mood: Mood?
    var scene: MealScene?
    var keyword: String?
    var favorite: Bool = false
    var page: Int = 1
    var pageSize: Int = 20

    func toQuery() -> [String: String] {
        var q: [String: String] = ["page": "\(page)", "page_size": "\(pageSize)"]
        if uncategorized {
            q["uncategorized"] = "1"
        } else if let id = categoryId {
            q["category_id"] = "\(id)"
        }
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
    var cutoutImage: String?
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
    var sceneTags: [String]?
    var expectedUpdatedAt: String?
    var force: Bool?

    enum CodingKeys: String, CodingKey {
        case name
        case description
        case coverImage = "cover_image"
        case cutoutImage = "cutout_image"
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
        case expectedUpdatedAt = "expected_updated_at"
        case force
    }
}

struct FavoriteResult: Decodable {
    let favored: Bool
}

struct RecipeCoverInput: Encodable {
    var image: String
    var cutoutImage: String?
    var allowClear: Bool = false

    enum CodingKeys: String, CodingKey {
        case image
        case cutoutImage = "cutout_image"
        case allowClear = "allow_clear"
    }
}

private struct BatchCategoryRequest: Encodable {
    let recipeIds: [UInt]
    let categoryId: UInt?

    enum CodingKeys: String, CodingKey {
        case recipeIds = "recipe_ids"
        case categoryId = "category_id"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(recipeIds, forKey: .recipeIds)
        if let categoryId {
            try container.encode(categoryId, forKey: .categoryId)
        } else {
            try container.encodeNil(forKey: .categoryId)
        }
    }
}

private struct BatchCategoryResult: Decodable {
    let updated: Int
}

private struct BatchDeleteRequest: Encodable {
    let recipeIds: [UInt]

    enum CodingKeys: String, CodingKey {
        case recipeIds = "recipe_ids"
    }
}

private struct BatchDeleteResult: Decodable {
    let deleted: Int
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
        let r: Recipe = try await api.post("recipes/create", body: req)
        MenuLocalCache.upsertRecipe(r)
        return r
    }

    func update(id: UInt, req: RecipeInput) async throws -> Recipe {
        let r: Recipe = try await api.post("recipes/\(id)/update", body: req)
        MenuLocalCache.upsertRecipe(r)
        return r
    }

    func setCover(id: UInt, image: String, cutoutImage: String?, allowClear: Bool = false) async throws -> Recipe {
        let r: Recipe = try await api.post(
            "recipes/\(id)/cover",
            body: RecipeCoverInput(image: image, cutoutImage: cutoutImage, allowClear: allowClear)
        )
        MenuLocalCache.upsertRecipe(r)
        AppNotifications.recipesChanged()
        return r
    }

    func delete(id: UInt) async throws {
        let _: EmptyResponse = try await api.post("recipes/\(id)/delete")
        MenuLocalCache.removeRecipes(ids: [id])
    }

    @discardableResult
    func batchUpdateCategory(recipeIds: [UInt], categoryId: UInt?) async throws -> Int {
        let res: BatchCategoryResult = try await api.post(
            "recipes/batch-category",
            body: BatchCategoryRequest(recipeIds: recipeIds, categoryId: categoryId)
        )
        MenuLocalCache.updateRecipesCategory(ids: recipeIds, categoryId: categoryId)
        AppNotifications.recipesChanged()
        AppNotifications.categoriesChanged()
        return res.updated
    }

    @discardableResult
    func batchDelete(recipeIds: [UInt]) async throws -> Int {
        let res: BatchDeleteResult = try await api.post(
            "recipes/batch-delete",
            body: BatchDeleteRequest(recipeIds: recipeIds)
        )
        MenuLocalCache.removeRecipes(ids: recipeIds)
        AppNotifications.recipesChanged()
        AppNotifications.categoriesChanged()
        return res.deleted
    }

    func toggleFavorite(id: UInt) async throws -> Bool {
        let r: FavoriteResult = try await api.post("recipes/\(id)/favorite")
        return r.favored
    }
}
