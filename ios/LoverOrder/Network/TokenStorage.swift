import Foundation
import Security

// 简单基于 Keychain 的令牌存储 用于 access / refresh 令牌
final class TokenStorage {
    static let shared = TokenStorage()

    private let accessKey = "com.loverorder.token.access"
    private let refreshKey = "com.loverorder.token.refresh"

    var access: String? {
        get { read(accessKey) }
        set { write(accessKey, value: newValue) }
    }

    var refresh: String? {
        get { read(refreshKey) }
        set { write(refreshKey, value: newValue) }
    }

    var isLoggedIn: Bool {
        access != nil
    }

    func clear() {
        access = nil
        refresh = nil
    }

    private func write(_ key: String, value: String?) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary)
        guard let value, let data = value.data(using: .utf8) else { return }
        var add = query
        add[kSecValueData as String] = data
        SecItemAdd(add as CFDictionary, nil)
    }

    private func read(_ key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }
}
