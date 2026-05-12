import Foundation

// 图片上传返回
struct UploadedImage: Decodable {
    let url: String
    let path: String
}

// 图片上传 multipart/form-data 走自定义编码
final class UploadService {
    static let shared = UploadService()
    private let session: URLSession = .shared
    private let decoder: JSONDecoder = JSONDecoder()

    func uploadImage(_ data: Data, filename: String = "image.jpg", mime: String = "image/jpeg") async throws -> UploadedImage {
        let boundary = "lover-order-\(UUID().uuidString)"
        let url = APIConfig.baseURL.appendingPathComponent("upload/image")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        if let token = TokenStorage.shared.access {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        request.httpBody = multipartBody(boundary: boundary, fieldName: "file", filename: filename, mime: mime, data: data)

        let (respData, response): (Data, URLResponse)
        do {
            (respData, response) = try await session.data(for: request)
        } catch {
            throw APIError.requestFailed(underlying: error)
        }
        guard let http = response as? HTTPURLResponse else { throw APIError.noData }
        if http.statusCode == 401 {
            TokenStorage.shared.clear()
            throw APIError.unauthorized
        }

        do {
            let wrapped = try decoder.decode(APIResponse<UploadedImage>.self, from: respData)
            if wrapped.code != 0 {
                throw APIError.server(code: wrapped.code, message: wrapped.message)
            }
            guard let value = wrapped.data else { throw APIError.noData }
            return value
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.decodingFailed(underlying: error)
        }
    }

    private func multipartBody(boundary: String, fieldName: String, filename: String, mime: String, data: Data) -> Data {
        var body = Data()
        let lineBreak = "\r\n"
        body.append("--\(boundary)\(lineBreak)".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(filename)\"\(lineBreak)".data(using: .utf8)!)
        body.append("Content-Type: \(mime)\(lineBreak)\(lineBreak)".data(using: .utf8)!)
        body.append(data)
        body.append("\(lineBreak)--\(boundary)--\(lineBreak)".data(using: .utf8)!)
        return body
    }
}
