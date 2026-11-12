import Foundation

// ============================================================
// Repository 的本地实现：完整可增删改查，数据落在 MockDatabase。
// 这一层是「后面联云服务器」时唯一被替换的部分之一。
// ============================================================

final class MockDashboardRepository: DashboardRepository {
    private let db: MockDatabase
    init(db: MockDatabase) { self.db = db }

    func snapshot() async throws -> DashboardSnapshot {
        try await MockLatency.wait()
        let s = db.snapshotCopy()
        let revenue = s.sales
            .filter { $0.status != .cancelled && $0.status != .draft }
            .reduce(0) { $0 + $1.amount }
        let pendingSales = s.sales.filter { $0.status == .pending }.count
        let pendingPurchase = s.purchases.filter { $0.status == .pending }.count
        let unscheduled = s.workOrders.filter { $0.status == .scheduled }.count
        let overdue = s.invoices.filter { $0.type == .receivable && $0.status == .overdue }.count
        let lowStock = Set(s.inventory.filter(\.isLowStock).map(\.productName))
        let receivable = s.invoices
            .filter { $0.type == .receivable && $0.status != .settled }
            .reduce(0) { $0 + $1.remaining }

        let kpis: [KPI] = [
            KPI(id: "k1", title: "本月销售额", value: String(format: "%.1f", revenue / 10_000),
                unit: "万元", delta: 0, symbol: "chart.line.uptrend.xyaxis", tone: .info),
            KPI(id: "k2", title: "待处理单据", value: "\(pendingSales + pendingPurchase)",
                unit: "单", delta: 0, symbol: "doc.text.magnifyingglass", tone: .warning),
            KPI(id: "k3", title: "库存预警", value: "\(lowStock.count)",
                unit: "种", delta: 0, symbol: "exclamationmark.triangle", tone: .danger),
            KPI(id: "k4", title: "应收未结", value: String(format: "%.1f", receivable / 10_000),
                unit: "万元", delta: 0, symbol: "banknote", tone: .success)
        ]

        let todos: [TodoItem] = [
            TodoItem(id: "t1", title: "销售订单待审", subtitle: "审核后进入发货流程",
                     count: pendingSales, symbol: "doc.badge.ellipsis", routeKey: "sales"),
            TodoItem(id: "t2", title: "采购申请待批", subtitle: "涉及 \(pendingPurchase) 家供应商",
                     count: pendingPurchase, symbol: "cart.badge.questionmark", routeKey: "purchase"),
            TodoItem(id: "t3", title: "工单待排产", subtitle: "需分配产线与交期",
                     count: unscheduled, symbol: "gearshape.2", routeKey: "production"),
            TodoItem(id: "t4", title: "逾期应收款", subtitle: "建议今日跟进回款",
                     count: overdue, symbol: "clock.badge.exclamationmark", routeKey: "finance")
        ]

        var alerts: [String] = Array(lowStock.prefix(2)).map { "\($0) 库存低于安全线，建议补货" }
        if overdue > 0 { alerts.append("\(overdue) 笔应收账款已逾期，请安排催收") }
        if alerts.isEmpty { alerts.append(s.sales.isEmpty ? "暂无业务数据，请先录入单据" : "当前无异常，所有指标运行平稳") }

        return DashboardSnapshot(kpis: kpis,
                                 todos: todos,
                                 recentOrders: Array(s.sales.prefix(5)),
                                 salesTrend: [],
                                 alerts: alerts)
    }
}

final class MockSalesRepository: SalesRepository {
    private let db: MockDatabase
    init(db: MockDatabase) { self.db = db }

    func list(query: String?, status: OrderStatus?) async throws -> [SalesOrder] {
        try await MockLatency.wait()
        let q = (query ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return db.read { snap in
            snap.sales.filter { order in
                let matchText = q.isEmpty || order.code.localizedCaseInsensitiveContains(q)
                    || order.customerName.localizedCaseInsensitiveContains(q)
                let matchStatus = status == nil || order.status == status
                return matchText && matchStatus
            }
        }
    }

    func detail(id: String) async throws -> SalesOrder? {
        try await MockLatency.wait()
        return db.read { $0.sales.first { $0.id == id } }
    }

    func create(_ order: SalesOrder) async throws {
        try await MockLatency.wait()
        db.read { snap in snap.sales.insert(order, at: 0) }
        db.persist()
    }

    func updateStatus(id: String, status: OrderStatus) async throws {
        try await MockLatency.wait()
        db.read { snap in
            if let i = snap.sales.firstIndex(where: { $0.id == id }) {
                snap.sales[i].status = status
            }
        }
        db.persist()
    }
}

final class MockPurchaseRepository: PurchaseRepository {
    private let db: MockDatabase
    init(db: MockDatabase) { self.db = db }

    func list(query: String?, status: PurchaseStatus?) async throws -> [PurchaseOrder] {
        try await MockLatency.wait()
        let q = (query ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return db.read { snap in
            snap.purchases.filter { order in
                let matchText = q.isEmpty || order.code.localizedCaseInsensitiveContains(q)
                    || order.supplierName.localizedCaseInsensitiveContains(q)
                return matchText && (status == nil || order.status == status)
            }
        }
    }

    func detail(id: String) async throws -> PurchaseOrder? {
        try await MockLatency.wait()
        return db.read { $0.purchases.first { $0.id == id } }
    }

    func updateStatus(id: String, status: PurchaseStatus) async throws {
        try await MockLatency.wait()
        db.read { snap in
            if let i = snap.purchases.firstIndex(where: { $0.id == id }) {
                snap.purchases[i].status = status
            }
        }
        db.persist()
    }
}

final class MockInventoryRepository: InventoryRepository {
    private let db: MockDatabase
    init(db: MockDatabase) { self.db = db }

    func list(query: String?, lowStockOnly: Bool) async throws -> [InventoryItem] {
        try await MockLatency.wait()
        let q = (query ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return db.read { snap in
            snap.inventory.filter { item in
                let matchText = q.isEmpty || item.productName.localizedCaseInsensitiveContains(q)
                    || item.sku.localizedCaseInsensitiveContains(q)
                return matchText && (!lowStockOnly || item.isLowStock)
            }
        }
    }

    func movements() async throws -> [StockMovement] {
        try await MockLatency.wait()
        return db.read { $0.movements }
    }

    func createInbound(_ draft: StockInDraft) async throws -> StockMovement {
        try await MockLatency.wait()
        var movement: StockMovement?
        db.read { snap in
            if let i = snap.inventory.firstIndex(where: {
                $0.sku.caseInsensitiveCompare(draft.sku) == .orderedSame
            }) {
                snap.inventory[i].quantity += draft.quantity
                snap.inventory[i].updatedAt = ERPFormat.today()
            } else {
                let product = snap.products.first {
                    $0.sku.caseInsensitiveCompare(draft.sku) == .orderedSame
                }
                snap.inventory.append(InventoryItem(
                    id: UUID().uuidString, sku: draft.sku,
                    productName: product?.name ?? draft.sku,
                    warehouse: draft.warehouse, quantity: draft.quantity,
                    safetyStock: 0, unit: product?.unit ?? "件",
                    updatedAt: ERPFormat.today()))
            }
            let item = snap.inventory.first {
                $0.sku.caseInsensitiveCompare(draft.sku) == .orderedSame
            }
            var photoURL: String?
            if let data = draft.photoJPEG {
                let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                    .appendingPathComponent("stockin-\(UUID().uuidString).jpg")
                if (try? data.write(to: url)) != nil { photoURL = url.absoluteString }
            }
            let mv = StockMovement(
                id: UUID().uuidString,
                code: "MV-\(Calendar.current.component(.year, from: Date()))-\(Int(Date().timeIntervalSince1970) % 100000)",
                productName: item?.productName ?? draft.sku,
                type: .inbound, quantity: draft.quantity,
                warehouse: draft.warehouse, date: ERPFormat.today(),
                operatorName: Seed.currentUser().name,
                note: draft.note.isEmpty ? nil : draft.note,
                photoUrl: photoURL,
                source: draft.fromCamera ? "camera" : "manual")
            snap.movements.insert(mv, at: 0)
            movement = mv
        }
        db.persist()
        return movement!
    }

    func adjust(itemId: String, delta: Int) async throws {
        try await MockLatency.wait()
        db.read { snap in
            guard let i = snap.inventory.firstIndex(where: { $0.id == itemId }) else { return }
            snap.inventory[i].quantity = max(0, snap.inventory[i].quantity + delta)
            snap.inventory[i].updatedAt = ERPFormat.today()
            let item = snap.inventory[i]
            let mv = StockMovement(
                id: UUID().uuidString,
                code: "MV-2026-\(Int(Date().timeIntervalSince1970) % 100000)",
                productName: item.productName,
                type: delta >= 0 ? .inbound : .outbound,
                quantity: abs(delta), warehouse: item.warehouse,
                date: ERPFormat.today(), operatorName: Seed.currentUser().name
            )
            snap.movements.insert(mv, at: 0)
        }
        db.persist()
    }

    // MARK: - 仓储出库查找（本地实现，与服务端筛选语义一致）

    func searchOutbound(_ filter: OutboundQuery) async throws -> OutboundSearchResult {
        try await MockLatency.wait()
        let snap = db.snapshotCopy()
        let all = snap.movements.filter { $0.type == .outbound }
        let kw = filter.keyword.lowercased(), sku = filter.sku.lowercased()
        let op = filter.operatorName.lowercased()
        let matched = all.filter { m in
            if !filter.warehouse.isEmpty && m.warehouse != filter.warehouse { return false }
            if !filter.dateFrom.isEmpty && m.date < filter.dateFrom { return false }
            if !filter.dateTo.isEmpty && m.date > filter.dateTo { return false }
            if !op.isEmpty && !m.operatorName.lowercased().contains(op) { return false }
            if !sku.isEmpty && !("\(m.sku ?? "") \(m.productName)").lowercased().contains(sku) { return false }
            if !kw.isEmpty {
                let hay = "\(m.code) \(m.productName) \(m.sku ?? "") \(m.warehouse) \(m.operatorName) \(m.receiver ?? "") \(m.note ?? "")".lowercased()
                if !hay.contains(kw) { return false }
            }
            return true
        }.sorted { ($0.date, $0.code) > ($1.date, $1.code) }

        var byWh: [String: (Int, Int)] = [:]
        for m in matched {
            let w = m.warehouse.isEmpty ? "未指定" : m.warehouse
            let cur = byWh[w] ?? (0, 0)
            byWh[w] = (cur.0 + 1, cur.1 + m.quantity)
        }
        let stats = byWh.map {
            OutboundWarehouseStat(name: $0.key, count: $0.value.0, quantity: $0.value.1)
        }.sorted { $0.quantity > $1.quantity }
        let summary = OutboundSummary(
            count: matched.count,
            totalQuantity: matched.reduce(0) { $0 + $1.quantity },
            warehouses: stats, latestDate: matched.first?.date ?? "")
        let options = OutboundOptions(
            warehouses: Array(Set(all.map(\.warehouse))).sorted(),
            operators: Array(Set(all.map(\.operatorName))).sorted())
        return OutboundSearchResult(items: matched, total: matched.count,
                                    limit: max(1, matched.count),
                                    summary: summary, options: options)
    }

    func createOutbound(_ draft: OutboundDraft) async throws -> StockMovement {
        try await MockLatency.wait()
        var result: StockMovement?
        var failure: String?
        db.read { snap in
            guard let i = snap.inventory.firstIndex(where: {
                $0.sku.caseInsensitiveCompare(draft.sku) == .orderedSame
            }) else {
                failure = "未找到该 SKU 的库存记录，请先入库"
                return
            }
            guard snap.inventory[i].quantity >= draft.quantity else {
                failure = "库存不足（当前 \(snap.inventory[i].quantity) \(snap.inventory[i].unit)）"
                return
            }
            let item = snap.inventory[i]
            snap.inventory[i].quantity -= draft.quantity
            snap.inventory[i].updatedAt = ERPFormat.today()
            let seq = snap.movements.filter { $0.code.hasPrefix("CK-") }.count + 1
            let mv = StockMovement(
                id: UUID().uuidString,
                code: String(format: "CK-%d-%04d",
                             Calendar.current.component(.year, from: Date()), seq),
                productName: item.productName, type: .outbound,
                quantity: draft.quantity,
                warehouse: draft.warehouse.isEmpty ? item.warehouse : draft.warehouse,
                date: draft.date.isEmpty ? ERPFormat.today() : draft.date,
                operatorName: envCurrentUserName(),
                note: draft.note.isEmpty ? nil : draft.note,
                source: "outbound", sku: item.sku,
                receiver: draft.receiver.isEmpty ? nil : draft.receiver,
                unit: item.unit)
            snap.movements.insert(mv, at: 0)
            result = mv
        }
        if let failure = failure { throw NSError(domain: "ERP", code: 400,
            userInfo: [NSLocalizedDescriptionKey: failure]) }
        db.persist()
        return result!
    }
}

/// 本地演示模式下操作人取占位账号；云端模式由服务端按会话写入真实账号
private func envCurrentUserName() -> String { Seed.currentUser().name }

final class MockProductionRepository: ProductionRepository {
    private let db: MockDatabase
    init(db: MockDatabase) { self.db = db }

    func list(status: WorkOrderStatus?) async throws -> [WorkOrder] {
        try await MockLatency.wait()
        return db.read { snap in
            snap.workOrders.filter { status == nil || $0.status == status }
        }
    }

    func reportProgress(id: String, doneQty: Int) async throws {
        try await MockLatency.wait()
        db.read { snap in
            guard let i = snap.workOrders.firstIndex(where: { $0.id == id }) else { return }
            snap.workOrders[i].doneQty = min(snap.workOrders[i].planQty, max(0, doneQty))
            if snap.workOrders[i].doneQty >= snap.workOrders[i].planQty {
                snap.workOrders[i].status = .completed
            } else if snap.workOrders[i].status == .scheduled {
                snap.workOrders[i].status = .producing
            }
        }
        db.persist()
    }
}

final class MockFinanceRepository: FinanceRepository {
    private let db: MockDatabase
    init(db: MockDatabase) { self.db = db }

    func list(type: InvoiceType?, status: InvoiceStatus?) async throws -> [Invoice] {
        try await MockLatency.wait()
        return db.read { snap in
            snap.invoices.filter { (type == nil || $0.type == type) && (status == nil || $0.status == status) }
        }
    }

    func settle(id: String, amount: Double) async throws {
        try await MockLatency.wait()
        db.read { snap in
            guard let i = snap.invoices.firstIndex(where: { $0.id == id }) else { return }
            var inv = snap.invoices[i]
            inv.settled = min(inv.amount, inv.settled + max(0, amount))
            inv.status = inv.settled >= inv.amount - 0.01 ? .settled : (inv.settled > 0 ? .partial : inv.status)
            snap.invoices[i] = inv
        }
        db.persist()
    }
}

final class MockMasterDataRepository: MasterDataRepository {
    private let db: MockDatabase
    init(db: MockDatabase) { self.db = db }

    func customers() async throws -> [Customer] { try await MockLatency.wait(); return db.read { $0.customers } }
    func suppliers() async throws -> [Supplier] { try await MockLatency.wait(); return db.read { $0.suppliers } }
    func products() async throws -> [Product] { try await MockLatency.wait(); return db.read { $0.products } }
}

final class MockReportRepository: ReportRepository {
    private let db: MockDatabase
    init(db: MockDatabase) { self.db = db }

    func bundle() async throws -> ReportBundle {
        try await MockLatency.wait()
        // 空库：图表全部为空，不注入任何演示趋势或占比
        return ReportBundle(salesTrend: [], purchaseTrend: [],
                            categoryShare: [], warehouseShare: [])
    }
}

final class MockAuthRepository: AuthRepository {
    func login(username: String, password: String) async throws -> AuthSession {
        AuthSession(token: "local-demo", user: .local, expiresAt: "", serverTime: nil)
    }
    func me() async throws -> AuthUser? { .local }
    func logout() async throws {}
    func changePassword(old: String, new: String) async throws {}
}

/// 本地数据源聚合实现
final class MockRepositoryProvider: RepositoryProvider {
    let db: MockDatabase
    let dashboard: DashboardRepository
    let sales: SalesRepository
    let purchase: PurchaseRepository
    let inventory: InventoryRepository
    let production: ProductionRepository
    let finance: FinanceRepository
    let masters: MasterDataRepository
    let reports: ReportRepository
    let auth: AuthRepository

    init(db: MockDatabase = MockDatabase()) {
        self.db = db
        dashboard = MockDashboardRepository(db: db)
        sales = MockSalesRepository(db: db)
        purchase = MockPurchaseRepository(db: db)
        inventory = MockInventoryRepository(db: db)
        production = MockProductionRepository(db: db)
        finance = MockFinanceRepository(db: db)
        masters = MockMasterDataRepository(db: db)
        reports = MockReportRepository(db: db)
        auth = MockAuthRepository()
    }
}
