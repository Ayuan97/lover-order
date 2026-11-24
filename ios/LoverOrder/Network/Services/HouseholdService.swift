import Foundation

struct CreateHouseholdRequest: Encodable {
    var name: String?
    var description: String?
}

struct JoinHouseholdRequest: Encodable {
    let code: String
}

struct CreateInviteRequest: Encodable {
    var expiresIn: Int?
    var maxUses: Int?

    enum CodingKeys: String, CodingKey {
        case expiresIn = "expires_in"
        case maxUses = "max_uses"
    }
}

struct HouseholdLaunchCanvasResponse: Decodable {
    let hasCustom: Bool
    let householdId: UInt
    let creatorId: UInt
    let creatorNickname: String
    let canEdit: Bool
    let document: CanvasDocument?
    let motion: String
    let holdSpeed: String
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case hasCustom = "has_custom"
        case householdId = "household_id"
        case creatorId = "creator_id"
        case creatorNickname = "creator_nickname"
        case canEdit = "can_edit"
        case document
        case motion
        case holdSpeed = "hold_speed"
        case updatedAt = "updated_at"
    }
}

struct SaveLaunchCanvasRequest: Encodable {
    let document: CanvasDocument
    let motion: String
    let holdSpeed: String

    enum CodingKeys: String, CodingKey {
        case document
        case motion
        case holdSpeed = "hold_speed"
    }
}

final class HouseholdService {
    static let shared = HouseholdService()
    private let api = APIClient.shared

    func create(_ req: CreateHouseholdRequest) async throws -> Household {
        try await api.post("household/create", body: req)
    }

    func info() async throws -> Household {
        try await api.get("household/info")
    }

    func join(code: String) async throws -> Household {
        try await api.post("household/join", body: JoinHouseholdRequest(code: code))
    }

    func leave() async throws {
        let _: EmptyResponse = try await api.post("household/leave")
    }

    func createInvite(_ req: CreateInviteRequest = .init()) async throws -> HouseholdInvite {
        try await api.post("household/invite", body: req)
    }

    func invitations() async throws -> [HouseholdInvite] {
        try await api.get("household/invitations")
    }

    func fetchLaunchCanvas() async throws -> HouseholdLaunchCanvasResponse {
        try await api.get("household/launch-canvas")
    }

    func saveLaunchCanvas(_ req: SaveLaunchCanvasRequest) async throws -> HouseholdLaunchCanvasResponse {
        try await api.post("household/launch-canvas", body: req)
    }
}
