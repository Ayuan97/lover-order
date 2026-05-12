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

    func detail(id: UInt) async throws -> MealSession {
        try await api.get("meals/\(id)")
    }

    func create(_ req: MealInput) async throws -> MealSession {
        try await api.post("meals/create", body: req)
    }

    func update(id: UInt, req: MealInput) async throws -> MealSession {
        try await api.post("meals/\(id)/update", body: req)
    }

    func confirm(id: UInt) async throws -> MealSession {
        try await api.post("meals/\(id)/confirm")
    }

    func complete(id: UInt) async throws -> MealSession {
        try await api.post("meals/\(id)/complete")
    }

    func cancel(id: UInt) async throws {
        let _: EmptyResponse = try await api.post("meals/\(id)/cancel")
    }

    func addDish(mealId: UInt, dish: DishInput) async throws -> MealDish {
        try await api.post("meals/\(mealId)/dishes/add", body: dish)
    }

    func removeDish(mealId: UInt, dishId: UInt) async throws {
        let _: EmptyResponse = try await api.post("meals/\(mealId)/dishes/\(dishId)/remove")
    }

    func review(mealId: UInt, _ req: ReviewInput) async throws -> MealReview {
        try await api.post("meals/\(mealId)/review", body: req)
    }
}
