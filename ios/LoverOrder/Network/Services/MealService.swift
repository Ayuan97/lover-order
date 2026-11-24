import Foundation
import Network

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

struct DishImageUpdateInput: Encodable {
    var image: String
    var cutoutImage: String?
    var saveToGallery: Bool = true
    var setAsCover: Bool = false

    enum CodingKeys: String, CodingKey {
        case image
        case cutoutImage = "cutout_image"
        case saveToGallery = "save_to_gallery"
        case setAsCover = "set_as_cover"
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

    func updateShoppingChecked(mealId: UInt, checkedItems: [String]) async throws -> [String] {
        struct Body: Encodable {
            let checkedItems: [String]
            enum CodingKeys: String, CodingKey { case checkedItems = "checked_items" }
        }
        struct Result: Decodable {
            let checkedItems: [String]
            enum CodingKeys: String, CodingKey { case checkedItems = "checked_items" }
        }
        let res: Result = try await api.post("meals/\(mealId)/shopping-list/check", body: Body(checkedItems: checkedItems))
        return res.checkedItems
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

    func updateDishImage(mealId: UInt, dishId: UInt, _ req: DishImageUpdateInput) async throws -> MealDish {
        let d: MealDish = try await api.post("meals/\(mealId)/dishes/\(dishId)/image", body: req)
        AppNotifications.mealChanged()
        if req.saveToGallery || req.setAsCover {
            AppNotifications.recipesChanged()
        }
        return d
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

struct CanvasElementPatch: Codable {
    let id: UUID
    var mealDishID: UInt? = nil
    var position: CanvasPoint? = nil
    var scale: CGFloat? = nil
    var rotationDegrees: Double? = nil
    var layer: Int? = nil
    var effect: CanvasEffect? = nil
    var style: CanvasStickerStyle? = nil
    var text: String? = nil
    var font: CanvasTextFont? = nil
    var color: CanvasTextColor? = nil
    var textStyle: CanvasTextStyle? = nil
    var textEffect: CanvasTextEffect? = nil

    func apply(to sticker: inout CanvasSticker) {
        if let position { sticker.position = position }
        if let scale { sticker.scale = scale }
        if let rotationDegrees { sticker.rotationDegrees = rotationDegrees }
        if let layer { sticker.layer = layer }
        if let effect { sticker.effect = effect }
        if let style { sticker.style = style }
    }

    func apply(to note: inout CanvasNote) {
        if let position { note.position = position }
        if let scale { note.scale = scale }
        if let rotationDegrees { note.rotationDegrees = rotationDegrees }
        if let layer { note.layer = layer }
        if let text { note.text = text }
        if let font { note.font = font }
        if let color { note.color = color }
        if let textStyle { note.textStyle = textStyle }
        if let textEffect { note.textEffect = textEffect }
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
    var stickerIds: [String]? = nil
    var noteIds: [String]? = nil
    var strokeIds: [String]? = nil
    var stickerPatches: [CanvasElementPatch]? = nil
    var notePatches: [CanvasElementPatch]? = nil
    var document: CanvasDocument? = nil
    var onlyIfEmpty: Bool? = nil
    var seedOpIds: [String]? = nil

    enum CodingKeys: String, CodingKey {
        case sticker, note, stroke, id
        case mealDishId = "meal_dish_id"
        case background, blur
        case moodFilter = "mood_filter"
        case customBackgroundURL = "custom_background_url"
        case clearCustomBackgroundURL = "clear_custom_background_url"
        case stickers, notes, document
        case stickerIds = "sticker_ids"
        case noteIds = "note_ids"
        case strokeIds = "stroke_ids"
        case stickerPatches = "sticker_patches"
        case notePatches = "note_patches"
        case onlyIfEmpty = "only_if_empty"
        case seedOpIds = "seed_op_ids"
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

    static func batch(stickers: [CanvasSticker]?, notes: [CanvasNote]?) -> CanvasOpPayload {
        CanvasOpPayload(stickers: stickers, notes: notes)
    }

    static func batchUpsert(stickers: [CanvasSticker]? = nil, notes: [CanvasNote]? = nil) -> CanvasOpPayload {
        CanvasOpPayload(stickers: stickers, notes: notes)
    }

    static func batchDelete(
        stickerIds: [UUID]? = nil,
        noteIds: [UUID]? = nil,
        strokeIds: [UUID]? = nil
    ) -> CanvasOpPayload {
        CanvasOpPayload(
            stickerIds: stickerIds?.map(\.uuidString),
            noteIds: noteIds?.map(\.uuidString),
            strokeIds: strokeIds?.map(\.uuidString)
        )
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
    let opId: String?
    let seedOpIds: [String]?
    let document: CanvasDocument?

    enum CodingKeys: String, CodingKey {
        case type
        case mealId = "meal_id"
        case revision, actor
        case clientId = "client_id"
        case opId = "op_id"
        case seedOpIds = "seed_op_ids"
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
    let revision: Int64?
}

struct QueuedCanvasOp: Codable {
    let opId: String
    let kind: String
    let payload: CanvasOpPayload
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
    var onNetworkRecovered: (() -> Void)?
    var onConnectionLost: (() -> Void)?
    var onError: ((String) -> Void)?

    private enum OutboundQueueItem {
        case op(text: String)
        case livePreview(text: String, isClear: Bool)
    }

    private let decoder = APIClient.makeDecoder()
    private let encoder = APIClient.makeEncoder()
    private var activeMealId: UInt?
    private var opStorageKey: String?
    private var shouldStayConnected = false
    private var socketTask: URLSessionWebSocketTask?
    private var receiveTask: Task<Void, Never>?
    private var pingTask: Task<Void, Never>?
    private var reconnectTask: Task<Void, Never>?
    private var staleCleanupTask: Task<Void, Never>?
    private var probeWatchdogTask: Task<Void, Never>?
    private var sendLoopTask: Task<Void, Never>?
    private var pathMonitor: NWPathMonitor?
    private var lastNetworkState: (satisfied: Bool, interfaceKey: String)?
    private var reconnectAttempt = 0
    private var lastPreviewSentAt: Date = .distantPast
    private var lastInboundAt: Date = .distantPast
    private var lastResyncRequestedAt: Date = .distantPast
    private var pendingOps: [QueuedCanvasOp] = []
    private var seedOpId: String?
    private var outboundQueue: [OutboundQueueItem] = []

    func connect(mealId: UInt, userId: UInt) {
        let storageKey = "meal.canvas.pending.\(userId).\(mealId)"
        if opStorageKey == storageKey && shouldStayConnected && socketTask != nil {
            return
        }
        disconnect()
        activeMealId = mealId
        opStorageKey = storageKey
        if let data = UserDefaults.standard.data(forKey: storageKey) {
            do {
                pendingOps = try decoder.decode([QueuedCanvasOp].self, from: data)
            } catch {
                onError?("读取未同步的画布改动失败")
            }
        }
        shouldStayConnected = true
        reconnectAttempt = 0
        startNetworkMonitor(mealId: mealId, userId: userId)
        openSocket(mealId: mealId)
        startStaleCleanupLoop()
    }

    func ensureConnected(mealId: UInt, userId: UInt, probeIfConnected: Bool = false) {
        guard opStorageKey == "meal.canvas.pending.\(userId).\(mealId)", shouldStayConnected else {
            connect(mealId: mealId, userId: userId)
            return
        }
        if let pendingReconnect = reconnectTask {
            pendingReconnect.cancel()
            reconnectTask = nil
            reconnectAttempt = 0
        }
        guard let task = socketTask else {
            openSocket(mealId: mealId)
            return
        }
        if probeIfConnected {
            if isConnected {
                probeSocketHealth(task: task, mealId: mealId)
            } else {
                // 挂在半路上的连接在回前台/切页时立刻重置重连，不走退避等待
                handleSocketClosed(task: task, mealId: mealId, immediate: true)
            }
        }
    }

    func disconnect() {
        shouldStayConnected = false
        activeMealId = nil
        opStorageKey = nil
        currentRevision = 0
        lastInboundAt = .distantPast
        lastResyncRequestedAt = .distantPast
        stopNetworkMonitor()
        reconnectTask?.cancel(); reconnectTask = nil
        pingTask?.cancel(); pingTask = nil
        receiveTask?.cancel(); receiveTask = nil
        staleCleanupTask?.cancel(); staleCleanupTask = nil
        probeWatchdogTask?.cancel(); probeWatchdogTask = nil
        sendLoopTask?.cancel(); sendLoopTask = nil
        socketTask?.cancel(with: .normalClosure, reason: nil)
        socketTask = nil
        isConnected = false
        onlineUsers = []
        remotePreviews = [:]
        pendingOps.removeAll()
        seedOpId = nil
        outboundQueue.removeAll()
    }

    func sendOp(kind: String, payload: CanvasOpPayload) {
        guard activeMealId != nil else { return }
        let op = QueuedCanvasOp(opId: UUID().uuidString, kind: kind, payload: payload)
        pendingOps.append(op)
        savePendingOps()
        if seedOpId == nil {
            queueForSocket(op)
        }
    }

    func seedCanvas(_ document: CanvasDocument) {
        let op = QueuedCanvasOp(
            opId: UUID().uuidString,
            kind: "replace_document",
            payload: CanvasOpPayload(document: document.networkSanitized(), onlyIfEmpty: true, seedOpIds: pendingOps.map(\.opId))
        )
        seedOpId = op.opId
        queueForSocket(op)
    }

    private func queueForSocket(_ op: QueuedCanvasOp) {
        guard isConnected, socketTask != nil else { return }
        let msg = OutboundCanvasOpMessage(
            clientId: clientID,
            opId: op.opId,
            kind: op.kind,
            payload: op.payload
        )
        do {
            let data = try encoder.encode(msg)
            outboundQueue.append(.op(text: String(decoding: data, as: UTF8.self)))
            ensureSendLoopRunning()
        } catch {
            onError?("准备同步画布改动失败")
        }
    }

    func resendPendingOps() {
        for op in pendingOps {
            queueForSocket(op)
        }
    }

    func allUnconfirmedOps() -> [QueuedCanvasOp] {
        pendingOps
    }

    func waitForCanvasSave(mealId: UInt) async -> Bool {
        let clock = ContinuousClock()
        let deadline = clock.now + .seconds(5)
        while activeMealId == mealId {
            if currentRevision > 0 && seedOpId == nil && pendingOps.isEmpty {
                return true
            }
            guard shouldStayConnected, clock.now < deadline else { return false }
            do {
                try await Task.sleep(for: .milliseconds(100))
            } catch {
                return false
            }
        }
        return false
    }

    private func savePendingOps() {
        guard let opStorageKey else { return }
        if pendingOps.isEmpty {
            UserDefaults.standard.removeObject(forKey: opStorageKey)
        } else {
            do {
                UserDefaults.standard.set(try encoder.encode(pendingOps), forKey: opStorageKey)
            } catch {
                onError?("保存未同步的画布改动失败")
            }
        }
    }

    private func acknowledgeOps(_ opId: String?, seedOpIds: [String] = [], clientId: String) {
        guard clientId == clientID, let opId else { return }
        let confirmed = Set(seedOpIds + [opId])
        let previousCount = pendingOps.count
        pendingOps.removeAll { confirmed.contains($0.opId) }
        if pendingOps.count != previousCount { savePendingOps() }
    }

    func requestResync() {
        guard isConnected, let task = socketTask, let mealId = activeMealId else { return }
        let now = Date()
        guard now.timeIntervalSince(lastResyncRequestedAt) >= 1.0 else { return }
        lastResyncRequestedAt = now
        Task { @MainActor [weak self] in
            do {
                try await task.send(.string("{\"type\":\"resync\"}"))
            } catch {
                self?.handleSocketClosed(task: task, mealId: mealId, immediate: true)
            }
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
        guard isConnected, socketTask != nil else { return }
        let isClear = (targetKind == "clear")
        let now = Date()
        if !isClear && now.timeIntervalSince(lastPreviewSentAt) < 0.06 {
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
        if !isClear, let last = outboundQueue.last, case .livePreview(_, false) = last {
            outboundQueue[outboundQueue.count - 1] = .livePreview(text: text, isClear: false)
        } else {
            outboundQueue.append(.livePreview(text: text, isClear: isClear))
        }
        ensureSendLoopRunning()
    }

    private func ensureSendLoopRunning() {
        guard sendLoopTask == nil else { return }
        sendLoopTask = Task { @MainActor [weak self] in
            defer {
                if !Task.isCancelled { self?.sendLoopTask = nil }
            }
            while let self, !Task.isCancelled, !self.outboundQueue.isEmpty {
                guard self.isConnected, let task = self.socketTask, let mealId = self.activeMealId else {
                    break
                }
                let item = self.outboundQueue.removeFirst()
                let text: String
                switch item {
                case .op(let t):
                    text = t
                case .livePreview(let t, _):
                    text = t
                }
                do {
                    try await task.send(.string(text))
                } catch {
                    self.handleSocketClosed(task: task, mealId: mealId)
                    break
                }
            }
        }
    }

    private func probeSocketHealth(task: URLSessionWebSocketTask, mealId: UInt) {
        let probeStartedAt = Date()
        probeWatchdogTask?.cancel()
        probeWatchdogTask = Task { @MainActor [weak self] in
            do {
                let rev = self?.currentRevision ?? 0
                try await task.send(.string("{\"type\":\"ping\",\"revision\":\(rev)}"))
            } catch {
                self?.handleSocketClosed(task: task, mealId: mealId, immediate: true)
                return
            }
            try? await Task.sleep(for: .seconds(1.5))
            guard let self, !Task.isCancelled,
                  self.socketTask === task, self.shouldStayConnected, self.activeMealId == mealId else {
                return
            }
            if self.lastInboundAt < probeStartedAt {
                print("[CanvasWS] ping watchdog expired on foreground resume, reconnecting meal=\(mealId)")
                task.cancel(with: .goingAway, reason: nil)
                self.handleSocketClosed(task: task, mealId: mealId, immediate: true)
            }
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
                    let rev = self.currentRevision
                    try await task.send(.string("{\"type\":\"ping\",\"revision\":\(rev)}"))
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

    private func startNetworkMonitor(mealId: UInt, userId: UInt) {
        stopNetworkMonitor()
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self, weak monitor] path in
            let satisfied = path.status == .satisfied
            let interfaceKey: String = {
                if path.usesInterfaceType(.wifi) { return "wifi" }
                if path.usesInterfaceType(.cellular) { return "cellular" }
                if path.usesInterfaceType(.wiredEthernet) { return "wired" }
                return "other"
            }()
            Task { @MainActor [weak self, weak monitor] in
                guard let self, let monitor, self.pathMonitor === monitor,
                      self.shouldStayConnected, TokenStorage.shared.isLoggedIn else { return }
                let prev = self.lastNetworkState
                self.lastNetworkState = (satisfied, interfaceKey)
                guard let prev, satisfied, !prev.satisfied || prev.interfaceKey != interfaceKey else {
                    return
                }
                self.reconnectAttempt = 0
                self.ensureConnected(mealId: mealId, userId: userId, probeIfConnected: true)
                self.onNetworkRecovered?()
            }
        }
        pathMonitor = monitor
        monitor.start(queue: DispatchQueue(label: "com.loverorder.canvas.netmon"))
    }

    private func stopNetworkMonitor() {
        pathMonitor?.cancel()
        pathMonitor = nil
        lastNetworkState = nil
    }

    private func handleSocketClosed(task: URLSessionWebSocketTask, mealId: UInt, immediate: Bool = false) {
        guard socketTask === task else { return }
        socketTask = nil
        task.cancel(with: .goingAway, reason: nil)
        pingTask?.cancel(); pingTask = nil
        receiveTask?.cancel(); receiveTask = nil
        probeWatchdogTask?.cancel(); probeWatchdogTask = nil
        sendLoopTask?.cancel(); sendLoopTask = nil

        outboundQueue.removeAll()
        seedOpId = nil
        let wasConnected = isConnected
        isConnected = false
        remotePreviews = [:]
        if wasConnected { onConnectionLost?() }

        guard shouldStayConnected, activeMealId == mealId, TokenStorage.shared.isLoggedIn else { return }
        if immediate {
            reconnectTask?.cancel()
            reconnectTask = nil
            reconnectAttempt = 0
            openSocket(mealId: mealId)
        } else {
            scheduleReconnect(mealId: mealId)
        }
    }

    private func scheduleReconnect(mealId: UInt) {
        reconnectTask?.cancel()
        let delays = [1, 2, 4, 8]
        let attempt = reconnectAttempt
        let delaySeconds = delays[min(attempt, delays.count - 1)]
        reconnectAttempt += 1
        reconnectTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delaySeconds))
            guard let self, !Task.isCancelled, self.shouldStayConnected, self.activeMealId == mealId else {
                return
            }
            if attempt == 2 {
                _ = await APIClient.shared.refreshAccessTokenIfNeeded()
                guard !Task.isCancelled, self.shouldStayConnected, self.activeMealId == mealId else {
                    return
                }
            }
            self.reconnectTask = nil
            self.openSocket(mealId: mealId)
        }
    }

    private func handleInboundData(_ data: Data) {
        lastInboundAt = Date()
        probeWatchdogTask?.cancel()
        probeWatchdogTask = nil

        let env: CanvasWSEnvelopeType
        do {
            env = try decoder.decode(CanvasWSEnvelopeType.self, from: data)
        } catch {
            print("[CanvasWS] decode envelope failed: \(error)")
            return
        }

        switch env.type {
        case "pong":
            if let serverRev = env.revision, serverRev > currentRevision {
                requestResync()
            }
        case "welcome":
            do {
                let msg = try decoder.decode(CanvasWelcomeMessage.self, from: data)
                isConnected = true
                reconnectAttempt = 0
                currentRevision = msg.revision
                onlineUsers = msg.onlineUsers ?? []
                onWelcome?(msg)
            } catch {
                print("[CanvasWS] decode welcome failed: \(error)")
                onError?("画布同步解析失败，请稍后重试")
            }
        case "presence":
            do {
                let msg = try decoder.decode(CanvasPresenceMessage.self, from: data)
                onlineUsers = msg.onlineUsers
            } catch {
                print("[CanvasWS] decode presence failed: \(error)")
            }
        case "op_applied":
            do {
                let msg = try decoder.decode(CanvasAppliedOpMessage.self, from: data)
                acknowledgeOps(msg.opId, clientId: msg.clientId)
                guard msg.revision >= currentRevision else { return }
                if msg.revision > currentRevision + 1 {
                    requestResync()
                    return
                }
                currentRevision = msg.revision
                onOpApplied?(msg)
            } catch {
                print("[CanvasWS] decode op_applied failed: \(error)")
                requestResync()
            }
        case "snapshot":
            do {
                let msg = try decoder.decode(CanvasSnapshotBroadcastMessage.self, from: data)
                acknowledgeOps(msg.opId, seedOpIds: msg.seedOpIds ?? [], clientId: msg.clientId)
                if msg.revision >= currentRevision {
                    currentRevision = msg.revision
                    onSnapshot?(msg)
                }
                if msg.clientId == clientID, let seedOpId, msg.opId == seedOpId {
                    self.seedOpId = nil
                    resendPendingOps()
                }
            } catch {
                print("[CanvasWS] decode snapshot failed: \(error)")
                requestResync()
            }
        case "live_preview":
            do {
                var msg = try decoder.decode(CanvasRemoteLivePreview.self, from: data)
                guard msg.clientId != clientID else { return }
                if msg.targetKind == "clear" {
                    remotePreviews.removeValue(forKey: msg.clientId)
                } else {
                    msg.receivedAt = Date()
                    remotePreviews[msg.clientId] = msg
                }
            } catch {
                print("[CanvasWS] decode live_preview failed: \(error)")
            }
        case "meal_sync":
            do {
                let msg = try decoder.decode(CanvasMealSyncMessage.self, from: data)
                onMealSync?(msg)
            } catch {
                print("[CanvasWS] decode meal_sync failed: \(error)")
            }
        case "error":
            if let message = env.message, !message.isEmpty {
                onError?(message)
            }
        default:
            break
        }
    }
}
