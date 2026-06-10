import Foundation

// 网络层错误类型
enum APIError: LocalizedError {
    case invalidURL
    case requestFailed(underlying: Error)
    case decodingFailed(underlying: Error)
    case server(code: Int, message: String)
    case unauthorized
    case noData

    // 这些文案会直接以 toast 呈现给用户 说人话 不暴露技术细节
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "请求地址有误"
        case .requestFailed:
            return "网络好像不太通 检查一下再试"
        case .decodingFailed:
            return "数据有点不对劲 稍后再试"
        case .server(_, let msg):
            return msg
        case .unauthorized:
            return "登录过期了 请重新登录"
        case .noData:
            return "暂时没拿到内容 再试一次"
        }
    }
}

// 后端统一响应
struct APIResponse<T: Decodable>: Decodable {
    let code: Int
    let message: String
    let data: T?
}
