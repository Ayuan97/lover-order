import Foundation
import UIKit
import UserNotifications

// 跨页面事件 用 NotificationCenter 广播 让独立的 View 各自决定要不要刷新
extension Notification.Name {
    static let recipesChanged = Notification.Name("lover-order.recipes.changed")
    static let mealChanged = Notification.Name("lover-order.meal.changed")
    static let categoriesChanged = Notification.Name("lover-order.categories.changed")
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
    let items: [AppNotificationEvent]
    let unreadCount: Int
    let latestId: UInt

    enum CodingKeys: String, CodingKey {
        case items
        case unreadCount = "unread_count"
        case latestId = "latest_id"
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

final class NotificationService {
    static let shared = NotificationService()
    private let api = APIClient.shared

    private struct RegisterBody: Encodable {
        let token: String
        let platform: String
        let environment: String
        let appVersion: String

        enum CodingKeys: String, CodingKey {
            case token, platform, environment
            case appVersion = "app_version"
        }
    }

    func registerDevice(token: String, environment: String, appVersion: String) async throws {
        let _: NotificationAck = try await api.post(
            "devices/register",
            body: RegisterBody(
                token: token,
                platform: "ios",
                environment: environment,
                appVersion: appVersion
            )
        )
    }

    func unregisterDevice(token: String) async throws {
        let _: NotificationAck = try await api.post("devices/unregister", body: ["token": token])
    }

    func list(afterId: UInt = 0, limit: Int = 30) async throws -> NotificationListResult {
        var q: [String: String] = ["limit": "\(limit)"]
        if afterId > 0 {
            q["after_id"] = "\(afterId)"
        }
        return try await api.get("notifications", query: q)
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
    @Published var apnsToken: String?
    @Published var isSyncing: Bool = false

    var onDeepLink: ((AppDeepLink) -> Void)?
    var onUnreadCountChange: ((Int) -> Void)?

    private static let prefsStorageKey = "loverorder.notification.prefs.v1"
    private static let promptedStorageKey = "loverorder.notification.prompted.v1"
    private static let lastDeliveredPrefix = "loverorder.notification.lastDelivered."

    private var activeUserId: UInt?
    private var pollTask: Task<Void, Never>?

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
        let userChanged = activeUserId != userId
        activeUserId = userId

        await refreshAuthorizationStatus()
        await requestPermissionIfNeededOnce()

        if let token = apnsToken, !token.isEmpty {
            await uploadAPNsToken(token)
        }

        syncMealtimeReminders()
        await syncServerNotifications(allowLocalBanner: !userChanged)

        startPollingLoop(userId: userId)
    }

    func handleLogout() async {
        pollTask?.cancel()
        pollTask = nil
        if let token = apnsToken, !token.isEmpty {
            try? await NotificationService.shared.unregisterDevice(token: token)
        }
        activeUserId = nil
        events = []
        updateUnreadCount(0)
    }

    func didReceiveAPNsToken(_ hex: String) {
        apnsToken = hex
        guard activeUserId != nil else { return }
        Task {
            await uploadAPNsToken(hex)
        }
    }

    func updatePreferences(_ mutate: (inout NotificationPreferences) -> Void) {
        mutate(&prefs)
        if let data = try? JSONEncoder().encode(prefs) {
            UserDefaults.standard.set(data, forKey: Self.prefsStorageKey)
        }
        syncMealtimeReminders()
    }

    func refreshAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        authorizationStatus = settings.authorizationStatus
        if settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }

    @discardableResult
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
            await refreshAuthorizationStatus()
            if granted {
                UIApplication.shared.registerForRemoteNotifications()
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
            events = result.items
            updateUnreadCount(result.unreadCount)

            let baselineKey = Self.lastDeliveredPrefix + "\(userId)"
            let hasBaseline = UserDefaults.standard.object(forKey: baselineKey) != nil
            let storedLastId = UInt(UserDefaults.standard.integer(forKey: baselineKey))

            if !hasBaseline {
                UserDefaults.standard.set(Int(result.latestId), forKey: baselineKey)
                return
            }

            let fresh = result.items
                .filter { $0.id > storedLastId && !$0.isRead }
                .sorted { $0.id < $1.id }

            if allowLocalBanner {
                for ev in fresh where prefs.shouldNotify(kind: ev.kind) {
                    await scheduleLocalBanner(for: ev)
                }
            }

            if result.latestId > storedLastId {
                UserDefaults.standard.set(Int(result.latestId), forKey: baselineKey)
            }
        } catch {
            // 后台轮询静默容错，不弹出网络错误打断使用
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
        try? await NotificationService.shared.markRead(eventId: event.id)
    }

    func markAllRead() async {
        events = events.map { old in
            AppNotificationEvent(
                id: old.id, userId: old.userId, actorId: old.actorId, householdId: old.householdId,
                kind: old.kind, title: old.title, body: old.body, mealId: old.mealId,
                roomCode: old.roomCode, deepLink: old.deepLink, isRead: true, readAt: old.readAt ?? Date(),
                createdAt: old.createdAt, actor: old.actor
            )
        }
        updateUnreadCount(0)
        try? await NotificationService.shared.markRead(eventId: 0)
    }

    // 体验与验收用：写入一条服务端通知，并立即弹出一条真系统本地横幅（点击可跳转）
    func sendTestAndDeliverBanner() async throws -> AppNotificationEvent {
        await refreshAuthorizationStatus()
        if authorizationStatus == .notDetermined {
            _ = await requestAuthorization()
        }
        let ev = try await NotificationService.shared.sendTest()
        await syncServerNotifications(allowLocalBanner: false)
        if let userId = activeUserId {
            let key = Self.lastDeliveredPrefix + "\(userId)"
            let current = UInt(UserDefaults.standard.integer(forKey: key))
            if ev.id > current {
                UserDefaults.standard.set(Int(ev.id), forKey: key)
            }
        }
        await scheduleLocalBanner(for: ev)
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
        completionHandler([.banner, .list, .sound, .badge])
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
            if let existing = events.first(where: { $0.id == eventId }) {
                Task { await markRead(event: existing) }
            } else {
                Task { try? await NotificationService.shared.markRead(eventId: eventId) }
            }
        }

        if let deepLinkRaw, let link = AppDeepLink.parse(string: deepLinkRaw) {
            onDeepLink?(link)
            return
        }

        switch kindRaw {
        case "meal_completed", "meal_reviewed":
            if let mealId, mealId > 0 {
                onDeepLink?(.history(mealId: mealId))
            } else {
                onDeepLink?(.meal(mealId: nil))
            }
        case "household_joined":
            onDeepLink?(.household)
        default:
            onDeepLink?(.meal(mealId: mealId))
        }
    }

    private func startPollingLoop(userId: UInt) {
        pollTask?.cancel()
        pollTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(8))
                guard let self, self.activeUserId == userId else { break }
                guard UIApplication.shared.applicationState == .active else { continue }
                await self.syncServerNotifications(allowLocalBanner: true)
            }
        }
    }

    private func uploadAPNsToken(_ token: String) async {
        #if DEBUG
        let env = "sandbox"
        #else
        let env = "production"
        #endif
        let version = (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "1.0"
        try? await NotificationService.shared.registerDevice(token: token, environment: env, appVersion: version)
    }

    private func scheduleLocalBanner(for event: AppNotificationEvent) async {
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
            identifier: "loverorder.event.\(event.id).\(UUID().uuidString.prefix(6))",
            content: content,
            trigger: trigger
        )
        try? await UNUserNotificationCenter.current().add(req)
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
