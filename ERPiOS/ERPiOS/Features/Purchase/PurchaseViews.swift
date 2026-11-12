import SwiftUI

struct PurchaseListView: View {
    @EnvironmentObject private var env: AppEnvironment
    @StateObject private var vm = LoadListViewModel<PurchaseOrder>()
    @State private var query = ""
    @State private var filter = "全部"

    private var filters: [String] { ["全部"] + PurchaseStatus.allCases.map(\.rawValue) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                FilterChips(options: filters, selection: $filter)
                switch vm.phase {
                case .loaded:
                    if vm.items.isEmpty {
                        EmptyStateView(symbol: "cart", title: "没有匹配的采购单")
                    } else {
                        Text("共 \(vm.items.count) 单 · 合计 \(ERPFormat.money(vm.items.reduce(0) { $0 + $1.amount }))")
                            .font(.caption).foregroundStyle(ERPTheme.textTertiary)
                        ForEach(vm.items) { order in
                            NavigationLink(value: AppRoute.purchaseDetail(order.id)) {
                                DocumentRow(code: order.code, title: order.supplierName,
                                            date: order.date, amount: order.amount,
                                            status: order.status.rawValue, tone: order.status.tone,
                                            extra: "预计到货 \(order.eta)")
                            }
                            .buttonStyle(.plain)
                        }
                    }
                default:
                    LoadStateBlock(phase: vm.phase) { Task { await load() } }
                }
            }
            .padding(.horizontal, ERPTheme.pagePadding)
            .padding(.top, 8).padding(.bottom, 96)
        }
        .background(ERPTheme.background.ignoresSafeArea())
        .navigationTitle("采购订单")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $query, prompt: "搜索单号或供应商")
        .task(id: "\(query)|\(filter)|\(env.dataVersion)") { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        let q = query
        let status = PurchaseStatus(rawValue: filter)
        await vm.load { try await env.repositories.purchase.list(query: q, status: status) }
    }
}

struct PurchaseDetailView: View {
    let orderId: String
    @EnvironmentObject private var env: AppEnvironment
    @StateObject private var vm = LoadItemViewModel<PurchaseOrder>()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                switch vm.phase {
                case .loaded:
                    if let order = vm.item { detail(order) }
                    else { EmptyStateView(title: "采购单不存在") }
                default:
                    LoadStateBlock(phase: vm.phase) { Task { await load() } }
                }
            }
            .padding(.horizontal, ERPTheme.pagePadding)
            .padding(.top, 8).padding(.bottom, 96)
        }
        .background(ERPTheme.background.ignoresSafeArea())
        .navigationTitle("采购单详情")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: env.dataVersion) { await load() }
    }

    private func load() async {
        await vm.load { try await env.repositories.purchase.detail(id: orderId) }
    }

    @ViewBuilder
    private func detail(_ order: PurchaseOrder) -> some View {
        ERPCard {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text(order.code).font(.caption.monospacedDigit())
                        .foregroundStyle(ERPTheme.textTertiary)
                    Text(order.supplierName).font(.title3.weight(.bold))
                }
                Spacer()
                StatusBadge(text: order.status.rawValue, tone: order.status.tone)
            }
            Divider().padding(.vertical, 6)
            Text(ERPFormat.money(order.amount))
                .font(.title.monospacedDigit().weight(.bold)).foregroundStyle(ERPTheme.brand)
        }

        ERPCard {
            SectionHeader(title: "基本信息")
            InfoRow(label: "下单日期", value: order.date)
            InfoRow(label: "预计到货", value: order.eta)
            InfoRow(label: "采购部门", value: order.owner)
        }

        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "采购明细")
            ForEach(order.items) { line in
                ERPCard(padding: 13) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(line.productName).font(.subheadline.weight(.medium))
                            Text("\(ERPFormat.number(line.quantity)) × \(ERPFormat.money(line.unitPrice))")
                                .font(.caption).foregroundStyle(ERPTheme.textSecondary)
                        }
                        Spacer()
                        Text(ERPFormat.money(line.amount)).font(.subheadline.monospacedDigit().weight(.semibold))
                    }
                }
            }
        }

        Text("变更采购状态").font(.caption).foregroundStyle(ERPTheme.textTertiary)
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(PurchaseStatus.allCases) { status in
                    Button(status.rawValue) {
                        Task {
                            try? await env.repositories.purchase.updateStatus(id: order.id, status: status)
                            await load()
                        }
                    }
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(order.status == status ? ERPTheme.brand : ERPTheme.card, in: Capsule())
                    .foregroundStyle(order.status == status ? Color.white : ERPTheme.textSecondary)
                }
            }
        }
    }
}
