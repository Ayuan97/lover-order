import Foundation

// 聚餐模式 临时多人点同一顿 不改自己的 household 归属
final class DiningService {
    static let shared = DiningService()
    private let api = APIClient.shared

    // host 在自己家的某一顿上开聚餐 返回带房间号的这一顿
    func open(mealId: UInt) async throws -> MealSession {
        try await api.post("meals/\(mealId)/dining/open")
    }

    // host 关闭聚餐
    func close(mealId: UInt) async throws {
        let _: EmptyResponse = try await api.post("meals/\(mealId)/dining/close")
    }

    // 访客按房间号加入
    func join(roomCode: String) async throws -> MealSession {
        try await api.post("dining/join", body: ["room_code": roomCode])
    }

    // 访客当前参与中的聚餐 没有则 nil
    func current() async throws -> MealSession? {
        do {
            return try await api.get("dining/current")
        } catch APIError.noData {
            return nil
        }
    }

    // 访客离开聚餐
    func leave(mealId: UInt) async throws {
        let _: EmptyResponse = try await api.post("dining/\(mealId)/leave")
    }

    // 聚餐里点菜
    func addDish(mealId: UInt, dish: DishInput) async throws -> MealSession {
        try await api.post("dining/\(mealId)/dishes/add", body: dish)
    }

    // 聚餐里移除自己点的菜
    func removeDish(mealId: UInt, dishId: UInt) async throws {
        let _: EmptyResponse = try await api.post("dining/\(mealId)/dishes/\(dishId)/remove")
    }

    // 聚餐可点的菜 即召集者家的菜单 参与者共用
    func recipes(mealId: UInt, keyword: String = "") async throws -> [Recipe] {
        let q: [String: String] = keyword.isEmpty ? [:] : ["keyword": keyword]
        return try await api.get("dining/\(mealId)/recipes", query: q)
    }
}
