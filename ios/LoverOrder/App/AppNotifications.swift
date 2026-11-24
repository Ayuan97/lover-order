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

// MARK: - 外链路由与深链解析 (lo://home/..., lo://room/..., lo://meal/..., lo://history/..., lo://household)

enum AppDeepLink: Equatable {
    case home(code: String)
    case room(code: String)
    case meal(mealId: UInt?)
    case history(mealId: UInt)
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
        case "household":
            return .household
        default:
            return nil
        }
    }
}

// MARK: - 通知事件模型与偏好

struct AppNotificationEvent: Codable, Identifiable, Equatable {
    let id: UInt
    let userId: UInt
    let actorId: UInt?
    let householdId: UInt?
    let kind: String
    let title: String
    let body: String
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
        case kind, title, body
        case mealId = "meal_id"
        case roomCode = "room_code"
        case deepLink = "deep_link"
        case isRead = "is_read"
        case readAt = "read_at"
        case createdAt = "created_at"
        case actor
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
        case "meal_dish_added", "meal_confirmed", "dining_joined", "dining_dish_added":
            return .meal(mealId: mealId)
        default:
            if let mealId, mealId > 0 { return .meal(mealId: mealId) }
            return .meal(mealId: nil)
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

struct NotificationPreferences: Codable, Equatable {
    var notifyPartnerMealEvents: Bool = true
    var notifyReviews: Bool = true
    var notifyDining: Bool = true
    var lunchReminderEnabled: Bool = false
    var lunchHour: Int = 11
    var lunchMinute: Int = 30
    var dinnerReminderEnabled: Bool = false
    var dinnerHour: Int = 17
    var dinnerMinute: Int = 30

    static let `default` = NotificationPreferences()

    var mutedKinds: [String] {
        ["meal_dish_added", "meal_confirmed", "meal_completed", "meal_reviewed",
         "dining_joined", "dining_dish_added", "household_joined"].filter { !shouldNotify(kind: $0) }
    }

    func shouldNotify(kind: String) -> Bool {
        switch kind {
        case "meal_dish_added", "meal_confirmed", "meal_completed":
            return notifyPartnerMealEvents
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

        enum CodingKeys: String, CodingKey {
            case token, platform, environment
            case deviceId = "device_id"
            case appVersion = "app_version"
            case mutedKinds = "muted_kinds"
        }
    }

    func registerDevice(token: String, environment: String, appVersion: String, mutedKinds: [String]) async throws {
        let _: NotificationAck = try await api.post(
            "devices/register",
            body: RegisterBody(
                token: token,
                deviceId: DeviceIdentity.shared.deviceID,
                platform: "ios",
                environment: environment,
                appVersion: appVersion,
                mutedKinds: mutedKinds
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
}

// MARK: - AppDelegate 与通知管理器（APNs 远端令牌 + 服务端通知流本地兜底 + 每日饭点提醒）

final class LoverAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
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

    private var activeUserId: UInt?
    private var activeViewedMealId: UInt?
    private var pollTask: Task<Void, Never>?
    private var pendingTappedLink: AppDeepLink?
    private var presentedBannerIds: Set<UInt> = []
    private var apnsToken: String?
    private var registrationTask: Task<Void, Never>?
    private var registeredDevice: DeviceRegistration?

    private struct DeviceRegistration: Equatable {
        let userId: UInt
        let token: String
        let mutedKinds: [String]
    }

    private var canPresentNotifications: Bool {
        authorizationStatus == .authorized || authorizationStatus == .provisional
    }

    private override init() {
        if let data = UserDefaults.standard.data(forKey: Self.prefsStorageKey),
           let decoded = try? JSONDecoder().decode(NotificationPreferences.self, from: data) {
            self.prefs = decoded
        } else {
            self.prefs = .default
        }
        super.init()
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
        mutate(&prefs)
        if let data = try? JSONEncoder().encode(prefs) {
            UserDefaults.standard.set(data, forKey: Self.prefsStorageKey)
        }
        syncMealtimeReminders()
        if prefs.mutedKinds != previousMutedKinds {
            queueDeviceRegistration()
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
        guard let userId = activeUserId, !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }

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
            guard matchedIds.contains(old.id) else { return old }
            return AppNotificationEvent(
                id: old.id, userId: old.userId, actorId: old.actorId, householdId: old.householdId,
                kind: old.kind, title: old.title, body: old.body, mealId: old.mealId,
                roomCode: old.roomCode, deepLink: old.deepLink, isRead: true, readAt: old.readAt ?? now,
                createdAt: old.createdAt, actor: old.actor
            )
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
            let old = events[idx]
            events[idx] = AppNotificationEvent(
                id: old.id, userId: old.userId, actorId: old.actorId, householdId: old.householdId,
                kind: old.kind, title: old.title, body: old.body, mealId: old.mealId,
                roomCode: old.roomCode, deepLink: old.deepLink, isRead: true, readAt: Date(),
                createdAt: old.createdAt, actor: old.actor
            )
            updateUnreadCount(max(0, unreadCount - 1))
        }
        UNUserNotificationCenter.current().removeDeliveredNotifications(
            withIdentifiers: ["loverorder.event.\(event.id)"]
        )
        try? await NotificationService.shared.markRead(eventId: event.id)
    }

    func markAllRead() async {
        let unreadIds = events.filter { !$0.isRead }.map { "loverorder.event.\($0.id)" }
        events = events.map { old in
            AppNotificationEvent(
                id: old.id, userId: old.userId, actorId: old.actorId, householdId: old.householdId,
                kind: old.kind, title: old.title, body: old.body, mealId: old.mealId,
                roomCode: old.roomCode, deepLink: old.deepLink, isRead: true, readAt: old.readAt ?? Date(),
                createdAt: old.createdAt, actor: old.actor
            )
        }
        updateUnreadCount(0)
        if !unreadIds.isEmpty {
            UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: unreadIds)
        } else {
            UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        }
        try? await NotificationService.shared.markRead(eventId: 0)
    }

    // 体验与验收用：写入一条服务端通知，并立即弹出一条真系统本地横幅（点击可跳转）
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

    // 每日午饭/晚饭前本地定时提醒
    func syncMealtimeReminders() {
        let center = UNUserNotificationCenter.current()
        let ids = ["loverorder.mealtime.lunch", "loverorder.mealtime.dinner"]
        center.removePendingNotificationRequests(withIdentifiers: ids)

        if prefs.lunchReminderEnabled {
            scheduleDailyReminder(
                identifier: ids[0],
                hour: prefs.lunchHour,
                minute: prefs.lunchMinute,
                title: "快到午饭时间啦",
                body: "去看看「这一顿」画布，选几道想吃的菜吧"
            )
        }
        if prefs.dinnerReminderEnabled {
            scheduleDailyReminder(
                identifier: ids[1],
                hour: prefs.dinnerHour,
                minute: prefs.dinnerMinute,
                title: "晚饭要吃点什么？",
                body: "打开画布和 Ta 一起商量今晚吃什么"
            )
        }
    }

    // MARK: - UNUserNotificationCenterDelegate

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let info = notification.request.content.userInfo
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
        let info = response.notification.request.content.userInfo
        let deepLinkRaw = info["deep_link"] as? String
        let kindRaw = info["kind"] as? String
        let eventId = (info["event_id"] as? NSNumber)?.uintValue
        let mealId = (info["meal_id"] as? NSNumber)?.uintValue

        Task { @MainActor in
            NotificationManager.shared.handleNotificationTap(
                deepLinkRaw: deepLinkRaw,
                kindRaw: kindRaw,
                eventId: eventId,
                mealId: mealId
            )
        }
        completionHandler()
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
                let device = DeviceRegistration(userId: userId, token: token, mutedKinds: prefs.mutedKinds)
                guard device != registeredDevice else { return }
                do {
                    try await NotificationService.shared.registerDevice(
                        token: token, environment: env, appVersion: version, mutedKinds: device.mutedKinds
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

    private func scheduleLocalBanner(for event: AppNotificationEvent) async throws {
        let content = UNMutableNotificationContent()
        content.title = event.title
        content.body = event.body
        content.sound = .default
        var info: [String: Any] = [
            "event_id": Int(event.id),
            "kind": event.kind
        ]
        if let deepLink = event.deepLink, !deepLink.isEmpty {
            info["deep_link"] = deepLink
        }
        if let mealId = event.mealId {
            info["meal_id"] = Int(mealId)
        }
        content.userInfo = info

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.25, repeats: false)
        let req = UNNotificationRequest(
            identifier: "loverorder.event.\(event.id)",
            content: content,
            trigger: trigger
        )
        try await UNUserNotificationCenter.current().add(req)
    }

    private func scheduleDailyReminder(identifier: String, hour: Int, minute: Int, title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.userInfo = ["deep_link": "lo://meal/0", "kind": "mealtime_reminder"]

        var comps = DateComponents()
        comps.hour = hour
        comps.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        let req = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(req)
    }

    private func updateUnreadCount(_ count: Int) {
        unreadCount = count
        onUnreadCountChange?(count)
        Task {
            try? await UNUserNotificationCenter.current().setBadgeCount(count)
        }
    }
}
