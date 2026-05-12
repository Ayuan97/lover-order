import Foundation

struct CategoryInput: Encodable {
    var name: String
    var icon: String?
    var color: String?
    var sortOrder: Int?

    enum CodingKeys: String, CodingKey {
        case name
        case icon
        case color
        case sortOrder = "sort_order"
    }
}

final class CategoryService {
    static let shared = CategoryService()
    private let api = APIClient.shared

    func list() async throws -> [RecipeCategory] {
        try await api.get("categories/list")
    }

    func create(_ req: CategoryInput) async throws -> RecipeCategory {
        try await api.post("categories/create", body: req)
    }

    func update(id: UInt, req: CategoryInput) async throws -> RecipeCategory {
        try await api.post("categories/\(id)/update", body: req)
    }

    func delete(id: UInt) async throws {
        let _: EmptyResponse = try await api.post("categories/\(id)/delete")
    }
}
