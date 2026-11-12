import Foundation

// 与服务端 /v1/auth/* 返回体字段严格一致
struct AuthUser: Codable, Identifiable, Hashable {
    var username: String
    var displayName: String
    var role: String
    var enabled: Bool
    var mustChangePassword: Bool
    var createdAt: String
    var id: String { username }

    static let local = AuthUser(
        username: "local", displayName: "本地演示", role: "admin",
        enabled: true, mustChangePassword: false, createdAt: ""
    )
}

struct AuthSession: Codable {
    var token: String
    var user: AuthUser
    var expiresAt: String
    var serverTime: String?
}

struct LoginPayload: Encodable {
    let username: String
    let password: String
}
