import Foundation

struct StickerFavorite: Decodable, Identifiable {
    let id: UInt
    let image: String
}

final class StickerFavoriteService {
    static let shared = StickerFavoriteService()
    private let api = APIClient.shared

    func list() async throws -> [StickerFavorite] {
        try await api.get("sticker-favorites/list")
    }

    func save(image: String) async throws -> StickerFavorite {
        try await api.post("sticker-favorites/create", body: ["image": image])
    }

    func delete(id: UInt) async throws {
        let _: EmptyResponse = try await api.post("sticker-favorites/\(id)/delete")
    }
}
