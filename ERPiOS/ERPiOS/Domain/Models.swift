import Foundation

// MARK: - 状态基调
// Domain 层不依赖 SwiftUI，用语义化基调，由 DesignSystem 映射为具体颜色。
enum StatusTone: String, Codable {
    case neutral, info, warning, success, danger, accent
}

// MARK: - 业务状态枚举

enum OrderStatus: String, Codable, CaseIterable, Identifiable {
    case draft = "草稿"
    case pending = "待审核"
    case confirmed = "已确认"
    case shipping = "发货中"
    case completed = "已完成"
    case cancelled = "已取消"
    var id: String { rawValue }
    var tone: StatusTone {
        switch self {
        case .draft: return .neutral
        case .pending: return .warning
        case .confirmed: return .info
        case .shipping: return .accent
        case .completed: return .success
        case .cancelled: return .danger
        }
    }
}

enum PurchaseStatus: String, Codable, CaseIterable, Identifiable {
    case draft = "草稿"
    case pending = "待审批"
    case ordered = "已下单"
    case receiving = "到货中"
    case completed = "已入库"
    case cancelled = "已取消"
    var id: String { rawValue }
    var tone: StatusTone {
        switch self {
        case .draft: return .neutral
        case .pending: return .warning
        case .ordered: return .info
        case .receiving: return .accent
        case .completed: return .success
        case .cancelled: return .danger
        }
    }
}

enum WorkOrderStatus: String, Codable, CaseIterable, Identifiable {
    case scheduled = "待排产"
    case producing = "生产中"
    case checking = "质检中"
    case completed = "已完成"
    case paused = "已暂停"
    var id: String { rawValue }
    var tone: StatusTone {
        switch self {
        case .scheduled: return .neutral
        case .producing: return .info
        case .checking: return .warning
        case .completed: return .success
        case .paused: return .danger
        }
    }
}

enum InvoiceType: String, Codable, CaseIterable, Identifiable {
    case receivable = "应收"
    case payable = "应付"
    var id: String { rawValue }
}

enum InvoiceStatus: String, Codable, CaseIterable, Identifiable {
    case open = "未结算"
    case partial = "部分结算"
    case settled = "已结算"
    case overdue = "已逾期"
    var id: String { rawValue }
    var tone: StatusTone {
        switch self {
        case .open: return .warning
        case .partial: return .info
        case .settled: return .success
        case .overdue: return .danger
        }
    }
}

enum MovementType: String, Codable, CaseIterable, Identifiable {
    case inbound = "入库"
    case outbound = "出库"
    case transfer = "调拨"
    var id: String { rawValue }
    var tone: StatusTone {
        switch self {
        case .inbound: return .success
        case .outbound: return .info
        case .transfer: return .accent
        }
    }
}

// MARK: - 基础资料

struct Customer: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    var contact: String
    var phone: String
    var city: String
    var level: String
    var receivable: Double
    var createdAt: String
}

struct Supplier: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    var contact: String
    var phone: String
    var category: String
    var rating: Int
    var payable: Double
    var createdAt: String
}

struct Product: Codable, Identifiable, Hashable {
    var id: String
    var sku: String
    var name: String
    var category: String
    var unit: String
    var price: Double
    var cost: Double
    var stock: Int
    var safetyStock: Int
    var symbol: String
    var isLowStock: Bool { stock <= safetyStock }
}

// MARK: - 单据

struct OrderLine: Codable, Identifiable, Hashable {
    var id: String
    var productName: String
    var quantity: Int
    var unitPrice: Double
    var amount: Double { unitPrice * Double(quantity) }
}

struct SalesOrder: Codable, Identifiable, Hashable {
    var id: String
    var code: String
    var customerName: String
    var date: String
    var amount: Double
    var status: OrderStatus
    var owner: String
    var items: [OrderLine]
    var remark: String
}

struct PurchaseOrder: Codable, Identifiable, Hashable {
    var id: String
    var code: String
    var supplierName: String
    var date: String
    var eta: String
    var amount: Double
    var status: PurchaseStatus
    var owner: String
    var items: [OrderLine]
}

struct InventoryItem: Codable, Identifiable, Hashable {
    var id: String
    var sku: String
    var productName: String
    var warehouse: String
    var quantity: Int
    var safetyStock: Int
    var unit: String
    var updatedAt: String
    var isLowStock: Bool { quantity <= safetyStock }
}

struct StockMovement: Codable, Identifiable, Hashable {
    var id: String
    var code: String
    var productName: String
    var type: MovementType
    var quantity: Int
    var warehouse: String
    var date: String
    var operatorName: String
    /// 拍照入库产生的备注 / 照片地址 / 来源（手动 or 拍照）
    var note: String? = nil
    var photoUrl: String? = nil
    var source: String? = nil
    /// 仓储出库查找模块新增字段（旧流水缺省时为空）
    var sku: String? = nil
    var receiver: String? = nil
    var unit: String? = nil
    var hasPhoto: Bool { (photoUrl?.isEmpty == false) }
}

// MARK: - 仓储出库查找

/// 出库查找条件；空字符串表示不限制该维度
struct OutboundQuery: Equatable {
    var keyword: String = ""
    var sku: String = ""
    var warehouse: String = ""
    var operatorName: String = ""
    var dateFrom: String = ""
    var dateTo: String = ""
}

/// 服务端 /v1/inventory/outbound/search 返回体
struct OutboundSearchResult: Codable {
    var items: [StockMovement]
    var total: Int
    var limit: Int
    var summary: OutboundSummary
    var options: OutboundOptions
}

struct OutboundSummary: Codable {
    var count: Int
    var totalQuantity: Int
    var warehouses: [OutboundWarehouseStat]
    var latestDate: String
}

struct OutboundWarehouseStat: Codable, Identifiable {
    var name: String
    var count: Int
    var quantity: Int
    var id: String { name }
}

struct OutboundOptions: Codable {
    var warehouses: [String]
    var operators: [String]
}

/// 登记出库提交体
struct OutboundDraft {
    var sku: String
    var quantity: Int
    var warehouse: String
    var receiver: String
    var note: String
    var date: String
}

struct WorkOrder: Codable, Identifiable, Hashable {
    var id: String
    var code: String
    var productName: String
    var planQty: Int
    var doneQty: Int
    var line: String
    var startDate: String
    var dueDate: String
    var status: WorkOrderStatus
    var progress: Double { planQty == 0 ? 0 : min(1, Double(doneQty) / Double(planQty)) }
}

struct Invoice: Codable, Identifiable, Hashable {
    var id: String
    var code: String
    var counterparty: String
    var type: InvoiceType
    var amount: Double
    var settled: Double
    var dueDate: String
    var status: InvoiceStatus
    var remaining: Double { max(0, amount - settled) }
}

// MARK: - 拍照入库

/// 入库草稿：手机端拍照 → OCR 预填 → 提交服务端
struct StockInDraft {
    var sku: String
    var quantity: Int
    var warehouse: String
    var note: String
    var photoJPEG: Data?
    var ocrText: String
    var fromCamera: Bool = true
}

// MARK: - 工作台与报表

struct KPI: Codable, Identifiable, Hashable {
    var id: String
    var title: String
    var value: String
    var unit: String
    var delta: Double
    var symbol: String
    var tone: StatusTone
}

struct TodoItem: Codable, Identifiable, Hashable {
    var id: String
    var title: String
    var subtitle: String
    var count: Int
    var symbol: String
    var routeKey: String
}

struct ReportPoint: Codable, Identifiable, Hashable {
    var id: String { label }
    var label: String
    var value: Double
}

struct CategoryShare: Codable, Identifiable, Hashable {
    var id: String { name }
    var name: String
    var value: Double
    var tone: StatusTone
}

struct DashboardSnapshot: Codable {
    var kpis: [KPI]
    var todos: [TodoItem]
    var recentOrders: [SalesOrder]
    var salesTrend: [ReportPoint]
    var alerts: [String]
}

struct ReportBundle: Codable {
    var salesTrend: [ReportPoint]
    var purchaseTrend: [ReportPoint]
    var categoryShare: [CategoryShare]
    var warehouseShare: [CategoryShare]
}

struct AppUser: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    var role: String
    var department: String
    var employeeNo: String
}
