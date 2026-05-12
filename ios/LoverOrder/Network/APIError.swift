import Foundation

// 网络层错误类型
enum APIError: LocalizedError {
    case invalidURL
    case requestFailed(underlying: Error)
    case decodingFailed(underlying: Error)
    case server(code: Int, message: String)
    case unauthorized
    case noData

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "请求地址有误"
        case .requestFailed(let err):
            return "网络异常：\(err.localizedDescription)"
        case .decodingFailed(let err):
            return "解析失败：\(err.localizedDescription)"
        case .server(_, let msg):
            return msg
        case .unauthorized:
            return "请重新登录"
        case .noData:
            return "无返回数据"
        }
    }
}

// 后端统一响应
struct APIResponse<T: Decodable>: Decodable {
    let code: Int
    let message: String
    let data: T?
}
