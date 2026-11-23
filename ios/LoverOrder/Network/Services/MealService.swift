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

    // MARK: - 实时画布 REST 读写

    func fetchCanvas(mealId: UInt) async throws -> CanvasSnapshotResponse {
        try await api.get("meals/\(mealId)/canvas")
    }

    func saveCanvas(mealId: UInt, document: CanvasDocument, clientId: String) async throws -> CanvasSnapshotResponse {
        try await api.post(
            "meals/\(mealId)/canvas",
            body: CanvasSaveRequest(document: document.networkSanitized(), clientId: clientId)
        )
    }
}

// MARK: - 实时画布同步协议与 WebSocket 会话

struct CanvasRemoteActor: Codable, Identifiable, Equatable, Hashable {
    let id: UInt
    let nickname: String
    let avatar: String?
    let role: String

    var asAppUser: AppUser {
        AppUser(id: id, nickname: nickname, avatar: avatar)
    }
}

struct CanvasSnapshotResponse: Codable {
    let mealId: UInt
    let revision: Int64
    let document: CanvasDocument?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case mealId = "meal_id"
        case revision
        case document
        case updatedAt = "updated_at"
    }
}

private struct CanvasSaveRequest: Encodable {
    let document: CanvasDocument
    let clientId: String

    enum CodingKeys: String, CodingKey {
        case document
        case clientId = "client_id"
    }
}

struct CanvasOpPayload: Codable {
    var sticker: CanvasSticker? = nil
    var note: CanvasNote? = nil
    var stroke: CanvasStroke? = nil
    var id: String? = nil
    var mealDishId: UInt? = nil
    var background: String? = nil
    var blur: Double? = nil
    var moodFilter: String? = nil
    var customBackgroundURL: String? = nil
    var clearCustomBackgroundURL: Bool? = nil
    var stickers: [CanvasSticker]? = nil
    var notes: [CanvasNote]? = nil
    var document: CanvasDocument? = nil
    var onlyIfEmpty: Bool? = nil

    enum CodingKeys: String, CodingKey {
        case sticker, note, stroke, id
        case mealDishId = "meal_dish_id"
        case background, blur
        case moodFilter = "mood_filter"
        case customBackgroundURL = "custom_background_url"
        case clearCustomBackgroundURL = "clear_custom_background_url"
        case stickers, notes, document
        case onlyIfEmpty = "only_if_empty"
    }

    var uuidValue: UUID? {
        id.flatMap { UUID(uuidString: $0) }
    }

    static func upsertSticker(_ sticker: CanvasSticker) -> CanvasOpPayload {
        CanvasOpPayload(sticker: sticker)
    }

    static func deleteSticker(id: UUID, mealDishID: UInt? = nil) -> CanvasOpPayload {
        CanvasOpPayload(id: id.uuidString, mealDishId: mealDishID)
    }

    static func upsertNote(_ note: CanvasNote) -> CanvasOpPayload {
        CanvasOpPayload(note: note)
    }

    static func deleteNote(id: UUID) -> CanvasOpPayload {
        CanvasOpPayload(id: id.uuidString)
    }

    static func addStroke(_ stroke: CanvasStroke) -> CanvasOpPayload {
        CanvasOpPayload(stroke: stroke)
    }

    static func deleteStroke(id: UUID?) -> CanvasOpPayload {
        CanvasOpPayload(id: id?.uuidString)
    }

    static func updateBackground(
        background: String,
        blur: Double,
        moodFilter: String,
        customBackgroundURL: String?,
        clearCustomBackgroundURL: Bool = false
    ) -> CanvasOpPayload {
        CanvasOpPayload(
            background: background,
            blur: blur,
            moodFilter: moodFilter,
            customBackgroundURL: customBackgroundURL,
            clearCustomBackgroundURL: clearCustomBackgroundURL ? true : nil
        )
    }

    static func batch(stickers: [CanvasSticker]?, notes: [CanvasNote]?) -> CanvasOpPayload {
        CanvasOpPayload(stickers: stickers, notes: notes)
    }

    static func replaceDocument(_ doc: CanvasDocument, onlyIfEmpty: Bool = false) -> CanvasOpPayload {
        CanvasOpPayload(document: doc.networkSanitized(), onlyIfEmpty: onlyIfEmpty ? true : nil)
    }
}

struct CanvasWelcomeMessage: Decodable {
    let type: String
    let mealId: UInt
    let revision: Int64
    let document: CanvasDocument?
    let canEdit: Bool
    let onlineUsers: [CanvasRemoteActor]?

    enum CodingKeys: String, CodingKey {
        case type
        case mealId = "meal_id"
        case revision, document
        case canEdit = "can_edit"
        case onlineUsers = "online_users"
    }
}

struct CanvasPresenceMessage: Decodable {
    let type: String
    let mealId: UInt
    let onlineUsers: [CanvasRemoteActor]

    enum CodingKeys: String, CodingKey {
        case type
        case mealId = "meal_id"
        case onlineUsers = "online_users"
    }
}

struct CanvasAppliedOpMessage: Decodable {
    let type: String
    let mealId: UInt
    let revision: Int64
    let actor: CanvasRemoteActor
    let clientId: String
    let opId: String
    let kind: String
    let payload: CanvasOpPayload

    enum CodingKeys: String, CodingKey {
        case type
        case mealId = "meal_id"
        case revision, actor
        case clientId = "client_id"
        case opId = "op_id"
        case kind, payload
    }
}

struct CanvasSnapshotBroadcastMessage: Decodable {
    let type: String
    let mealId: UInt
    let revision: Int64
    let actor: CanvasRemoteActor?
    let clientId: String
    let document: CanvasDocument?

    enum CodingKeys: String, CodingKey {
        case type
        case mealId = "meal_id"
        case revision, actor
        case clientId = "client_id"
        case document
    }
}

struct CanvasRemoteLivePreview: Decodable, Equatable {
    let type: String
    let mealId: UInt
    let actor: CanvasRemoteActor
    let clientId: String
    let targetKind: String
    let targetId: String
    let position: CanvasPoint?
    let scale: CGFloat?
    let rotationDegrees: Double?
    let activeStroke: CanvasStroke?
    var receivedAt: Date = Date()

    enum CodingKeys: String, CodingKey {
        case type
        case mealId = "meal_id"
        case actor
        case clientId = "client_id"
        case targetKind = "target_kind"
        case targetId = "target_id"
        case position, scale
        case rotationDegrees = "rotation_degrees"
        case activeStroke = "active_stroke"
    }
}

struct CanvasMealSyncMessage: Decodable {
    let type: String
    let mealId: UInt
    let reason: String
    let actorId: UInt?

    enum CodingKeys: String, CodingKey {
        case type
        case mealId = "meal_id"
        case reason
        case actorId = "actor_id"
    }
}

private struct CanvasWSEnvelopeType: Decodable {
    let type: String
    let message: String?
}

private struct OutboundCanvasOpMessage: Encodable {
    let type = "op"
    let clientId: String
    let opId: String
    let kind: String
    let payload: CanvasOpPayload

    enum CodingKeys: String, CodingKey {
        case type
        case clientId = "client_id"
        case opId = "op_id"
        case kind, payload
    }
}

private struct OutboundLivePreviewMessage: Encodable {
    let type = "live_preview"
    let clientId: String
    let targetKind: String
    let targetId: String
    let position: CanvasPoint?
    let scale: CGFloat?
    let rotationDegrees: Double?
    let activeStroke: CanvasStroke?

    enum CodingKeys: String, CodingKey {
        case type
        case clientId = "client_id"
        case targetKind = "target_kind"
        case targetId = "target_id"
        case position, scale
        case rotationDegrees = "rotation_degrees"
        case activeStroke = "active_stroke"
    }
}

@MainActor
final class CanvasRealtimeSession: ObservableObject {
    @Published var isConnected: Bool = false
    @Published var onlineUsers: [CanvasRemoteActor] = []
    @Published var remotePreviews: [String: CanvasRemoteLivePreview] = [:]

    var currentRevision: Int64 = 0
    let clientID: String = UUID().uuidString

    var onWelcome: ((CanvasWelcomeMessage) -> Void)?
    var onSnapshot: ((CanvasSnapshotBroadcastMessage) -> Void)?
    var onOpApplied: ((CanvasAppliedOpMessage) -> Void)?
    var onMealSync: ((CanvasMealSyncMessage) -> Void)?
    var onError: ((String) -> Void)?

    private let decoder = APIClient.makeDecoder()
    private let encoder = APIClient.makeEncoder()
    private var activeMealId: UInt?
    private var shouldStayConnected = false
    private var socketTask: URLSessionWebSocketTask?
    private var receiveTask: Task<Void, Never>?
    private var pingTask: Task<Void, Never>?
    private var reconnectTask: Task<Void, Never>?
    private var staleCleanupTask: Task<Void, Never>?
    private var reconnectAttempt = 0
    private var lastPreviewSentAt: Date = .distantPast
    private var pendingOps: [(kind: String, payload: CanvasOpPayload)] = []

    func connect(mealId: UInt) {
        if activeMealId == mealId && shouldStayConnected && socketTask != nil {
            return
        }
        disconnect()
        activeMealId = mealId
        shouldStayConnected = true
        reconnectAttempt = 0
        openSocket(mealId: mealId)
        startStaleCleanupLoop()
    }

    func ensureConnected(mealId: UInt) {
        if activeMealId == mealId && shouldStayConnected {
            if !isConnected && reconnectTask == nil && socketTask == nil {
                openSocket(mealId: mealId)
            }
        } else {
            connect(mealId: mealId)
        }
    }

    func disconnect() {
        shouldStayConnected = false
        activeMealId = nil
        reconnectTask?.cancel(); reconnectTask = nil
        pingTask?.cancel(); pingTask = nil
        receiveTask?.cancel(); receiveTask = nil
        staleCleanupTask?.cancel(); staleCleanupTask = nil
        socketTask?.cancel(with: .normalClosure, reason: nil)
        socketTask = nil
        isConnected = false
        onlineUsers = []
        remotePreviews = [:]
        pendingOps.removeAll()
    }

    func sendOp(kind: String, payload: CanvasOpPayload) {
        guard activeMealId != nil else { return }
        let msg = OutboundCanvasOpMessage(
            clientId: clientID,
            opId: UUID().uuidString,
            kind: kind,
            payload: payload
        )
        guard isConnected, let task = socketTask,
              let data = try? encoder.encode(msg),
              let text = String(data: data, encoding: .utf8) else {
            enqueuePendingOp(kind: kind, payload: payload)
            return
        }
        let mealId = activeMealId
        Task { [weak self] in
            do {
                try await task.send(.string(text))
            } catch {
                guard let self else { return }
                self.enqueuePendingOp(kind: kind, payload: payload)
                if let mealId {
                    self.handleSocketClosed(task: task, mealId: mealId)
                }
            }
        }
    }

    func drainPendingOps() -> [(kind: String, payload: CanvasOpPayload)] {
        let ops = pendingOps
        pendingOps.removeAll()
        return ops
    }

    private func enqueuePendingOp(kind: String, payload: CanvasOpPayload) {
        if kind == "replace_document" && payload.onlyIfEmpty == true {
            return
        }
        pendingOps.append((kind: kind, payload: payload))
        if pendingOps.count > 100 {
            pendingOps.removeFirst(pendingOps.count - 100)
        }
    }

    func sendLivePreview(
        targetKind: String,
        targetId: String = "",
        position: CanvasPoint? = nil,
        scale: CGFloat? = nil,
        rotationDegrees: Double? = nil,
        activeStroke: CanvasStroke? = nil
    ) {
        guard isConnected, let task = socketTask else { return }
        let now = Date()
        if targetKind != "clear" && now.timeIntervalSince(lastPreviewSentAt) < 0.06 {
            return
        }
        lastPreviewSentAt = now
        let msg = OutboundLivePreviewMessage(
            clientId: clientID,
            targetKind: targetKind,
            targetId: targetId,
            position: position,
            scale: scale,
            rotationDegrees: rotationDegrees,
            activeStroke: activeStroke
        )
        guard let data = try? encoder.encode(msg),
              let text = String(data: data, encoding: .utf8) else { return }
        Task {
            try? await task.send(.string(text))
        }
    }

    private func openSocket(mealId: UInt) {
        guard shouldStayConnected, activeMealId == mealId,
              let url = APIConfig.webSocketURL(path: "meals/\(mealId)/canvas/ws", query: ["client_id": clientID]) else {
            return
        }
        var request = URLRequest(url: url)
        if let token = TokenStorage.shared.access, !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let task = URLSession.shared.webSocketTask(with: request)
        socketTask = task
        task.resume()
        startReceiveLoop(task: task, mealId: mealId)
        startPingLoop(task: task, mealId: mealId)
    }

    private func startReceiveLoop(task: URLSessionWebSocketTask, mealId: UInt) {
        receiveTask?.cancel()
        receiveTask = Task { [weak self] in
            while let self, !Task.isCancelled {
                do {
                    let message = try await task.receive()
                    guard self.socketTask === task, self.shouldStayConnected, self.activeMealId == mealId else {
                        return
                    }
                    let data: Data
                    switch message {
                    case .string(let s):
                        data = Data(s.utf8)
                    case .data(let d):
                        data = d
                    @unknown default:
                        continue
                    }
                    self.handleInboundData(data)
                } catch {
                    self.handleSocketClosed(task: task, mealId: mealId)
                    return
                }
            }
        }
    }

    private func startPingLoop(task: URLSessionWebSocketTask, mealId: UInt) {
        pingTask?.cancel()
        pingTask = Task { [weak self] in
            while let self, !Task.isCancelled {
                try? await Task.sleep(for: .seconds(20))
                guard !Task.isCancelled, self.socketTask === task, self.shouldStayConnected, self.activeMealId == mealId else {
                    return
                }
                do {
                    try await task.send(.string("{\"type\":\"ping\"}"))
                } catch {
                    self.handleSocketClosed(task: task, mealId: mealId)
                    return
                }
            }
        }
    }

    private func startStaleCleanupLoop() {
        staleCleanupTask?.cancel()
        staleCleanupTask = Task { [weak self] in
            while let self, !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled, self.shouldStayConnected else { return }
                let cutoff = Date().addingTimeInterval(-1.8)
                self.remotePreviews = self.remotePreviews.filter { $0.value.receivedAt > cutoff }
            }
        }
    }

    private func handleSocketClosed(task: URLSessionWebSocketTask, mealId: UInt) {
        guard socketTask === task else { return }
        socketTask = nil
        pingTask?.cancel(); pingTask = nil
        receiveTask?.cancel(); receiveTask = nil
        isConnected = false
        remotePreviews = [:]

        guard shouldStayConnected, activeMealId == mealId, TokenStorage.shared.isLoggedIn else { return }
        scheduleReconnect(mealId: mealId)
    }

    private func scheduleReconnect(mealId: UInt) {
        reconnectTask?.cancel()
        let delays = [1, 2, 4, 8]
        let delaySeconds = delays[min(reconnectAttempt, delays.count - 1)]
        reconnectAttempt += 1
        reconnectTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delaySeconds))
            guard let self, !Task.isCancelled, self.shouldStayConnected, self.activeMealId == mealId else {
                return
            }
            self.reconnectTask = nil
            self.openSocket(mealId: mealId)
        }
    }

    private func handleInboundData(_ data: Data) {
        guard let env = try? decoder.decode(CanvasWSEnvelopeType.self, from: data) else { return }
        switch env.type {
        case "welcome":
            guard let msg = try? decoder.decode(CanvasWelcomeMessage.self, from: data) else { return }
            isConnected = true
            reconnectAttempt = 0
            currentRevision = msg.revision
            onlineUsers = msg.onlineUsers ?? []
            onWelcome?(msg)
        case "presence":
            guard let msg = try? decoder.decode(CanvasPresenceMessage.self, from: data) else { return }
            onlineUsers = msg.onlineUsers
        case "op_applied":
            guard let msg = try? decoder.decode(CanvasAppliedOpMessage.self, from: data) else { return }
            currentRevision = max(currentRevision, msg.revision)
            onOpApplied?(msg)
        case "snapshot":
            guard let msg = try? decoder.decode(CanvasSnapshotBroadcastMessage.self, from: data) else { return }
            currentRevision = max(currentRevision, msg.revision)
            onSnapshot?(msg)
        case "live_preview":
            guard var msg = try? decoder.decode(CanvasRemoteLivePreview.self, from: data),
                  msg.clientId != clientID else { return }
            if msg.targetKind == "clear" {
                remotePreviews.removeValue(forKey: msg.clientId)
            } else {
                msg.receivedAt = Date()
                remotePreviews[msg.clientId] = msg
            }
        case "meal_sync":
            guard let msg = try? decoder.decode(CanvasMealSyncMessage.self, from: data) else { return }
            onMealSync?(msg)
        case "error":
            if let message = env.message, !message.isEmpty {
                onError?(message)
            }
        default:
            break
        }
    }
}
