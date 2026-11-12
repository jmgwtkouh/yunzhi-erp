import Foundation

// 本地 Mock 数据库：内存快照 + UserDefaults JSON 持久化。
// 用 NSLock 保证多线程安全，联云后可整体替换或降级为离线缓存。
struct MockDBSnapshot: Codable {
    var sales: [SalesOrder]
    var purchases: [PurchaseOrder]
    var inventory: [InventoryItem]
    var movements: [StockMovement]
    var workOrders: [WorkOrder]
    var invoices: [Invoice]
    var customers: [Customer]
    var suppliers: [Supplier]
    var products: [Product]
}

final class MockDatabase: @unchecked Sendable {
    // v1 曾持久化演示业务数据；升级到 v2 后旧数据不再读取，并在启动时清除。
    private static let storageKey = "erp.mockdb.v2"
    private let lock = NSLock()
    private var snapshot: MockDBSnapshot

    init() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "erp.mockdb.v1")   // 清除历史演示数据
        if let data = defaults.data(forKey: Self.storageKey),
           let decoded = try? JSONDecoder().decode(MockDBSnapshot.self, from: data) {
            snapshot = decoded
        } else {
            snapshot = MockDatabase.fresh()
        }
    }

    /// 生产默认：空库，不预置任何演示业务数据。
    /// 演示种子数据仍保留在 Seed 中，仅供显式调用（演示开关）使用。
    static func fresh() -> MockDBSnapshot {
        MockDBSnapshot(sales: [], purchases: [], inventory: [],
                       movements: [], workOrders: [], invoices: [],
                       customers: [], suppliers: [], products: [])
    }

    func read<T>(_ body: (inout MockDBSnapshot) -> T) -> T {
        lock.lock(); defer { lock.unlock() }
        return body(&snapshot)
    }

    func snapshotCopy() -> MockDBSnapshot {
        read { snap in snap }
    }

    func persist() {
        let copy = snapshotCopy()
        guard let data = try? JSONEncoder().encode(copy) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }

    /// 仅用于 QA 截图：把 Seed 演示数据灌入本地库（正常启动不会调用）
    func loadDemoSeed() {
        read { snap in
            snap.products = Seed.products()
            snap.customers = Seed.customers()
            snap.suppliers = Seed.suppliers()
            snap.inventory = Seed.inventory()
            snap.movements = Seed.movements()
        }
        persist()
    }

    func reset() {
        read { snap in snap = MockDatabase.fresh() }
        persist()
    }
}

/// 模拟网络往返，让 loading / 骨架屏在本地阶段也能被验证
enum MockLatency {
    static func wait() async throws {
        try await Task.sleep(nanoseconds: 140_000_000)
    }
}
