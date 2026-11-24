import Foundation
import UIKit
import UserNotifications

// 跨页面事件 用 NotificationCenter 广播 让独立的 View 各自决定要不要刷新
extension Notification.Name {
    static let recipesChanged = Notification.Name("lover-order.recipes.changed")
    static let mealChanged = Notification.Name("lover-order.meal.changed")
    static let categoriesChanged = Notification.Name("lover-order.categories.changed")
    static let householdChanged = Notification.Name("lover-order.household.changed")
    static let historyChanged = Notification.Name("lover-order.history.changed")
    static let stickerFavoritesChanged = Notification.Name("lover-order.stickerFavorites.changed")
    static let shoppingChanged = Notification.Name("lover-order.shopping.changed")
    static let launchCanvasChanged = Notification.Name("lover-order.launchCanvas.changed")
    static let reconcileCanvasDishes = Notification.Name("lover-order.canvas.reconcileDishes")
    static let sessionExpired = Notification.Name("lover-order.session.expired")
}

enum AppNotifications {
    static func recipesChanged() {
        NotificationCenter.default.post(name: .recipesChanged, object: nil)
    }
    static func sessionExpired() {
        NotificationCenter.default.post(name: .sessionExpired, object: nil)
    }
    static func mealChanged() {
        NotificationCenter.default.post(name: .mealChanged, object: nil)
    }
    static func categoriesChanged() {
        NotificationCenter.default.post(name: .categoriesChanged, object: nil)
    }
    static func householdChanged() {
        NotificationCenter.default.post(name: .householdChanged, object: nil)
    }
    static func historyChanged() {
        NotificationCenter.default.post(name: .historyChanged, object: nil)
    }
    static func stickerFavoritesChanged() {
        NotificationCenter.default.post(name: .stickerFavoritesChanged, object: nil)
    }
    static func shoppingChanged() {
        NotificationCenter.default.post(name: .shoppingChanged, object: nil)
    }
    static func launchCanvasChanged() {
        NotificationCenter.default.post(name: .launchCanvasChanged, object: nil)
    }
    static func reconcileCanvasDishes() {
        NotificationCenter.default.post(name: .reconcileCanvasDishes, object: nil)
    }
}

// MARK: - 外链路由与深链解析 (lo://home/..., lo://room/..., lo://meal/..., lo://history/..., lo://shopping/..., lo://household)

enum AppDeepLink: Equatable {
    case home(code: String)
    case room(code: String)
    case meal(mealId: UInt?)
    case history(mealId: UInt)
    case shopping(mealId: UInt)
    case household

    static func parse(url: URL) -> AppDeepLink? {
        guard url.scheme?.lowercased() == "lo" else { return nil }
        return parse(string: url.absoluteString)
    }

    static func parse(string raw: String) -> AppDeepLink? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let url = URL(string: trimmed),
              url.scheme?.lowercased() == "lo" else {
            return nil
        }

        let host = url.host?.lowercased() ?? ""
        let pathParts = url.pathComponents.filter { $0 != "/" && !$0.isEmpty }

        switch host {
        case "home":
            guard let code = pathParts.first, !code.isEmpty else { return nil }
            return .home(code: code)
        case "room":
            guard let code = pathParts.first, !code.isEmpty else { return nil }
            return .room(code: code)
        case "meal":
            if let first = pathParts.first, let id = UInt(first), id > 0 {
                return .meal(mealId: id)
            }
            return .meal(mealId: nil)
        case "history":
            guard let first = pathParts.first, let id = UInt(first), id > 0 else { return nil }
            return .history(mealId: id)
        case "shopping":
            guard let first = pathParts.first, let id = UInt(first), id > 0 else { return nil }
            return .shopping(mealId: id)
        case "household":
            return .household
        default:
            return nil
        }
    }
}

// MARK: - 通知事件模型与偏好

enum NotificationCategoryID {
    static let dishOrNudge = "MEAL_DISH_OR_NUDGE"
    static let dinner = "MEAL_NUDGE_DINNER"

    static let actionReplyThumbs = "ACTION_REPLY_THUMBS"
    static let actionReplyComing = "ACTION_REPLY_COMING"
    static let actionReplyWashing = "ACTION_REPLY_WASHING"
    static let actionOpenCanvas = "ACTION_OPEN_CANVAS"
}

struct AppNotificationEvent: Codable, Identifiable, Equatable {
    let id: UInt
    let userId: UInt
    let actorId: UInt?
    let householdId: UInt?
    let kind: String
    let presetKey: String?
    let title: String
    let body: String
    let stickerCode: String?
    let imageURL: String?
    let soundName: String?
    let mealId: UInt?
    let roomCode: String?
    let deepLink: String?
    let isRead: Bool
    let readAt: Date?
    let createdAt: Date?
    let actor: AppUser?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case actorId = "actor_id"
        case householdId = "household_id"
        case kind
        case presetKey = "preset_key"
        case title, body
        case stickerCode = "sticker_code"
        case imageURL = "image_url"
        case soundName = "sound_name"
        case mealId = "meal_id"
        case roomCode = "room_code"
        case deepLink = "deep_link"
        case isRead = "is_read"
        case readAt = "read_at"
        case createdAt = "created_at"
        case actor
    }

    func markingRead(at date: Date = Date()) -> AppNotificationEvent {
        AppNotificationEvent(
            id: id,
            userId: userId,
            actorId: actorId,
            householdId: householdId,
            kind: kind,
            presetKey: presetKey,
            title: title,
            body: body,
            stickerCode: stickerCode,
            imageURL: imageURL,
            soundName: soundName,
            mealId: mealId,
            roomCode: roomCode,
            deepLink: deepLink,
            isRead: true,
            readAt: readAt ?? date,
            createdAt: createdAt,
            actor: actor
        )
    }

    var resolvedDeepLink: AppDeepLink? {
        if let deepLink, let parsed = AppDeepLink.parse(string: deepLink) {
            return parsed
        }
        switch kind {
        case "meal_completed", "meal_reviewed":
            if let mealId, mealId > 0 { return .history(mealId: mealId) }
            return .meal(mealId: nil)
        case "household_joined":
            return .household
        case "meal_dish_added", "meal_confirmed", "dining_joined", "dining_dish_added", "meal_nudge", "meal_nudge_reply":
            return .meal(mealId: mealId)
        default:
            if let mealId, mealId > 0 { return .meal(mealId: mealId) }
            return .meal(mealId: nil)
        }
    }

    var stickerAssetName: String? {
        guard let raw = stickerCode?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return nil
        }
        let candidate = raw.hasPrefix("StickerEmoji_") ? raw : "StickerEmoji_\(raw)"
        return UIImage(named: candidate) != nil ? candidate : nil
    }

    var canQuickReply: Bool {
        kind == "meal_nudge" || kind == "meal_dish_added" || kind == "meal_confirmed"
    }

    var quickReplyDefaultCode: String {
        if presetKey == "dinner_ready" || kind == "meal_confirmed" {
            return "washing_hands"
        }
        if kind == "meal_dish_added" {
            return "thumbs_up"
        }
        return "wave_back"
    }

    var quickReplyButtonTitle: String {
        if presetKey == "dinner_ready" || kind == "meal_confirmed" {
            return "马上上桌"
        }
        if kind == "meal_dish_added" {
            return "赞成这道"
        }
        return "回戳 Ta"
    }

    var categoryIdentifier: String? {
        switch kind {
        case "meal_confirmed":
            return NotificationCategoryID.dinner
        case "meal_dish_added", "test":
            return NotificationCategoryID.dishOrNudge
        case "meal_nudge":
            return presetKey == "dinner_ready" ? NotificationCategoryID.dinner : NotificationCategoryID.dishOrNudge
        default:
            return nil
        }
    }

    var iconName: String {
        switch kind {
        case "meal_confirmed": return "checkmark.seal.fill"
        case "meal_dish_added": return "fork.knife"
        case "meal_completed": return "sparkles"
        case "meal_reviewed": return "bubble.left.and.text.bubble.right.fill"
        case "dining_joined", "dining_dish_added": return "person.2.wave.2.fill"
        case "household_joined": return "house.fill"
        case "meal_nudge":
            if presetKey == "dinner_ready" { return "bell.and.waves.left.and.right.fill" }
            if presetKey == "shopping_list" { return "cart.fill" }
            return "hand.wave.fill"
        case "meal_nudge_reply": return "heart.fill"
        default: return "bell.badge.fill"
        }
    }
}

struct NotificationListResult: Decodable {
    enum APNsDelivery: String, Decodable {
        case pending, remote
    }

    let items: [AppNotificationEvent]
    let unreadCount: Int
    let latestId: UInt
    let apnsDeliveries: [String: APNsDelivery]

    enum CodingKeys: String, CodingKey {
        case items
        case unreadCount = "unread_count"
        case latestId = "latest_id"
        case apnsDeliveries = "apns_deliveries"
    }
}

struct NudgeSendResult: Decodable {
    let presetKey: String
    let title: String?
    let body: String?
    let stickerCode: String?
    let soundName: String?
    let deepLink: String?
    let recipientCount: Int

    enum CodingKeys: String, CodingKey {
        case presetKey = "preset_key"
        case title, body
        case stickerCode = "sticker_code"
        case soundName = "sound_name"
        case deepLink = "deep_link"
        case recipientCount = "recipient_count"
    }
}

struct NotificationPreferences: Codable, Equatable {
    var notifyPartnerMealEvents: Bool = true
    var notifyNudges: Bool = true
    var notifyReviews: Bool = true
    var notifyDining: Bool = true
    var useCustomSounds: Bool = true
    var lunchReminderEnabled: Bool = false
    var lunchHour: Int = 11
    var lunchMinute: Int = 30
    var dinnerReminderEnabled: Bool = false
    var dinnerHour: Int = 17
    var dinnerMinute: Int = 30

    static let `default` = NotificationPreferences()

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        notifyPartnerMealEvents = try c.decodeIfPresent(Bool.self, forKey: .notifyPartnerMealEvents) ?? true
        notifyNudges = try c.decodeIfPresent(Bool.self, forKey: .notifyNudges) ?? true
        notifyReviews = try c.decodeIfPresent(Bool.self, forKey: .notifyReviews) ?? true
        notifyDining = try c.decodeIfPresent(Bool.self, forKey: .notifyDining) ?? true
        useCustomSounds = try c.decodeIfPresent(Bool.self, forKey: .useCustomSounds) ?? true
        lunchReminderEnabled = try c.decodeIfPresent(Bool.self, forKey: .lunchReminderEnabled) ?? false
        lunchHour = try c.decodeIfPresent(Int.self, forKey: .lunchHour) ?? 11
        lunchMinute = try c.decodeIfPresent(Int.self, forKey: .lunchMinute) ?? 30
        dinnerReminderEnabled = try c.decodeIfPresent(Bool.self, forKey: .dinnerReminderEnabled) ?? false
        dinnerHour = try c.decodeIfPresent(Int.self, forKey: .dinnerHour) ?? 17
        dinnerMinute = try c.decodeIfPresent(Int.self, forKey: .dinnerMinute) ?? 30
    }

    var mutedKinds: [String] {
        [
            "meal_dish_added", "meal_confirmed", "meal_completed", "meal_reviewed",
            "dining_joined", "dining_dish_added", "household_joined",
            "meal_nudge", "meal_nudge_reply"
        ].filter { !shouldNotify(kind: $0) }
    }

    func shouldNotify(kind: String) -> Bool {
        switch kind {
        case "meal_dish_added", "meal_confirmed", "meal_completed":
            return notifyPartnerMealEvents
        case "meal_nudge", "meal_nudge_reply":
            return notifyNudges
        case "meal_reviewed":
            return notifyReviews
        case "dining_joined", "dining_dish_added", "household_joined":
            return notifyDining
        default:
            return true
        }
    }
}

private struct NotificationAck: Decodable {
    let ok: Bool?
}

private struct NotificationPermissionError: LocalizedError {
    var errorDescription: String? { "请先在系统设置中开启通知权限" }
}

final class NotificationService {
    static let shared = NotificationService()
    private let api = APIClient.shared

    private struct RegisterBody: Encodable {
        let token: String
        let deviceId: String
        let platform: String
        let environment: String
        let appVersion: String
        let mutedKinds: [String]
        let useCustomSound: Bool

        enum CodingKeys: String, CodingKey {
            case token, platform, environment
            case deviceId = "device_id"
            case appVersion = "app_version"
            case mutedKinds = "muted_kinds"
            case useCustomSound = "use_custom_sound"
        }
    }

    private struct NudgeBody: Encodable {
        let preset: String
        let message: String?
        let stickerCode: String?
        let mealId: UInt?
        let targetUserId: UInt?

        enum CodingKeys: String, CodingKey {
            case preset, message
            case stickerCode = "sticker_code"
            case mealId = "meal_id"
            case targetUserId = "target_user_id"
        }
    }

    private struct ReplyBody: Encodable {
        let eventId: UInt
        let replyCode: String
        let mealId: UInt?

        enum CodingKeys: String, CodingKey {
            case eventId = "event_id"
            case replyCode = "reply_code"
            case mealId = "meal_id"
        }
    }

    func registerDevice(
        token: String,
        environment: String,
        appVersion: String,
        mutedKinds: [String],
        useCustomSound: Bool
    ) async throws {
        let _: NotificationAck = try await api.post(
            "devices/register",
            body: RegisterBody(
                token: token,
                deviceId: DeviceIdentity.shared.deviceID,
                platform: "ios",
                environment: environment,
                appVersion: appVersion,
                mutedKinds: mutedKinds,
                useCustomSound: useCustomSound
            )
        )
    }

    func unregisterDevice(token: String) async throws {
        let _: NotificationAck = try await api.post("devices/unregister", body: ["token": token])
    }

    func list(afterId: UInt? = nil, limit: Int = 30) async throws -> NotificationListResult {
        var q: [String: String] = ["limit": "\(limit)"]
        if let afterId {
            q["after_id"] = "\(afterId)"
        }
        return try await api.get(
            "notifications",
            query: q,
            headers: ["X-Notification-Device-ID": DeviceIdentity.shared.deviceID]
        )
    }

    func markRead(eventId: UInt = 0) async throws {
        let _: NotificationAck = try await api.post("notifications/read", body: ["event_id": eventId])
    }

    func sendTest() async throws -> AppNotificationEvent {
        try await api.post("notifications/test")
    }

    func sendNudge(
        preset: String,
        message: String? = nil,
        stickerCode: String? = nil,
        mealId: UInt? = nil,
        targetUserId: UInt? = nil
    ) async throws -> NudgeSendResult {
        try await api.post(
            "notifications/nudge",
            body: NudgeBody(
                preset: preset,
                message: message,
                stickerCode: stickerCode,
                mealId: mealId,
                targetUserId: targetUserId
            )
        )
    }

    func sendReply(
        eventId: UInt = 0,
        replyCode: String,
        mealId: UInt? = nil
    ) async throws -> NudgeSendResult {
        try await api.post(
            "notifications/reply",
            body: ReplyBody(
                eventId: eventId,
                replyCode: replyCode,
                mealId: mealId
            )
        )
    }
}

// MARK: - AppDelegate 与通知管理器（APNs 远端令牌 + 服务端通知流本地兜底 + 富媒体缩略图/快捷回应 + 智能饭点提醒）

final class LoverAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        NotificationManager.registerNotificationCategories()
        UNUserNotificationCenter.current().delegate = NotificationManager.shared
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let hex = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        Task { @MainActor in
            NotificationManager.shared.didReceiveAPNsToken(hex)
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        // 模拟器或无推送签名证书环境下静默回退为本地+轮询提醒通道，不打断用户
    }
}

@MainActor
final class NotificationManager: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()

    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published var events: [AppNotificationEvent] = []
    @Published var unreadCount: Int = 0
    @Published var prefs: NotificationPreferences
    @Published private(set) var isAPNsRegistered = false
    @Published var isSyncing: Bool = false

    var onDeepLink: ((AppDeepLink) -> Void)? {
        didSet {
            if let onDeepLink, let link = pendingTappedLink {
                pendingTappedLink = nil
                onDeepLink(link)
            }
        }
    }
    var onUnreadCountChange: ((Int) -> Void)?

    private static let prefsStorageKey = "loverorder.notification.prefs.v1"
    private static let promptedStorageKey = "loverorder.notification.prompted.v1"
    private static let lastDeliveredPrefix = "loverorder.notification.lastDelivered."
    private static let mealContextStorageKey = "loverorder.notification.mealContext.v1"

    private struct MealReminderContext: Codable, Equatable {
        var mealId: UInt?
        var statusRaw: String?
        var dishNames: [String] = []
        var lastCompletedAt: Date?
    }

    private var activeUserId: UInt?
    private var activeViewedMealId: UInt?
    private var pollTask: Task<Void, Never>?
    private var pendingTappedLink: AppDeepLink?
    private var presentedBannerIds: Set<UInt> = []
    private var apnsToken: String?
    private var registrationTask: Task<Void, Never>?
    private var registeredDevice: DeviceRegistration?
    private var pendingResyncAllowBanner: Bool?
    private var mealContext: MealReminderContext

    private struct DeviceRegistration: Equatable {
        let userId: UInt
        let token: String
        let mutedKinds: [String]
        let useCustomSound: Bool
    }

    private var canPresentNotifications: Bool {
        authorizationStatus == .authorized || authorizationStatus == .provisional
    }

    nonisolated static func registerNotificationCategories() {
        let thumbsAction = UNNotificationAction(
            identifier: NotificationCategoryID.actionReplyThumbs,
            title: "赞成这道菜 👍",
            options: []
        )
        let comingAction = UNNotificationAction(
            identifier: NotificationCategoryID.actionReplyComing,
            title: "收到，马上来 👋",
            options: []
        )
        let washingAction = UNNotificationAction(
            identifier: NotificationCategoryID.actionReplyWashing,
            title: "洗手马上到 🍚",
            options: []
        )
        let openAction = UNNotificationAction(
            identifier: NotificationCategoryID.actionOpenCanvas,
            title: "打开画布看看",
            options: [.foreground]
        )

        let dishOrNudgeCategory = UNNotificationCategory(
            identifier: NotificationCategoryID.dishOrNudge,
            actions: [thumbsAction, comingAction, openAction],
            intentIdentifiers: [],
            options: []
        )
        let dinnerCategory = UNNotificationCategory(
            identifier: NotificationCategoryID.dinner,
            actions: [washingAction, openAction],
            intentIdentifiers: [],
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([dishOrNudgeCategory, dinnerCategory])
    }

    private override init() {
        if let data = UserDefaults.standard.data(forKey: Self.prefsStorageKey),
           let decoded = try? JSONDecoder().decode(NotificationPreferences.self, from: data) {
            self.prefs = decoded
        } else {
            self.prefs = .default
        }
        if let ctxData = UserDefaults.standard.data(forKey: Self.mealContextStorageKey),
           let decodedCtx = try? JSONDecoder().decode(MealReminderContext.self, from: ctxData) {
            self.mealContext = decodedCtx
        } else {
            self.mealContext = MealReminderContext()
        }
        super.init()
        Self.registerNotificationCategories()
        UNUserNotificationCenter.current().delegate = self
    }

    // 登录成功或冷启动恢复登录态后启动推送注册与通知流同步
    func onAuthenticated(userId: UInt) async {
        activeUserId = userId

        await refreshAuthorizationStatus()
        await requestPermissionIfNeededOnce()

        queueDeviceRegistration()
        syncMealtimeReminders()
        await syncServerNotifications()

        startPollingLoop(userId: userId)
    }

    func handleLogout() async {
        pollTask?.cancel()
        pollTask = nil
        activeUserId = nil
        activeViewedMealId = nil
        await registrationTask?.value
        if let token = apnsToken, !token.isEmpty {
            try? await NotificationService.shared.unregisterDevice(token: token)
        }
        registeredDevice = nil
        isAPNsRegistered = false
        presentedBannerIds.removeAll()
        events = []
        updateUnreadCount(0)
    }

    func didReceiveAPNsToken(_ hex: String) {
        apnsToken = hex
        queueDeviceRegistration()
    }

    func updatePreferences(_ mutate: (inout NotificationPreferences) -> Void) {
        let previousMutedKinds = prefs.mutedKinds
        let previousCustomSounds = prefs.useCustomSounds
        mutate(&prefs)
        if let data = try? JSONEncoder().encode(prefs) {
            UserDefaults.standard.set(data, forKey: Self.prefsStorageKey)
        }
        syncMealtimeReminders()
        if prefs.mutedKinds != previousMutedKinds || prefs.useCustomSounds != previousCustomSounds {
            queueDeviceRegistration()
        }
    }

    /// 同步当前餐次上下文供「每日饭点提醒」感知菜单状态（已定下报菜名、刚吃完自动免打扰）
    func updateMealContext(meal: MealSession?, markCompletedNow: Bool = false) {
        var next = mealContext
        if markCompletedNow {
            next.lastCompletedAt = Date()
        }
        if let meal {
            next.mealId = meal.id
            next.statusRaw = meal.status.rawValue
            next.dishNames = (meal.dishes ?? []).map(\.recipeName).filter { !$0.isEmpty }
            if meal.status == .completed, let completedAt = meal.completedAt {
                next.lastCompletedAt = completedAt
            }
        }
        guard next != mealContext else { return }
        mealContext = next
        if let data = try? JSONEncoder().encode(next) {
            UserDefaults.standard.set(data, forKey: Self.mealContextStorageKey)
        }
        if prefs.lunchReminderEnabled || prefs.dinnerReminderEnabled {
            syncMealtimeReminders()
        }
    }

    /// 画布已通过 WebSocket 实时展示了该传呼/回戳时调用，避免轮询再弹一次重复系统横幅
    func noteReceivedCanvasNudge(eventId: UInt) {
        guard eventId > 0 else { return }
        presentedBannerIds.insert(eventId)
        Task {
            try? await NotificationService.shared.markRead(eventId: eventId)
            await syncServerNotifications(allowLocalBanner: false)
        }
    }

    func refreshAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        authorizationStatus = settings.authorizationStatus
        if settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional {
            UIApplication.shared.registerForRemoteNotifications()
            queueDeviceRegistration()
        }
    }

    @discardableResult
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
            await refreshAuthorizationStatus()
            if granted {
                syncMealtimeReminders()
            }
            return granted
        } catch {
            await refreshAuthorizationStatus()
            return false
        }
    }

    func requestPermissionIfNeededOnce() async {
        guard authorizationStatus == .notDetermined else { return }
        guard !UserDefaults.standard.bool(forKey: Self.promptedStorageKey) else { return }
        UserDefaults.standard.set(true, forKey: Self.promptedStorageKey)
        _ = await requestAuthorization()
    }

    func openSystemNotificationSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    // 同步服务端通知事件流，并为新出现的未读事件触发真实系统横幅
    func syncServerNotifications(allowLocalBanner: Bool = true) async {
        guard let userId = activeUserId else { return }
        if isSyncing {
            pendingResyncAllowBanner = (pendingResyncAllowBanner ?? false) || allowLocalBanner
            return
        }
        isSyncing = true
        defer {
            isSyncing = false
            if let nextBanner = pendingResyncAllowBanner, activeUserId == userId {
                pendingResyncAllowBanner = nil
                Task { @MainActor [weak self] in
                    await self?.syncServerNotifications(allowLocalBanner: nextBanner)
                }
            }
        }

        do {
            let result = try await NotificationService.shared.list(limit: 40)
            guard activeUserId == userId else { return }
            events = result.items
            updateUnreadCount(result.unreadCount)
            if UIApplication.shared.applicationState == .active, let viewedMeal = activeViewedMealId {
                await markMealEventsRead(mealId: viewedMeal)
            }
            guard allowLocalBanner else { return }

            let baselineKey = Self.lastDeliveredPrefix + "\(userId)"
            guard let storedID = UserDefaults.standard.object(forKey: baselineKey) as? Int else {
                UserDefaults.standard.set(Int(result.latestId), forKey: baselineKey)
                return
            }

            var deliveredThrough = UInt(storedID)
            guard canPresentNotifications, deliveredThrough < result.latestId else { return }
            let existingBannerIds = await deliveredBannerIds()
            defer { UserDefaults.standard.set(Int(deliveredThrough), forKey: baselineKey) }
            while deliveredThrough < result.latestId {
                let page = try await NotificationService.shared.list(afterId: deliveredThrough, limit: 40)
                guard activeUserId == userId, !page.items.isEmpty else { break }
                for event in page.items {
                    guard activeUserId == userId else { return }
                    let alreadyViewingLiveMeal = UIApplication.shared.applicationState == .active
                        && activeViewedMealId != nil
                        && event.mealId == activeViewedMealId
                        && Self.activeMealEventKinds.contains(event.kind)
                    if event.kind != "test", !event.isRead, !alreadyViewingLiveMeal,
                       prefs.shouldNotify(kind: event.kind),
                       !existingBannerIds.contains(event.id), !presentedBannerIds.contains(event.id) {
                        switch page.apnsDeliveries[String(event.id)] {
                        case .pending:
                            return
                        case .remote:
                            break
                        case nil:
                            try await scheduleLocalBanner(for: event)
                        }
                    }
                    deliveredThrough = event.id
                }
            }
        } catch {
            // 后台轮询静默容错，不弹出网络错误打断使用
        }
    }

    private static let activeMealEventKinds: Set<String> = [
        "meal_dish_added", "meal_confirmed", "dining_joined", "dining_dish_added"
    ]

    /// 记录用户当前正在前台浏览的画布餐次：已在画布亲眼看到的加菜/定下动态自动消掉未读红点
    func setActiveViewedMeal(_ mealId: UInt?) {
        activeViewedMealId = mealId
        if let mealId, mealId > 0 {
            Task { await markMealEventsRead(mealId: mealId) }
        }
    }

    func markMealEventsRead(mealId: UInt) async {
        guard mealId > 0 else { return }
        await markMatchingRead { ev in
            !ev.isRead && ev.mealId == mealId && Self.activeMealEventKinds.contains(ev.kind)
        }
    }

    func markHistoryEventsRead(mealId: UInt? = nil) async {
        await markMatchingRead { ev in
            guard !ev.isRead, (ev.kind == "meal_completed" || ev.kind == "meal_reviewed") else { return false }
            if let mealId, mealId > 0 {
                return ev.mealId == mealId
            }
            return true
        }
    }

    func markHouseholdEventsRead() async {
        await markMatchingRead { ev in
            !ev.isRead && ev.kind == "household_joined"
        }
    }

    private func markMatchingRead(_ predicate: (AppNotificationEvent) -> Bool) async {
        let matched = events.filter(predicate)
        guard !matched.isEmpty else { return }
        let matchedIds = Set(matched.map(\.id))
        let now = Date()
        events = events.map { old in
            matchedIds.contains(old.id) ? old.markingRead(at: now) : old
        }
        updateUnreadCount(max(0, unreadCount - matchedIds.count))
        UNUserNotificationCenter.current().removeDeliveredNotifications(
            withIdentifiers: matchedIds.map { "loverorder.event.\($0)" }
        )
        for id in matchedIds {
            try? await NotificationService.shared.markRead(eventId: id)
        }
    }

    func markRead(event: AppNotificationEvent) async {
        if let idx = events.firstIndex(where: { $0.id == event.id && !$0.isRead }) {
            events[idx] = events[idx].markingRead()
            updateUnreadCount(max(0, unreadCount - 1))
        }
        UNUserNotificationCenter.current().removeDeliveredNotifications(
            withIdentifiers: ["loverorder.event.\(event.id)"]
        )
        try? await NotificationService.shared.markRead(eventId: event.id)
    }

    func markAllRead() async {
        let unreadIds = events.filter { !$0.isRead }.map { "loverorder.event.\($0.id)" }
        let now = Date()
        events = events.map { $0.markingRead(at: now) }
        updateUnreadCount(0)
        if !unreadIds.isEmpty {
            UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: unreadIds)
        } else {
            UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        }
        try? await NotificationService.shared.markRead(eventId: 0)
    }

    // 体验与验收用：写入一条服务端通知，并立即弹出一条含缩略图、音效与下拉快捷回应的真系统横幅
    func sendTestAndDeliverBanner() async throws -> AppNotificationEvent {
        await refreshAuthorizationStatus()
        if authorizationStatus == .notDetermined {
            _ = await requestAuthorization()
        }
        guard canPresentNotifications else { throw NotificationPermissionError() }
        let ev = try await NotificationService.shared.sendTest()
        await syncServerNotifications(allowLocalBanner: false)
        if !(await deliveredBannerIds()).contains(ev.id) {
            try await scheduleLocalBanner(for: ev)
        }
        return ev
    }

    // 每日午饭/晚饭前智能本地定时提醒（感知当前菜单状态，刚吃完时锁屏也跳过当日提醒）
    func syncMealtimeReminders() {
        let center = UNUserNotificationCenter.current()
        let baseIDs = ["loverorder.mealtime.lunch", "loverorder.mealtime.dinner"]
        let skipDayIDs = baseIDs.flatMap { base in (1...14).map { "\(base).day\($0)" } }
        center.removePendingNotificationRequests(withIdentifiers: baseIDs + skipDayIDs)

        let dishSummary = Self.summarizeDishNames(mealContext.dishNames)

        if prefs.lunchReminderEnabled {
            let (title, body, soundFile) = mealtimeReminderCopy(isDinner: false, dishSummary: dishSummary)
            scheduleDailyReminder(
                identifier: baseIDs[0],
                hour: prefs.lunchHour,
                minute: prefs.lunchMinute,
                title: title,
                body: body,
                stickerAsset: "StickerEmoji_food_ramen",
                soundFile: soundFile
            )
        }
        if prefs.dinnerReminderEnabled {
            let (title, body, soundFile) = mealtimeReminderCopy(isDinner: true, dishSummary: dishSummary)
            scheduleDailyReminder(
                identifier: baseIDs[1],
                hour: prefs.dinnerHour,
                minute: prefs.dinnerMinute,
                title: title,
                body: body,
                stickerAsset: "StickerEmoji_food_cheers",
                soundFile: soundFile
            )
        }
    }

    private func mealtimeReminderCopy(isDinner: Bool, dishSummary: String) -> (String, String, String) {
        let mealLabel = isDinner ? "晚饭" : "午饭"
        if mealContext.statusRaw == MealStatus.confirmed.rawValue, !dishSummary.isEmpty {
            return (
                "\(mealLabel)菜单早就定好啦",
                "今天吃「\(dishSummary)」，差不多可以准备开动咯",
                "dinner_chime.caf"
            )
        }
        if mealContext.statusRaw == MealStatus.planning.rawValue, !dishSummary.isEmpty {
            return (
                "桌上有 \(mealContext.dishNames.count) 道候选菜啦",
                "「\(dishSummary)」还在商量中，上画布和 Ta 拍板吧",
                "plate_pop.caf"
            )
        }
        if isDinner {
            return (
                "晚风吹来饭香，今晚吃点啥？",
                "打开「这一顿」画布，抛两道想吃的菜或喊 Ta 一起挑",
                "nudge_boing.caf"
            )
        }
        return (
            "咕咕～快到午饭时间啦",
            "去「这一顿」画布逛逛，选几道今天想吃的菜吧",
            "nudge_boing.caf"
        )
    }

    private static func summarizeDishNames(_ names: [String]) -> String {
        let cleaned = names.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        guard !cleaned.isEmpty else { return "" }
        if cleaned.count <= 3 {
            return cleaned.joined(separator: "、")
        }
        return "\(cleaned.prefix(3).joined(separator: "、")) 等 \(cleaned.count) 道菜"
    }

    // MARK: - UNUserNotificationCenterDelegate

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let reqID = notification.request.identifier
        let info = notification.request.content.userInfo
        if reqID.hasPrefix("loverorder.mealtime.") {
            Task { @MainActor in
                let manager = NotificationManager.shared
                if let lastCompleted = manager.mealContext.lastCompletedAt,
                   Date().timeIntervalSince(lastCompleted) < 2.5 * 3600 {
                    // 刚吃饱不久自动静默跳过当次饭点闹钟，不机械打扰
                    completionHandler([])
                } else {
                    completionHandler([.banner, .list, .sound])
                }
            }
            return
        }
        guard let eventId = (info["event_id"] as? NSNumber)?.uintValue else {
            completionHandler([.banner, .list, .sound, .badge])
            return
        }
        let kind = info["kind"] as? String ?? ""
        let isRemote = notification.request.trigger is UNPushNotificationTrigger
        Task { @MainActor in
            let manager = NotificationManager.shared
            if manager.prefs.shouldNotify(kind: kind), manager.presentedBannerIds.insert(eventId).inserted {
                completionHandler([.banner, .list, .sound, .badge])
            } else {
                completionHandler([])
            }
            if isRemote { await manager.syncServerNotifications() }
        }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let actionID = response.actionIdentifier
        let info = response.notification.request.content.userInfo
        let deepLinkRaw = info["deep_link"] as? String
        let kindRaw = info["kind"] as? String
        let eventId = (info["event_id"] as? NSNumber)?.uintValue
        let mealId = (info["meal_id"] as? NSNumber)?.uintValue

        let silentReplyCode: String? = {
            switch actionID {
            case NotificationCategoryID.actionReplyThumbs:
                return "thumbs_up"
            case NotificationCategoryID.actionReplyComing:
                return "coming"
            case NotificationCategoryID.actionReplyWashing:
                return "washing_hands"
            default:
                return nil
            }
        }()

        if let replyCode = silentReplyCode {
            Task { @MainActor in
                if let eventId, eventId > 0 {
                    NotificationManager.shared.presentedBannerIds.insert(eventId)
                }
                _ = try? await NotificationService.shared.sendReply(
                    eventId: eventId ?? 0,
                    replyCode: replyCode,
                    mealId: mealId
                )
                await NotificationManager.shared.syncServerNotifications(allowLocalBanner: false)
                completionHandler()
            }
            return
        }

        if actionID == UNNotificationDismissActionIdentifier {
            completionHandler()
            return
        }

        Task { @MainActor in
            NotificationManager.shared.handleNotificationTap(
                deepLinkRaw: deepLinkRaw,
                kindRaw: kindRaw,
                eventId: eventId,
                mealId: mealId
            )
            completionHandler()
        }
    }

    private func handleNotificationTap(
        deepLinkRaw: String?,
        kindRaw: String?,
        eventId: UInt?,
        mealId: UInt?
    ) {
        if let eventId, eventId > 0 {
            presentedBannerIds.insert(eventId)
            if let existing = events.first(where: { $0.id == eventId }) {
                Task { await markRead(event: existing) }
            } else {
                Task { try? await NotificationService.shared.markRead(eventId: eventId) }
            }
        }

        if let deepLinkRaw, let link = AppDeepLink.parse(string: deepLinkRaw) {
            openTappedLink(link)
            return
        }

        switch kindRaw {
        case "meal_completed", "meal_reviewed":
            if let mealId, mealId > 0 {
                openTappedLink(.history(mealId: mealId))
            } else {
                openTappedLink(.meal(mealId: nil))
            }
        case "household_joined":
            openTappedLink(.household)
        default:
            openTappedLink(.meal(mealId: mealId))
        }
    }

    private func openTappedLink(_ link: AppDeepLink) {
        if let onDeepLink {
            onDeepLink(link)
        } else {
            pendingTappedLink = link
        }
    }

    private func startPollingLoop(userId: UInt) {
        pollTask?.cancel()
        pollTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(8))
                guard let self, self.activeUserId == userId else { break }
                guard UIApplication.shared.applicationState == .active else { continue }
                self.queueDeviceRegistration()
                await self.syncServerNotifications(allowLocalBanner: true)
            }
        }
    }

    private func queueDeviceRegistration() {
        guard registrationTask == nil, activeUserId != nil, apnsToken != nil, canPresentNotifications else { return }
        #if DEBUG
        let env = "sandbox"
        #else
        let env = "production"
        #endif
        let version = (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "1.0"
        registrationTask = Task {
            defer { registrationTask = nil }
            while let userId = activeUserId, let token = apnsToken, canPresentNotifications {
                let device = DeviceRegistration(
                    userId: userId,
                    token: token,
                    mutedKinds: prefs.mutedKinds,
                    useCustomSound: prefs.useCustomSounds
                )
                guard device != registeredDevice else { return }
                do {
                    try await NotificationService.shared.registerDevice(
                        token: token,
                        environment: env,
                        appVersion: version,
                        mutedKinds: device.mutedKinds,
                        useCustomSound: device.useCustomSound
                    )
                } catch {
                    return
                }
                registeredDevice = device
                isAPNsRegistered = true
            }
        }
    }

    private func deliveredBannerIds() async -> Set<UInt> {
        let notifications = await UNUserNotificationCenter.current().deliveredNotifications()
        return presentedBannerIds.union(notifications.compactMap {
            ($0.request.content.userInfo["event_id"] as? NSNumber)?.uintValue
        })
    }

    private func notificationSound(named rawSound: String?, fallbackKind: String) -> UNNotificationSound {
        guard prefs.useCustomSounds else { return .default }
        let candidate: String = {
            if let s = rawSound?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty {
                return s
            }
            switch fallbackKind {
            case "meal_confirmed", "meal_completed":
                return "dinner_chime.caf"
            case "meal_nudge", "meal_nudge_reply", "dining_joined":
                return "nudge_boing.caf"
            default:
                return "plate_pop.caf"
            }
        }()
        let ns = candidate as NSString
        let ext = ns.pathExtension.isEmpty ? "caf" : ns.pathExtension
        let base = ns.deletingPathExtension
        if Bundle.main.url(forResource: base, withExtension: ext) != nil {
            return UNNotificationSound(named: UNNotificationSoundName("\(base).\(ext)"))
        }
        return .default
    }

    private func scheduleLocalBanner(for event: AppNotificationEvent) async throws {
        // 45 秒内连加菜合并后，清理同餐次同发起人的旧单菜横幅，保持通知栏清爽
        if event.kind == "meal_dish_added" || event.kind == "dining_dish_added",
           let mealId = event.mealId, let actorId = event.actorId {
            let delivered = await UNUserNotificationCenter.current().deliveredNotifications()
            let staleIDs = delivered.compactMap { item -> String? in
                let u = item.request.content.userInfo
                guard (u["kind"] as? String) == event.kind,
                      (u["meal_id"] as? NSNumber)?.uintValue == mealId,
                      (u["actor_id"] as? NSNumber)?.uintValue == actorId else {
                    return nil
                }
                return item.request.identifier
            }
            if !staleIDs.isEmpty {
                UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: staleIDs)
            }
        }

        let content = UNMutableNotificationContent()
        content.title = event.title
        content.body = event.body
        content.sound = notificationSound(named: event.soundName, fallbackKind: event.kind)
        if let cat = event.categoryIdentifier {
            content.categoryIdentifier = cat
        }
        if let mealId = event.mealId, mealId > 0 {
            content.threadIdentifier = "loverorder.meal.\(mealId)"
        }

        if let attachment = await makeBannerAttachment(for: event) {
            content.attachments = [attachment]
        }

        var info: [String: Any] = [
            "event_id": Int(event.id),
            "kind": event.kind
        ]
        if let actorId = event.actorId {
            info["actor_id"] = Int(actorId)
        }
        if let presetKey = event.presetKey, !presetKey.isEmpty {
            info["preset_key"] = presetKey
        }
        if let deepLink = event.deepLink, !deepLink.isEmpty {
            info["deep_link"] = deepLink
        }
        if let mealId = event.mealId {
            info["meal_id"] = Int(mealId)
        }
        content.userInfo = info

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.22, repeats: false)
        let req = UNNotificationRequest(
            identifier: "loverorder.event.\(event.id)",
            content: content,
            trigger: trigger
        )
        try await UNUserNotificationCenter.current().add(req)
    }

    private func scheduleDailyReminder(
        identifier: String,
        hour: Int,
        minute: Int,
        title: String,
        body: String,
        stickerAsset: String,
        soundFile: String
    ) {
        let now = Date()
        let cal = Calendar.current
        var todayComps = cal.dateComponents([.year, .month, .day], from: now)
        todayComps.hour = hour
        todayComps.minute = minute
        let todayFireDate = cal.date(from: todayComps)
        let shouldSkipToday: Bool = {
            guard let fire = todayFireDate, fire > now,
                  let lastCompleted = mealContext.lastCompletedAt else {
                return false
            }
            return fire.timeIntervalSince(lastCompleted) >= 0 && fire.timeIntervalSince(lastCompleted) < 2.5 * 3600
        }()

        if shouldSkipToday {
            // 刚吃完不到 2.5 小时即到提醒点：跳过今天并排入未来 14 天单次提醒，锁屏后台也不打扰
            for dayOffset in 1...14 {
                guard let targetDay = cal.date(byAdding: .day, value: dayOffset, to: now) else { continue }
                let content = UNMutableNotificationContent()
                content.title = title
                content.body = body
                content.sound = notificationSound(named: soundFile, fallbackKind: "mealtime_reminder")
                content.userInfo = ["deep_link": "lo://meal/0", "kind": "mealtime_reminder"]
                if let stickerImage = UIImage(named: stickerAsset),
                   let attachment = Self.writeStickerThumbnailAttachment(image: stickerImage, tag: "\(identifier)-d\(dayOffset)") {
                    content.attachments = [attachment]
                }
                var comps = cal.dateComponents([.year, .month, .day], from: targetDay)
                comps.hour = hour
                comps.minute = minute
                let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
                let req = UNNotificationRequest(identifier: "\(identifier).day\(dayOffset)", content: content, trigger: trigger)
                UNUserNotificationCenter.current().add(req)
            }
            return
        }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = notificationSound(named: soundFile, fallbackKind: "mealtime_reminder")
        content.userInfo = ["deep_link": "lo://meal/0", "kind": "mealtime_reminder"]
        if let stickerImage = UIImage(named: stickerAsset),
           let attachment = Self.writeStickerThumbnailAttachment(image: stickerImage, tag: identifier) {
            content.attachments = [attachment]
        }

        var comps = DateComponents()
        comps.hour = hour
        comps.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        let req = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(req)
    }

    // MARK: - 通知横幅富媒体缩略图合成（菜品抠图白边贴纸 / 实拍图 / 36 枚水粉贴纸）

    private func makeBannerAttachment(for event: AppNotificationEvent) async -> UNNotificationAttachment? {
        Self.pruneStaleAttachmentFiles()

        if let rawURL = event.imageURL, let url = APIConfig.imageURL(rawURL) {
            if let remoteImage = await loadBannerImageWithTimeout(url: url, timeoutSeconds: 1.8) {
                let isCutoutCandidate = rawURL.lowercased().contains("cutout") || rawURL.lowercased().hasSuffix(".png")
                let styled: UIImage
                if isCutoutCandidate {
                    styled = await StickerBorderRenderer.shared.makeDieCutSticker(
                        from: remoteImage,
                        cacheKey: url.absoluteString
                    )
                } else {
                    styled = remoteImage
                }
                if let att = Self.writeStickerThumbnailAttachment(
                    image: styled,
                    tag: "ev-\(event.id)",
                    addCardBackdrop: !isCutoutCandidate
                ) {
                    return att
                }
            }
        }

        if let assetName = event.stickerAssetName, let stickerImage = UIImage(named: assetName) {
            return Self.writeStickerThumbnailAttachment(image: stickerImage, tag: "ev-\(event.id)")
        }
        return nil
    }

    private func loadBannerImageWithTimeout(url: URL, timeoutSeconds: Double) async -> UIImage? {
        if let cached = RemoteImageCache.shared.cachedImage(for: url) {
            return cached
        }
        // RemoteImageCache.load 内部使用非结构化 Task 单飞，这里用 AsyncStream 竞速确保超时后立即放行横幅，不被慢网拖住
        let stream = AsyncStream<UIImage?> { continuation in
            let fetchTask = Task {
                let image = await RemoteImageCache.shared.load(url: url)
                continuation.yield(image)
                continuation.finish()
            }
            let timeoutTask = Task {
                try? await Task.sleep(for: .seconds(timeoutSeconds))
                guard !Task.isCancelled else { return }
                continuation.yield(nil)
                continuation.finish()
            }
            continuation.onTermination = { _ in
                timeoutTask.cancel()
                _ = fetchTask
            }
        }
        for await result in stream {
            return result
        }
        return nil
    }

    private static var attachmentDir: URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("LoverOrderNotifThumbs", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private static func pruneStaleAttachmentFiles() {
        let fm = FileManager.default
        let dir = attachmentDir
        guard let urls = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.creationDateKey]) else {
            return
        }
        let cutoff = Date().addingTimeInterval(-3600)
        for url in urls {
            if let created = (try? url.resourceValues(forKeys: [.creationDateKey]))?.creationDate,
               created < cutoff {
                try? fm.removeItem(at: url)
            }
        }
    }

    private static func writeStickerThumbnailAttachment(
        image: UIImage,
        tag: String,
        addCardBackdrop: Bool = false
    ) -> UNNotificationAttachment? {
        let canvasSide: CGFloat = 240
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = addCardBackdrop

        let rendered = UIGraphicsImageRenderer(size: CGSize(width: canvasSide, height: canvasSide), format: format).image { ctx in
            let bounds = CGRect(x: 0, y: 0, width: canvasSide, height: canvasSide)
            if addCardBackdrop {
                let path = UIBezierPath(roundedRect: bounds, cornerRadius: 36)
                path.addClip()
                let scale = max(canvasSide / max(1, image.size.width), canvasSide / max(1, image.size.height))
                let drawW = image.size.width * scale
                let drawH = image.size.height * scale
                let rect = CGRect(
                    x: (canvasSide - drawW) * 0.5,
                    y: (canvasSide - drawH) * 0.5,
                    width: drawW,
                    height: drawH
                )
                image.draw(in: rect)
            } else {
                let inset: CGFloat = 14
                let avail = canvasSide - inset * 2
                let scale = min(avail / max(1, image.size.width), avail / max(1, image.size.height))
                let drawW = image.size.width * scale
                let drawH = image.size.height * scale
                let rect = CGRect(
                    x: (canvasSide - drawW) * 0.5,
                    y: (canvasSide - drawH) * 0.5,
                    width: drawW,
                    height: drawH
                )
                ctx.cgContext.setShadow(
                    offset: CGSize(width: 0, height: 6),
                    blur: 14,
                    color: UIColor.black.withAlphaComponent(0.18).cgColor
                )
                image.draw(in: rect)
            }
        }

        guard let png = rendered.pngData() else { return nil }
        let safeTag = tag.replacingOccurrences(of: ".", with: "-")
        let fileURL = attachmentDir.appendingPathComponent("\(safeTag)-\(UUID().uuidString.prefix(8)).png")
        do {
            try png.write(to: fileURL, options: .atomic)
            return try UNNotificationAttachment(identifier: "thumb", url: fileURL, options: nil)
        } catch {
            return nil
        }
    }

    private func updateUnreadCount(_ count: Int) {
        unreadCount = count
        onUnreadCountChange?(count)
        Task {
            try? await UNUserNotificationCenter.current().setBadgeCount(count)
        }
    }
}
