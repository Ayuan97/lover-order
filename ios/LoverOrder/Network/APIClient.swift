import Foundation

// 后端基础地址
// 模拟器走 localhost；真机用 Info.plist 里的 API_BASE_URL（或下面的 fallback LAN IP）
// 修改方式：
//   方式 A 改 Info.plist 加 API_BASE_URL 字符串 比如 "http://192.168.1.162:8081"
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
}

// 统一 HTTP 客户端 只支持 POST / GET 与后端约定一致
final class APIClient {
    static let shared = APIClient()

    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init(session: URLSession = .shared) {
        self.session = session
        let dec = JSONDecoder()
        let enc = JSONEncoder()
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
        enc.dateEncodingStrategy = .iso8601
        self.decoder = dec
        self.encoder = enc
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

    private func send<B: Encodable, R: Decodable>(
        method: String,
        path: String,
        query: [String: String],
        body: B?
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
        if let token = TokenStorage.shared.access {
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

        if http.statusCode == 401 {
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
