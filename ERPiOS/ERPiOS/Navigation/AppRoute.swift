import SwiftUI

enum AppTab: String, CaseIterable, Identifiable, Hashable {
    case dashboard = "工作台"
    case business = "业务"
    case reports = "报表"
    case settings = "我的"

    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .dashboard: return "square.grid.2x2"
        case .business: return "briefcase"
        case .reports: return "chart.bar.xaxis"
        case .settings: return "person.crop.circle"
        }
    }
    var selectedSymbol: String {
        switch self {
        case .dashboard: return "square.grid.2x2.fill"
        case .business: return "briefcase.fill"
        case .reports: return "chart.bar.xaxis"
        case .settings: return "person.crop.circle.fill"
        }
    }
}

enum AppRoute: Hashable {
    case salesList
    case salesDetail(String)
    case purchaseList
    case purchaseDetail(String)
    case inventoryList
    case movementList
    case outboundSearch
    case productionList
    case financeList
    case customers
    case suppliers
    case products
    case dataSourceSettings
}

@MainActor
final class AppRouter: ObservableObject {
    @Published var selectedTab: AppTab = .dashboard
    @Published var paths: [AppTab: [AppRoute]] = [:]

    func binding(for tab: AppTab) -> Binding<[AppRoute]> {
        Binding(get: { self.paths[tab] ?? [] },
                set: { self.paths[tab] = $0 })
    }

    func push(_ route: AppRoute) {
        paths[selectedTab, default: []].append(route)
    }

    func popAll(in tab: AppTab) {
        paths[tab] = []
    }

    /// 工作台待办 / 快捷入口跳转：统一切到业务 Tab 并压入目标页
    func openFromDashboard(_ route: AppRoute) {
        selectedTab = .business
        paths[.business] = [route]
    }
}

struct RouteDestination: View {
    let route: AppRoute

    @ViewBuilder var body: some View {
        switch route {
        case .salesList: SalesListView()
        case .salesDetail(let id): SalesDetailView(orderId: id)
        case .purchaseList: PurchaseListView()
        case .purchaseDetail(let id): PurchaseDetailView(orderId: id)
        case .inventoryList: InventoryListView()
        case .movementList: MovementListView()
        case .outboundSearch: OutboundSearchView()
        case .productionList: ProductionListView()
        case .financeList: FinanceListView()
        case .customers: CustomerListView()
        case .suppliers: SupplierListView()
        case .products: ProductListView()
        case .dataSourceSettings: DataSourceSettingsView()
        }
    }
}
