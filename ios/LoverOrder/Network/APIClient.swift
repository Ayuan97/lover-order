import Foundation

// 后端基础地址
// 模拟器走 localhost；真机用 Info.plist 里的 API_BASE_URL（或下面的 fallback LAN IP）
// 修改方式：
//   方式 A 改 Info.plist 加 API_BASE_URL 字符串 比如 "http://180.110.203.208:8081"
//   方式 B 直接改下面的 fallbackDeviceBaseURL（更快）
enum APIConfig {
    private static let fallbackDeviceBaseURL = "http://180.110.203.208:8081"

    static let baseURL: URL = {
        #if targetEnvironment(simulator)
        return URL(string: "http://localhost:8081/api/v1")!
        #else
        let base = (Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let host = (base?.isEmpty == false ? base! : fallbackDeviceBaseURL)
        return URL(string: host + "/api/v1") ?? URL(string: fallbackDeviceBaseURL + "/api/v1")!
        #endif
    }()

    // 图片字段可能是 /static/... 相对路径 渲染前按当前后端地址补全
    // 这样换 LAN IP 或模拟器/真机混用时 老图都不挂;历史数据里的绝对 URL 原样放行
    static func imageURL(_ s: String?) -> URL? {
        guard let s, !s.isEmpty else { return nil }
        if s.hasPrefix("http://") || s.hasPrefix("https://") {
            return URL(string: s)
        }
        var comp = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        comp?.path = s
        comp?.query = nil
        return comp?.url
    }

    // 构造 WebSocket 连接地址（http->ws / https->wss）
    static func webSocketURL(path: String, query: [String: String] = [:]) -> URL? {
        var comp = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)
        if comp?.scheme == "https" {
            comp?.scheme = "wss"
        } else if comp?.scheme == "http" {
            comp?.scheme = "ws"
        }
        if !query.isEmpty {
            comp?.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        return comp?.url
    }
}

// 单飞 Token 刷新器：并发 401 共享同一轮 auth/refresh 请求，避免重复刷新或误清登录态
private actor TokenRefresher {
    private struct RefreshBody: Encodable {
        let refreshToken: String
        enum CodingKeys: String, CodingKey { case refreshToken = "refresh_token" }
    }

    private struct RefreshPayload: Decodable {
        let accessToken: String
        enum CodingKeys: String, CodingKey { case accessToken = "access_token" }
    }

    private var activeTask: Task<Bool, Never>?

    func refreshIfNeeded(
        failedAccessToken: String?,
        session: URLSession,
        decoder: JSONDecoder,
        encoder: JSONEncoder
    ) async -> Bool {
        let currentAccess = await MainActor.run { TokenStorage.shared.access }
        if let failedAccessToken,
           let currentAccess,
           !currentAccess.isEmpty,
           currentAccess != failedAccessToken {
            return true
        }
        if let existing = activeTask {
            return await existing.value
        }
        let task = Task<Bool, Never> {
            let refreshToken = await MainActor.run { TokenStorage.shared.refresh }
            guard let refreshToken, !refreshToken.isEmpty else {
                return false
            }
            guard let url = URLComponents(
                url: APIConfig.baseURL.appendingPathComponent("auth/refresh"),
                resolvingAgainstBaseURL: false
            )?.url else {
                return false
            }
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try? encoder.encode(RefreshBody(refreshToken: refreshToken))

            guard let (data, response) = try? await session.data(for: request),
                  let http = response as? HTTPURLResponse,
                  http.statusCode == 200,
                  let wrapped = try? decoder.decode(APIResponse<RefreshPayload>.self, from: data),
                  wrapped.code == 0,
                  let payload = wrapped.data,
                  !payload.accessToken.isEmpty else {
                return false
            }

            return await MainActor.run {
                guard let currentRefresh = TokenStorage.shared.refresh,
                      currentRefresh == refreshToken else {
                    return false
                }
                TokenStorage.shared.access = payload.accessToken
                return true
            }
        }
        activeTask = task
        let ok = await task.value
        activeTask = nil
        return ok
    }
}

// 统一 HTTP 客户端 只支持 POST / GET 与后端约定一致
final class APIClient {
    static let shared = APIClient()

    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    private let refresher = TokenRefresher()

    static func makeDecoder() -> JSONDecoder {
        let dec = JSONDecoder()
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let fallback = ISO8601DateFormatter()
        dec.dateDecodingStrategy = .custom { d in
            let container = try d.singleValueContainer()
            let s = try container.decode(String.self)
            if let date = formatter.date(from: s) { return date }
            if let date = fallback.date(from: s) { return date }
            if let date = APIClient.altParse(s) { return date }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "无法解析日期：\(s)")
        }
        return dec
    }

    static func makeEncoder() -> JSONEncoder {
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        return enc
    }

    init(session: URLSession = .shared) {
        self.session = session
        self.decoder = Self.makeDecoder()
        self.encoder = Self.makeEncoder()
    }

    // GET 请求 查询参数走 query
    func get<R: Decodable>(_ path: String, query: [String: String] = [:]) async throws -> R {
        try await send(method: "GET", path: path, query: query, body: Optional<EmptyBody>.none)
    }

    // POST 请求 JSON body
    func post<B: Encodable, R: Decodable>(_ path: String, body: B?) async throws -> R {
        try await send(method: "POST", path: path, query: [:], body: body)
    }

    // POST 请求 无 body
    func post<R: Decodable>(_ path: String) async throws -> R {
        try await send(method: "POST", path: path, query: [:], body: Optional<EmptyBody>.none)
    }

    func refreshAccessTokenIfNeeded(failedAccessToken: String? = nil) async -> Bool {
        await refresher.refreshIfNeeded(
            failedAccessToken: failedAccessToken,
            session: session,
            decoder: decoder,
            encoder: encoder
        )
    }

    private func send<B: Encodable, R: Decodable>(
        method: String,
        path: String,
        query: [String: String],
        body: B?,
        allowRefresh: Bool = true
    ) async throws -> R {
        var components = URLComponents(
            url: APIConfig.baseURL.appendingPathComponent(path),
            resolvingAgainstBaseURL: false
        )
        if !query.isEmpty {
            components?.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        guard let url = components?.url else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let token = TokenStorage.shared.access
        let hadAuthToken = token != nil
        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let body {
            request.httpBody = try encoder.encode(body)
        }

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.requestFailed(underlying: error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw APIError.noData
        }

        if http.statusCode == 401 && hadAuthToken {
            if allowRefresh && path != "auth/refresh" {
                if await refreshAccessTokenIfNeeded(failedAccessToken: token) {
                    return try await send(method: method, path: path, query: query, body: body, allowRefresh: false)
                }
            }
            TokenStorage.shared.clear()
            AppNotifications.sessionExpired()
            throw APIError.unauthorized
        }

        do {
            let wrapped = try decoder.decode(APIResponse<R>.self, from: data)
            if wrapped.code != 0 {
                throw APIError.server(code: wrapped.code, message: wrapped.message)
            }
            if let value = wrapped.data {
                return value
            }
            if let empty = EmptyResponse() as? R {
                return empty
            }
            throw APIError.noData
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.decodingFailed(underlying: error)
        }
    }

    private struct EmptyBody: Encodable {}

    private static func altParse(_ s: String) -> Date? {
        let formats = [
            "yyyy-MM-dd'T'HH:mm:ssZ",
            "yyyy-MM-dd'T'HH:mm:ss.SSSZ",
            "yyyy-MM-dd HH:mm:ss",
        ]
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        for f in formats {
            formatter.dateFormat = f
            if let d = formatter.date(from: s) {
                return d
            }
        }
        return nil
    }
}

// 用于接口返回 data 为空时占位
struct EmptyResponse: Decodable {}
