import Foundation

struct MealInput: Encodable {
    var title: String?
    var scene: MealScene?
    var mood: Mood?
    var plannedAt: Date?
    var note: String?

    enum CodingKeys: String, CodingKey {
        case title
        case scene
        case mood
        case plannedAt = "planned_at"
        case note
    }
}

struct DishInput: Encodable {
    var recipeId: UInt?
    var name: String?
    var image: String?
    var note: String?

    enum CodingKeys: String, CodingKey {
        case recipeId = "recipe_id"
        case name
        case image
        case note
    }
}

struct ReviewInput: Encodable {
    var rating: Int
    var comment: String?
    var photos: [String]?
    var dishReviews: [DishReviewInput]? = nil

    enum CodingKeys: String, CodingKey {
        case rating
        case comment
        case photos
        case dishReviews = "dish_reviews"
    }
}

struct DishReviewInput: Encodable {
    var mealDishId: UInt
    var rating: Int
    var comment: String?

    enum CodingKeys: String, CodingKey {
        case mealDishId = "meal_dish_id"
        case rating
        case comment
    }
}

struct MealListQuery {
    var scene: MealScene?
    var status: MealStatus?
    var page: Int = 1
    var pageSize: Int = 20

    func toQuery() -> [String: String] {
        var q: [String: String] = ["page": "\(page)", "page_size": "\(pageSize)"]
        if let s = scene { q["scene"] = s.rawValue }
        if let st = status { q["status"] = st.rawValue }
        return q
    }
}

final class MealService {
    static let shared = MealService()
    private let api = APIClient.shared

    func current(scene: MealScene? = nil, mood: Mood? = nil) async throws -> MealSession {
        var q: [String: String] = [:]
        if let s = scene { q["scene"] = s.rawValue }
        if let m = mood { q["mood"] = m.rawValue }
        return try await api.get("meals/current", query: q)
    }

    func list(_ query: MealListQuery = .init()) async throws -> MealListResult {
        try await api.get("meals/list", query: query.toQuery())
    }

    func stats() async throws -> HouseholdStats {
        try await api.get("meals/stats")
    }

    func shoppingList(mealId: UInt) async throws -> ShoppingList {
        try await api.get("meals/\(mealId)/shopping-list")
    }

    func detail(id: UInt) async throws -> MealSession {
        try await api.get("meals/\(id)")
    }

    // 以下变更成功后广播 mealChanged:Tab 页常驻不重建 靠通知同步"这一顿"
    // 在 Service 层发 是为了覆盖所有调用入口(首页/菜单/挑菜面板/菜谱详情/评价)

    func create(_ req: MealInput) async throws -> MealSession {
        let m: MealSession = try await api.post("meals/create", body: req)
        AppNotifications.mealChanged()
        return m
    }

    func update(id: UInt, req: MealInput) async throws -> MealSession {
        let m: MealSession = try await api.post("meals/\(id)/update", body: req)
        AppNotifications.mealChanged()
        return m
    }

    func confirm(id: UInt) async throws -> MealSession {
        let m: MealSession = try await api.post("meals/\(id)/confirm")
        AppNotifications.mealChanged()
        return m
    }

    func complete(id: UInt) async throws -> MealSession {
        let m: MealSession = try await api.post("meals/\(id)/complete")
        AppNotifications.mealChanged()
        return m
    }

    func cancel(id: UInt) async throws {
        let _: EmptyResponse = try await api.post("meals/\(id)/cancel")
        AppNotifications.mealChanged()
    }

    func addDish(mealId: UInt, dish: DishInput) async throws -> MealDish {
        let d: MealDish = try await api.post("meals/\(mealId)/dishes/add", body: dish)
        AppNotifications.mealChanged()
        return d
    }

    func removeDish(mealId: UInt, dishId: UInt) async throws {
        let _: EmptyResponse = try await api.post("meals/\(mealId)/dishes/\(dishId)/remove")
        AppNotifications.mealChanged()
    }

    func review(mealId: UInt, _ req: ReviewInput) async throws -> MealReview {
        let r: MealReview = try await api.post("meals/\(mealId)/review", body: req)
        AppNotifications.mealChanged()
        return r
    }
}
