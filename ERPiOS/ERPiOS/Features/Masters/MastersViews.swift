import SwiftUI

// MARK: - 通用主数据列表外壳

struct MasterListView<Item: Identifiable, Row: View>: View {
    @EnvironmentObject private var env: AppEnvironment
    @StateObject private var vm = LoadListViewModel<Item>()

    let title: String
    let fetch: () async throws -> [Item]
    let row: (Item) -> Row

    init(title: String,
         fetch: @escaping () async throws -> [Item],
         @ViewBuilder row: @escaping (Item) -> Row) {
        self.title = title
        self.fetch = fetch
        self.row = row
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                switch vm.phase {
                case .loaded:
                    if vm.items.isEmpty {
                        EmptyStateView(title: "暂无\(title)资料")
                    } else {
                        Text("共 \(vm.items.count) 条记录")
                            .font(.caption).foregroundStyle(ERPTheme.textTertiary)
                        ForEach(vm.items) { item in row(item) }
                    }
                default:
                    LoadStateBlock(phase: vm.phase) { Task { await load() } }
                }
            }
            .padding(.horizontal, ERPTheme.pagePadding)
            .padding(.top, 8).padding(.bottom, 96)
        }
        .background(ERPTheme.background.ignoresSafeArea())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .task(id: env.dataVersion) { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        await vm.load(fetch)
    }
}

// MARK: - 客户

struct CustomerListView: View {
    @EnvironmentObject private var env: AppEnvironment

    var body: some View {
        MasterListView(title: "客户",
                       fetch: { try await env.repositories.masters.customers() }) { (customer: Customer) in
            ERPCard(padding: 13) {
                HStack(spacing: 12) {
                    IconTile(symbol: "building.2",
                             tone: customer.level == "战略客户" ? .warning : .info, size: 40)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(customer.name).font(.subheadline.weight(.semibold)).lineLimit(1)
                        Text("\(customer.contact) · \(customer.city) · \(customer.level)")
                            .font(.caption).foregroundStyle(ERPTheme.textSecondary)
                        Text(customer.phone).font(.caption2).foregroundStyle(ERPTheme.textTertiary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 3) {
                        Text("应收").font(.caption2).foregroundStyle(ERPTheme.textTertiary)
                        Text(ERPFormat.compactMoney(customer.receivable))
                            .font(.caption.monospacedDigit().weight(.semibold))
                            .foregroundStyle(ERPTheme.warning)
                    }
                }
            }
        }
    }
}

// MARK: - 供应商

struct SupplierListView: View {
    @EnvironmentObject private var env: AppEnvironment

    var body: some View {
        MasterListView(title: "供应商",
                       fetch: { try await env.repositories.masters.suppliers() }) { (supplier: Supplier) in
            ERPCard(padding: 13) {
                HStack(spacing: 12) {
                    IconTile(symbol: "truck.box", tone: .accent, size: 40)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(supplier.name).font(.subheadline.weight(.semibold)).lineLimit(1)
                        Text("\(supplier.category) · \(supplier.contact)")
                            .font(.caption).foregroundStyle(ERPTheme.textSecondary)
                        Text(String(repeating: "★", count: supplier.rating))
                            .font(.caption2).foregroundStyle(ERPTheme.warning)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 3) {
                        Text("应付").font(.caption2).foregroundStyle(ERPTheme.textTertiary)
                        Text(ERPFormat.compactMoney(supplier.payable))
                            .font(.caption.monospacedDigit().weight(.semibold))
                    }
                }
            }
        }
    }
}

// MARK: - 商品

struct ProductListView: View {
    @EnvironmentObject private var env: AppEnvironment

    var body: some View {
        MasterListView(title: "商品",
                       fetch: { try await env.repositories.masters.products() }) { (product: Product) in
            ERPCard(padding: 13) {
                HStack(spacing: 12) {
                    IconTile(symbol: "cube.box", tone: product.isLowStock ? .danger : .success, size: 40)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(product.name).font(.subheadline.weight(.semibold)).lineLimit(1)
                        Text("\(product.sku) · \(product.category)")
                            .font(.caption).foregroundStyle(ERPTheme.textSecondary)
                        Text("库存 \(ERPFormat.number(product.stock)) \(product.unit) / 安全 \(ERPFormat.number(product.safetyStock))")
                            .font(.caption2)
                            .foregroundStyle(product.isLowStock ? ERPTheme.danger : ERPTheme.textTertiary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 3) {
                        Text(ERPFormat.money(product.price))
                            .font(.subheadline.monospacedDigit().weight(.semibold))
                        Text("成本 \(ERPFormat.compactMoney(product.cost))")
                            .font(.caption2).foregroundStyle(ERPTheme.textTertiary)
                    }
                }
            }
        }
    }
}
