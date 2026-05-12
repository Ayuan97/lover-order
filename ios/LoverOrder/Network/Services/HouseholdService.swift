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
}
