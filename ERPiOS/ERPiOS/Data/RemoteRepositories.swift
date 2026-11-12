import Foundation

// ============================================================
// 远程数据源实现：代码已按 REST 契约写好，默认不启用。
// 联云步骤：
//   1. 设置页填写 baseURL / token，数据源切到「云服务器」
//   2. 后端按 APIRoutes 提供接口；字段不一致时调整 Network.swift 的
//      JSONDecoder.keyDecodingStrategy 或在此处加 DTO 映射
//   3. 业务层（Features / ViewModel）无需任何改动
// ============================================================

private struct StatusPayload: Encodable { let status: String }
private struct AmountPayload: Encodable { let amount: Double }
private struct QuantityPayload: Encodable { let delta: Int }
private struct DoneQtyPayload: Encodable { let doneQty: Int }

final class RemoteDashboardRepository: DashboardRepository {
    private let client: APIClient
    init(client: APIClient) { self.client = client }
    func snapshot() async throws -> DashboardSnapshot {
        try await client.request(Endpoint(path: APIRoutes.dashboard), as: DashboardSnapshot.self)
    }
}

final class RemoteSalesRepository: SalesRepository {
    private let client: APIClient
    init(client: APIClient) { self.client = client }

    func list(query: String?, status: OrderStatus?) async throws -> [SalesOrder] {
        var q: [String: String] = [:]
        if let query = query, !query.isEmpty { q["q"] = query }
        if let status = status { q["status"] = status.rawValue }
        return try await client.request(Endpoint(path: APIRoutes.sales, query: q), as: [SalesOrder].self)
    }

    func detail(id: String) async throws -> SalesOrder? {
        try await client.request(Endpoint(path: "\(APIRoutes.sales)/\(id)"), as: SalesOrder.self)
    }

    func create(_ order: SalesOrder) async throws {
        _ = try await client.submit(Endpoint(path: APIRoutes.sales, method: .post),
                                    body: order, as: SalesOrder.self)
    }

    func updateStatus(id: String, status: OrderStatus) async throws {
        try await client.perform(Endpoint(path: "\(APIRoutes.sales)/\(id)/status", method: .patch),
                                 body: StatusPayload(status: status.rawValue))
    }
}

final class RemotePurchaseRepository: PurchaseRepository {
    private let client: APIClient
    init(client: APIClient) { self.client = client }

    func list(query: String?, status: PurchaseStatus?) async throws -> [PurchaseOrder] {
        var q: [String: String] = [:]
        if let query = query, !query.isEmpty { q["q"] = query }
        if let status = status { q["status"] = status.rawValue }
        return try await client.request(Endpoint(path: APIRoutes.purchases, query: q), as: [PurchaseOrder].self)
    }

    func detail(id: String) async throws -> PurchaseOrder? {
        try await client.request(Endpoint(path: "\(APIRoutes.purchases)/\(id)"), as: PurchaseOrder.self)
    }

    func updateStatus(id: String, status: PurchaseStatus) async throws {
        try await client.perform(Endpoint(path: "\(APIRoutes.purchases)/\(id)/status", method: .patch),
                                 body: StatusPayload(status: status.rawValue))
    }
}

final class RemoteInventoryRepository: InventoryRepository {
    private let client: APIClient
    init(client: APIClient) { self.client = client }

    func list(query: String?, lowStockOnly: Bool) async throws -> [InventoryItem] {
        var q: [String: String] = [:]
        if let query = query, !query.isEmpty { q["q"] = query }
        if lowStockOnly { q["low_stock"] = "true" }
        return try await client.request(Endpoint(path: APIRoutes.inventory, query: q), as: [InventoryItem].self)
    }

    func movements() async throws -> [StockMovement] {
        try await client.request(Endpoint(path: APIRoutes.movements), as: [StockMovement].self)
    }

    func createInbound(_ draft: StockInDraft) async throws -> StockMovement {
        struct Body: Encodable {
            let sku: String
            let quantity: Int
            let warehouse: String
            let note: String
            let ocrText: String
            let source: String
            let photo: String?
        }
        struct Response: Decodable { let movement: StockMovement }

        var photo: String?
        if let data = draft.photoJPEG {
            photo = "data:image/jpeg;base64," + data.base64EncodedString()
        }
        let body = Body(sku: draft.sku, quantity: draft.quantity,
                        warehouse: draft.warehouse, note: draft.note,
                        ocrText: draft.ocrText,
                        source: draft.fromCamera ? "camera" : "manual",
                        photo: photo)
        let resp = try await client.submit(
            Endpoint(path: "\(APIRoutes.inventory)/inbound", method: .post),
            body: body, as: Response.self)
        return resp.movement
    }

    func searchOutbound(_ filter: OutboundQuery) async throws -> OutboundSearchResult {
        var q: [String: String] = [:]
        if !filter.keyword.isEmpty { q["q"] = filter.keyword }
        if !filter.sku.isEmpty { q["sku"] = filter.sku }
        if !filter.warehouse.isEmpty { q["warehouse"] = filter.warehouse }
        if !filter.operatorName.isEmpty { q["operator"] = filter.operatorName }
        if !filter.dateFrom.isEmpty { q["date_from"] = filter.dateFrom }
        if !filter.dateTo.isEmpty { q["date_to"] = filter.dateTo }
        return try await client.request(
            Endpoint(path: APIRoutes.outboundSearch, query: q),
            as: OutboundSearchResult.self)
    }

    func createOutbound(_ draft: OutboundDraft) async throws -> StockMovement {
        struct Body: Encodable {
            let sku: String
            let quantity: Int
            let warehouse: String
            let receiver: String
            let note: String
            let date: String
        }
        struct Response: Decodable { let movement: StockMovement }
        let body = Body(sku: draft.sku, quantity: draft.quantity,
                        warehouse: draft.warehouse, receiver: draft.receiver,
                        note: draft.note, date: draft.date)
        let resp = try await client.submit(
            Endpoint(path: APIRoutes.outboundCreate, method: .post),
            body: body, as: Response.self)
        return resp.movement
    }

    func adjust(itemId: String, delta: Int) async throws {
        try await client.perform(Endpoint(path: "\(APIRoutes.inventory)/\(itemId)/adjust", method: .post),
                                 body: QuantityPayload(delta: delta))
    }
}

final class RemoteProductionRepository: ProductionRepository {
    private let client: APIClient
    init(client: APIClient) { self.client = client }

    func list(status: WorkOrderStatus?) async throws -> [WorkOrder] {
        var q: [String: String] = [:]
        if let status = status { q["status"] = status.rawValue }
        return try await client.request(Endpoint(path: APIRoutes.workOrders, query: q), as: [WorkOrder].self)
    }

    func reportProgress(id: String, doneQty: Int) async throws {
        try await client.perform(Endpoint(path: "\(APIRoutes.workOrders)/\(id)/progress", method: .patch),
                                 body: DoneQtyPayload(doneQty: doneQty))
    }
}

final class RemoteFinanceRepository: FinanceRepository {
    private let client: APIClient
    init(client: APIClient) { self.client = client }

    func list(type: InvoiceType?, status: InvoiceStatus?) async throws -> [Invoice] {
        var q: [String: String] = [:]
        if let type = type { q["type"] = type.rawValue }
        if let status = status { q["status"] = status.rawValue }
        return try await client.request(Endpoint(path: APIRoutes.invoices, query: q), as: [Invoice].self)
    }

    func settle(id: String, amount: Double) async throws {
        try await client.perform(Endpoint(path: "\(APIRoutes.invoices)/\(id)/settle", method: .post),
                                 body: AmountPayload(amount: amount))
    }
}

final class RemoteMasterDataRepository: MasterDataRepository {
    private let client: APIClient
    init(client: APIClient) { self.client = client }

    func customers() async throws -> [Customer] {
        try await client.request(Endpoint(path: APIRoutes.customers), as: [Customer].self)
    }
    func suppliers() async throws -> [Supplier] {
        try await client.request(Endpoint(path: APIRoutes.suppliers), as: [Supplier].self)
    }
    func products() async throws -> [Product] {
        try await client.request(Endpoint(path: APIRoutes.products), as: [Product].self)
    }
}

final class RemoteReportRepository: ReportRepository {
    private let client: APIClient
    init(client: APIClient) { self.client = client }
    func bundle() async throws -> ReportBundle {
        try await client.request(Endpoint(path: APIRoutes.reports), as: ReportBundle.self)
    }
}

final class RemoteAuthRepository: AuthRepository {
    private let client: APIClient
    init(client: APIClient) { self.client = client }

    func login(username: String, password: String) async throws -> AuthSession {
        try await client.submit(Endpoint(path: "v1/auth/login", method: .post),
                                body: LoginPayload(username: username, password: password),
                                as: AuthSession.self)
    }
    func me() async throws -> AuthUser? {
        try await client.request(Endpoint(path: "v1/auth/me"), as: AuthUser.self)
    }
    func logout() async throws {
        struct Empty: Encodable {}
        try await client.perform(Endpoint(path: "v1/auth/logout", method: .post), body: Empty())
    }
    func changePassword(old: String, new: String) async throws {
        struct Payload: Encodable { let oldPassword: String; let newPassword: String }
        try await client.perform(Endpoint(path: "v1/auth/password", method: .post),
                                 body: Payload(oldPassword: old, newPassword: new))
    }
}

final class RemoteRepositoryProvider: RepositoryProvider {
    let dashboard: DashboardRepository
    let sales: SalesRepository
    let purchase: PurchaseRepository
    let inventory: InventoryRepository
    let production: ProductionRepository
    let finance: FinanceRepository
    let masters: MasterDataRepository
    let reports: ReportRepository
    let auth: AuthRepository

    init(client: APIClient) {
        dashboard = RemoteDashboardRepository(client: client)
        sales = RemoteSalesRepository(client: client)
        purchase = RemotePurchaseRepository(client: client)
        inventory = RemoteInventoryRepository(client: client)
        production = RemoteProductionRepository(client: client)
        finance = RemoteFinanceRepository(client: client)
        masters = RemoteMasterDataRepository(client: client)
        reports = RemoteReportRepository(client: client)
        auth = RemoteAuthRepository(client: client)
    }
}
