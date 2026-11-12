import SwiftUI

// MARK: - 销售订单列表

struct SalesListView: View {
    @EnvironmentObject private var env: AppEnvironment
    @StateObject private var vm = LoadListViewModel<SalesOrder>()
    @State private var query = ""
    @State private var filter = "全部"
    @State private var showCreate = false

    private var filters: [String] { ["全部"] + OrderStatus.allCases.map(\.rawValue) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                FilterChips(options: filters, selection: $filter)
                if let summary = summaryText {
                    Text(summary).font(.caption).foregroundStyle(ERPTheme.textTertiary)
                }
                switch vm.phase {
                case .loaded:
                    if vm.items.isEmpty {
                        EmptyStateView(symbol: "doc.text.magnifyingglass",
                                       title: "没有匹配的销售订单", message: "换个关键词或状态试试")
                    } else {
                        ForEach(vm.items) { order in
                            NavigationLink(value: AppRoute.salesDetail(order.id)) {
                                DocumentRow(code: order.code, title: order.customerName,
                                            date: order.date, amount: order.amount,
                                            status: order.status.rawValue, tone: order.status.tone,
                                            extra: "负责人 \(order.owner) · \(order.items.count) 个明细")
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
        .navigationTitle("销售订单")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $query, prompt: "搜索单号或客户名称")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showCreate = true } label: {
                    Image(systemName: "plus.circle.fill").foregroundStyle(ERPTheme.brand)
                }
            }
        }
        .sheet(isPresented: $showCreate) {
            CreateSalesOrderView { await load() }
                .environmentObject(env)
        }
        .task(id: "\(query)|\(filter)|\(env.dataVersion)") { await load() }
        .refreshable { await load() }
    }

    private var summaryText: String? {
        guard vm.phase == .loaded else { return nil }
        let total = vm.items.reduce(0) { $0 + $1.amount }
        return "共 \(vm.items.count) 单 · 合计 \(ERPFormat.money(total))"
    }

    private func load() async {
        let q = query
        let status = OrderStatus(rawValue: filter)
        await vm.load { try await env.repositories.sales.list(query: q, status: status) }
    }
}

// MARK: - 销售订单详情

struct SalesDetailView: View {
    let orderId: String
    @EnvironmentObject private var env: AppEnvironment
    @StateObject private var vm = LoadItemViewModel<SalesOrder>()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                switch vm.phase {
                case .loaded:
                    if let order = vm.item { detail(order) }
                    else { EmptyStateView(title: "订单不存在") }
                default:
                    LoadStateBlock(phase: vm.phase) { Task { await load() } }
                }
            }
            .padding(.horizontal, ERPTheme.pagePadding)
            .padding(.top, 8).padding(.bottom, 96)
        }
        .background(ERPTheme.background.ignoresSafeArea())
        .navigationTitle("订单详情")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: env.dataVersion) { await load() }
    }

    private func load() async {
        await vm.load { try await env.repositories.sales.detail(id: orderId) }
    }

    @ViewBuilder
    private func detail(_ order: SalesOrder) -> some View {
        ERPCard {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text(order.code).font(.caption.monospacedDigit())
                        .foregroundStyle(ERPTheme.textTertiary)
                    Text(order.customerName).font(.title3.weight(.bold))
                        .foregroundStyle(ERPTheme.textPrimary)
                }
                Spacer()
                StatusBadge(text: order.status.rawValue, tone: order.status.tone)
            }
            Divider().padding(.vertical, 6)
            Text(ERPFormat.money(order.amount))
                .font(.title.monospacedDigit().weight(.bold))
                .foregroundStyle(ERPTheme.brand)
        }

        ERPCard {
            SectionHeader(title: "基本信息")
            InfoRow(label: "下单日期", value: order.date)
            InfoRow(label: "负责人", value: order.owner)
            InfoRow(label: "明细行数", value: "\(order.items.count)")
            InfoRow(label: "备注", value: order.remark.isEmpty ? "无" : order.remark)
        }

        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "商品明细")
            ForEach(order.items) { line in
                ERPCard(padding: 13) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(line.productName).font(.subheadline.weight(.medium))
                            Text("\(ERPFormat.number(line.quantity)) × \(ERPFormat.money(line.unitPrice))")
                                .font(.caption).foregroundStyle(ERPTheme.textSecondary)
                        }
                        Spacer()
                        Text(ERPFormat.money(line.amount))
                            .font(.subheadline.monospacedDigit().weight(.semibold))
                    }
                }
            }
        }

        Text("变更订单状态")
            .font(.caption).foregroundStyle(ERPTheme.textTertiary)
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(OrderStatus.allCases) { status in
                    Button(status.rawValue) {
                        Task {
                            try? await env.repositories.sales.updateStatus(id: order.id, status: status)
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

// MARK: - 新建销售订单（演示本地写入路径）

struct CreateSalesOrderView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var env: AppEnvironment
    var onCreated: () async -> Void

    @State private var customerName = ""
    @State private var productName = "工业传感器 IS-200"
    @State private var quantity = "10"
    @State private var unitPrice = "1280"
    @State private var remark = ""
    @State private var saving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("客户") {
                    TextField("客户名称（必填）", text: $customerName)
                }
                Section("商品明细") {
                    TextField("商品名称", text: $productName)
                    TextField("数量", text: $quantity).keyboardType(.numberPad)
                    TextField("单价", text: $unitPrice).keyboardType(.decimalPad)
                }
                Section("备注") {
                    TextField("选填", text: $remark)
                }
                Section {
                    Text("当前为本地演示数据源，保存后写入本机数据库；联云后同一表单将提交到服务器。")
                        .font(.caption).foregroundStyle(ERPTheme.textSecondary)
                }
            }
            .navigationTitle("新建销售订单")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(saving ? "保存中" : "保存") { save() }.disabled(saving)
                }
            }
            .alert("无法保存",
                   isPresented: Binding(get: { errorMessage != nil },
                                        set: { if !$0 { errorMessage = nil } })) {
                Button("好", role: .cancel) { }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func save() {
        guard !customerName.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "请填写客户名称"
            return
        }
        saving = true
        Task {
            let qty = max(1, Int(quantity) ?? 1)
            let price = max(0, Double(unitPrice) ?? 0)
            let line = OrderLine(id: UUID().uuidString, productName: productName,
                                 quantity: qty, unitPrice: price)
            let order = SalesOrder(
                id: UUID().uuidString,
                code: "SO-2026-N\(Int(Date().timeIntervalSince1970) % 10000)",
                customerName: customerName, date: ERPFormat.today(),
                amount: line.amount, status: .draft,
                owner: env.currentUser.name, items: [line], remark: remark
            )
            do {
                try await env.repositories.sales.create(order)
                await onCreated()
                dismiss()
            } catch let err {
                errorMessage = err.localizedDescription
            }
            saving = false
        }
    }
}
