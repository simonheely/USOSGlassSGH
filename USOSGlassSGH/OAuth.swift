import Foundation
import CryptoKit
import Security

struct OAuthToken: Codable { let key: String; let secret: String }
struct Credentials: Codable {
    var consumerKey: String
    var consumerSecret: String
    var token: OAuthToken?
}
enum SecureStore {
    private static var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: "pl.prototype.USOSGlassSGH.oauth",
         kSecAttrAccount as String: "personal-connection"]
    }
    static func read() throws -> Credentials? {
        var q = query; q[kSecReturnData as String] = true
        var result: CFTypeRef?
        let status = SecItemCopyMatching(q as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else { throw CampusError.keychain(status) }
        return try JSONDecoder().decode(Credentials.self, from: data)
    }
    static func save(_ value: Credentials) throws {
        let data = try JSONEncoder().encode(value)
        let attrs: [String: Any] = [kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly]
        let status = SecItemUpdate(query as CFDictionary, attrs as CFDictionary)
        if status == errSecItemNotFound {
            var q = query; attrs.forEach { q[$0.key] = $0.value }
            let result = SecItemAdd(q as CFDictionary, nil)
            guard result == errSecSuccess else { throw CampusError.keychain(result) }
        } else if status != errSecSuccess { throw CampusError.keychain(status) }
    }
    static func delete() throws {
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw CampusError.keychain(status) }
    }
}

enum OAuth1 {
    static func encode(_ s: String) -> String {
        s.addingPercentEncoding(withAllowedCharacters: CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"))!
    }
    static func normalized(_ pairs: [(String, String)]) -> String {
        pairs.map { (encode($0.0), encode($0.1)) }.sorted {
            $0.0 == $1.0 ? $0.1 < $1.1 : $0.0 < $1.0
        }.map { "\($0)=\($1)" }.joined(separator: "&")
    }
    static func signature(method: String, url: String, parameters: [(String, String)], consumerSecret: String, tokenSecret: String) -> String {
        let base = [method.uppercased(), url, normalized(parameters)].map(encode).joined(separator: "&")
        let key = SymmetricKey(data: Data("\(encode(consumerSecret))&\(encode(tokenSecret))".utf8))
        return Data(HMAC<Insecure.SHA1>.authenticationCode(for: Data(base.utf8), using: key)).base64EncodedString()
    }
    static func token(from data: Data, requireCallback: Bool = false) throws -> OAuthToken {
        guard let s = String(data: data, encoding: .utf8) else { throw CampusError.invalidToken }
        var fields: [String: String] = [:]
        for pair in s.split(separator: "&") {
            let parts = pair.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            guard parts.count == 2 else { continue }
            fields[String(parts[0])] = String(parts[1]).replacingOccurrences(of: "+", with: " ").removingPercentEncoding
        }
        guard let key = fields["oauth_token"], !key.isEmpty,
              let secret = fields["oauth_token_secret"], !secret.isEmpty,
              !requireCallback || fields["oauth_callback_confirmed"] == "true" else { throw CampusError.invalidToken }
        return OAuthToken(key: key, secret: secret)
    }
}

// Never forward signed requests through redirects or cache private HTTP responses.
final class NoRedirect: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void) { completionHandler(nil) }
}
struct USOSClient {
    static let base = "https://usosapps.sgh.waw.pl/"
    let credentials: Credentials
    private static let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 25
        config.timeoutIntervalForResource = 45
        config.urlCache = nil
        return URLSession(configuration: config, delegate: NoRedirect(), delegateQueue: nil)
    }()
    func request(_ path: String, parameters: [String: String] = [:], token: OAuthToken? = nil) async throws -> Data {
        let endpoint = Self.base + "services/" + path
        var oauth = ["oauth_consumer_key": credentials.consumerKey, "oauth_nonce": UUID().uuidString,
            "oauth_timestamp": String(Int(Date().timeIntervalSince1970)), "oauth_signature_method": "HMAC-SHA1", "oauth_version": "1.0"]
        let auth = token ?? credentials.token
        if let auth { oauth["oauth_token"] = auth.key }
        let pairs = parameters.map { ($0.key, $0.value) } + oauth.map { ($0.key, $0.value) }
        oauth["oauth_signature"] = OAuth1.signature(method: "GET", url: endpoint, parameters: pairs,
            consumerSecret: credentials.consumerSecret, tokenSecret: auth?.secret ?? "")
        let query = OAuth1.normalized(parameters.map { ($0.key, $0.value) })
        guard let url = URL(string: endpoint + (query.isEmpty ? "" : "?" + query)) else { throw CampusError.invalidData }
        var req = URLRequest(url: url)
        req.setValue("OAuth " + oauth.sorted { $0.key < $1.key }.map { "\(OAuth1.encode($0.key))=\"\(OAuth1.encode($0.value))\"" }.joined(separator: ", "), forHTTPHeaderField: "Authorization")
        let (data, response) = try await Self.session.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw CampusError.invalidData }
        guard (200..<300).contains(http.statusCode) else { throw CampusError.http(http.statusCode) }
        return data
    }
    func begin() async throws -> OAuthToken {
        try OAuth1.token(from: await request("oauth/request_token", parameters: ["oauth_callback": "oob", "scopes": "studies|grades"]), requireCallback: true)
    }
    func finish(_ pending: OAuthToken, pin: String) async throws -> OAuthToken {
        try OAuth1.token(from: await request("oauth/access_token", parameters: ["oauth_verifier": pin], token: pending))
    }
    func profile() async throws -> Student {
        try JSONDecoder().decode(Student.self, from: await request("users/user", parameters: ["fields": "id|first_name|last_name"]))
    }
    func timetable(start: Date) async throws -> [CampusEvent] {
        let data = try await request("tt/student", parameters: ["start": CampusTime.string(start, "yyyy-MM-dd"), "days": "7",
            "fields": "start_time|end_time|name|type|course_name|classtype_name|room_number|building_name|frequency"])
        let rows = try JSONDecoder().decode([APIEvent].self, from: data)
        return Array(Dictionary(try rows.map { let e = try $0.model(); return (e.id, e) }, uniquingKeysWith: { first, _ in first }).values).sorted { $0.start < $1.start }
    }
    func grades() async throws -> [CampusGrade] {
        let data = try await request("grades/latest", parameters: ["days": "365", "fields": "value_symbol|passes|exam_id|exam_session_number|date_modified|course_edition[course_id|course_name|term_id]"])
        return try JSONDecoder().decode([CampusGrade].self, from: data)
    }
}
