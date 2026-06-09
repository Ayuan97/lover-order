import Foundation
import Security

// 简单基于 Keychain 的令牌存储 用于 access / refresh 令牌
final class TokenStorage {
    static let shared = TokenStorage()

    private let accessKey = "com.loverorder.token.access"
    private let refreshKey = "com.loverorder.token.refresh"
    private var accessCache: String?
    private var refreshCache: String?
    #if targetEnvironment(simulator)
    private let debugDefaults = UserDefaults.standard
    #endif

    var access: String? {
        get {
            if let accessCache { return accessCache }
            accessCache = read(accessKey)
            #if targetEnvironment(simulator)
            if accessCache == nil {
                accessCache = debugDefaults.string(forKey: accessKey)
            }
            #endif
            return accessCache
        }
        set {
            accessCache = newValue
            write(accessKey, value: newValue)
        }
    }

    var refresh: String? {
        get {
            if let refreshCache { return refreshCache }
            refreshCache = read(refreshKey)
            #if targetEnvironment(simulator)
            if refreshCache == nil {
                refreshCache = debugDefaults.string(forKey: refreshKey)
            }
            #endif
            return refreshCache
        }
        set {
            refreshCache = newValue
            write(refreshKey, value: newValue)
        }
    }

    var isLoggedIn: Bool {
        access != nil
    }

    func clear() {
        accessCache = nil
        refreshCache = nil
        access = nil
        refresh = nil
    }

    private func write(_ key: String, value: String?) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary)
        guard let value, let data = value.data(using: .utf8) else {
            #if targetEnvironment(simulator)
            debugDefaults.removeObject(forKey: key)
            #endif
            return
        }
        var add = query
        add[kSecValueData as String] = data
        SecItemAdd(add as CFDictionary, nil)
        #if targetEnvironment(simulator)
        debugDefaults.set(value, forKey: key)
        #endif
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
