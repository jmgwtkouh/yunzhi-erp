import Foundation

// ============================================================
// 数据访问契约（业务层唯一依赖）
// ------------------------------------------------------------
// 当前由 Data/Mock 实现；联云时只需在 RepositoryFactory 切换为
// Data/Remote 实现，Features 层与 Domain 层无需任何改动。
// ============================================================

protocol DashboardRepository: AnyObject {
    func snapshot() async throws -> DashboardSnapshot
}

protocol SalesRepository: AnyObject {
    func list(query: String?, status: OrderStatus?) async throws -> [SalesOrder]
    func detail(id: String) async throws -> SalesOrder?
    func create(_ order: SalesOrder) async throws
    func updateStatus(id: String, status: OrderStatus) async throws
}

protocol PurchaseRepository: AnyObject {
    func list(query: String?, status: PurchaseStatus?) async throws -> [PurchaseOrder]
    func detail(id: String) async throws -> PurchaseOrder?
    func updateStatus(id: String, status: PurchaseStatus) async throws
}

protocol InventoryRepository: AnyObject {
    func list(query: String?, lowStockOnly: Bool) async throws -> [InventoryItem]
    func movements() async throws -> [StockMovement]
    func adjust(itemId: String, delta: Int) async throws
    /// 拍照入库：按 SKU 增加库存并生成一条入库流水（可附带照片）
    func createInbound(_ draft: StockInDraft) async throws -> StockMovement
    /// 仓储出库查找：多条件检索出库流水并返回汇总
    func searchOutbound(_ query: OutboundQuery) async throws -> OutboundSearchResult
    /// 登记出库：校验库存、扣减数量并生成一条出库流水
    func createOutbound(_ draft: OutboundDraft) async throws -> StockMovement
}

protocol ProductionRepository: AnyObject {
    func list(status: WorkOrderStatus?) async throws -> [WorkOrder]
    func reportProgress(id: String, doneQty: Int) async throws
}

protocol FinanceRepository: AnyObject {
    func list(type: InvoiceType?, status: InvoiceStatus?) async throws -> [Invoice]
    func settle(id: String, amount: Double) async throws
}

protocol MasterDataRepository: AnyObject {
    func customers() async throws -> [Customer]
    func suppliers() async throws -> [Supplier]
    func products() async throws -> [Product]
}

protocol ReportRepository: AnyObject {
    func bundle() async throws -> ReportBundle
}

protocol AuthRepository: AnyObject {
    func login(username: String, password: String) async throws -> AuthSession
    func me() async throws -> AuthUser?
    func logout() async throws
    func changePassword(old: String, new: String) async throws
}

/// 聚合注入点：AppEnvironment 只持有这一个协议
protocol RepositoryProvider: AnyObject {
    var auth: AuthRepository { get }
    var dashboard: DashboardRepository { get }
    var sales: SalesRepository { get }
    var purchase: PurchaseRepository { get }
    var inventory: InventoryRepository { get }
    var production: ProductionRepository { get }
    var finance: FinanceRepository { get }
    var masters: MasterDataRepository { get }
    var reports: ReportRepository { get }
}
