import Foundation

// ============================================================
// 云接入层（当前不启用，联云时填 baseURL / token 即可切换）
// 后端接口契约见 APIRoutes；所有返回体直接使用 Domain 层模型，
// 若后端字段名不同，只需在 JSONDecoder.keyDecodingStrategy 处适配。
// ============================================================

enum DataSourceMode: String, Codable, CaseIterable, Identifiable {
    case mock = "本地演示"
    case remote = "云服务器"
    var id: String { rawValue }
}

struct APIConfiguration: Codable, Equatable {
    var baseURLString: String
    var token: String
    var timeout: TimeInterval

    // 已部署到腾讯云轻量应用服务器（广州），App 设置页会预填此地址。
    // 换服务器时直接在「我的 → 数据源」修改即可，无需改代码。
    static let `default` = APIConfiguration(
        baseURLString: "http://127.0.0.1:8080",
        token: "",
        timeout: 20
    )

    var baseURL: URL? { URL(string: baseURLString) }
    var isConfigured: Bool {
        guard let u = baseURL, let scheme = u.scheme,
              ["http", "https"].contains(scheme.lowercased()), u.host != nil else { return false }
        return !baseURLString.contains("example.com")
    }
}

enum HTTPMethod: String {
    case get = "GET", post = "POST", patch = "PATCH", put = "PUT", delete = "DELETE"
}

/// 后端接口清单：联云时按此表对接
enum APIRoutes {
    static let dashboard = "v1/dashboard/summary"
    static let sales = "v1/sales-orders"
    static let purchases = "v1/purchase-orders"
    static let inventory = "v1/inventory/items"
    static let movements = "v1/inventory/movements"
    static let outboundSearch = "v1/inventory/outbound/search"
    static let outboundCreate = "v1/inventory/outbound"
    static let workOrders = "v1/work-orders"
    static let invoices = "v1/invoices"
    static let customers = "v1/master/customers"
    static let suppliers = "v1/master/suppliers"
    static let products = "v1/master/products"
    static let reports = "v1/reports/overview"
}

struct Endpoint {
    var path: String
    var method: HTTPMethod = .get
    var query: [String: String] = [:]
    var body: Data? = nil

    func urlRequest(baseURL: URL, token: String, timeout: TimeInterval) throws -> URLRequest {
        let full = baseURL.appendingPathComponent(path)
        guard var comps = URLComponents(url: full, resolvingAgainstBaseURL: false) else {
            throw APIError.invalidURL
        }
        if !query.isEmpty {
            comps.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        guard let url = comps.url else { throw APIError.invalidURL }
        var req = URLRequest(url: url, timeoutInterval: timeout)
        req.httpMethod = method.rawValue
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        if !token.isEmpty { req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        req.httpBody = body
        return req
    }
}

enum APIError: LocalizedError {
    case invalidURL
    case notConfigured
    case invalidResponse
    case unauthorized
    case httpStatus(Int, String)
    case decoding(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "请求地址无效"
        case .notConfigured: return "尚未配置服务器地址，请先在「设置 - 数据源」中填写"
        case .invalidResponse: return "服务器返回了无效响应"
        case .unauthorized: return "登录已过期，请重新登录"
        case .httpStatus(let code, let msg): return "请求失败 (\(code))：\(msg.prefix(120))"
        case .decoding(let err): return "数据解析失败：\(err.localizedDescription)"
        }
    }
}

protocol APIClient: AnyObject {
    /// 登录后由 AppEnvironment 写入，优先于 config.json 中的静态运维 Token
    var sessionToken: String { get set }
    func request<T: Decodable>(_ endpoint: Endpoint, as type: T.Type) async throws -> T
    func submit<Body: Encodable, Response: Decodable>(_ endpoint: Endpoint, body: Body,
                                                      as type: Response.Type) async throws -> Response
    func perform<Body: Encodable>(_ endpoint: Endpoint, body: Body) async throws
}

final class URLSessionAPIClient: APIClient {
    let configuration: APIConfiguration
    var sessionToken: String = ""
    private var effectiveToken: String {
        sessionToken.isEmpty ? configuration.token : sessionToken
    }
    private let session: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(configuration: APIConfiguration) {
        self.configuration = configuration
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = configuration.timeout
        cfg.waitsForConnectivity = true
        self.session = URLSession(configuration: cfg)
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        // 后端若使用 snake_case，改为 .convertFromSnakeCase 即可全局适配
        decoder.keyDecodingStrategy = .useDefaultKeys
    }

    func request<T: Decodable>(_ endpoint: Endpoint, as type: T.Type) async throws -> T {
        let (data, response) = try await session.data(for: try makeRequest(endpoint))
        return try decode(data, response, as: type)
    }

    func submit<Body: Encodable, Response: Decodable>(_ endpoint: Endpoint, body: Body,
                                                      as type: Response.Type) async throws -> Response {
        var ep = endpoint
        ep.body = try encoder.encode(body)
        let (data, response) = try await session.data(for: try makeRequest(ep))
        return try decode(data, response, as: type)
    }

    func perform<Body: Encodable>(_ endpoint: Endpoint, body: Body) async throws {
        var ep = endpoint
        ep.body = try encoder.encode(body)
        let (_, response) = try await session.data(for: try makeRequest(ep))
        try validate(response)
    }

    private func makeRequest(_ endpoint: Endpoint) throws -> URLRequest {
        guard configuration.isConfigured, let base = configuration.baseURL else {
            throw APIError.notConfigured
        }
        return try endpoint.urlRequest(baseURL: base, token: effectiveToken,
                                       timeout: configuration.timeout)
    }

    private func validate(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        if http.statusCode == 401 { throw APIError.unauthorized }
        guard (200..<300).contains(http.statusCode) else {
            throw APIError.httpStatus(http.statusCode, "")
        }
    }

    private func decode<T: Decodable>(_ data: Data, _ response: URLResponse, as type: T.Type) throws -> T {
        try validate(response)
        do { return try decoder.decode(T.self, from: data) }
        catch { throw APIError.decoding(error) }
    }
}
