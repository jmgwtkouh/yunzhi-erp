import SwiftUI

// ============================================================
// 仓储出库查找：多条件检索出库流水 + 汇总 + 登记出库
// 云端走 /v1/inventory/outbound/*，本地演示由 Mock 仓储实现相同语义
// ============================================================

struct OutboundSearchView: View {
    @EnvironmentObject private var env: AppEnvironment

    @State private var keyword = ""
    @State private var sku = ""
    @State private var warehouse = ""
    @State private var operatorName = ""
    @State private var useDateRange = false
    @State private var fromDate = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @State private var toDate = Date()

    @State private var applied = OutboundQuery()
    @State private var refreshToken = 0
    @State private var result: OutboundSearchResult?
    @State private var phase: LoadPhase = .idle
    @State private var showCreate = false

    private static let day: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    private var draftQuery: OutboundQuery {
        var q = OutboundQuery()
        q.keyword = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        q.sku = sku.trimmingCharacters(in: .whitespacesAndNewlines)
        q.warehouse = warehouse
        q.operatorName = operatorName
        if useDateRange {
            q.dateFrom = Self.day.string(from: fromDate)
            q.dateTo = Self.day.string(from: toDate)
        }
        return q
    }

    private var taskKey: String {
        "\(applied.keyword)|\(applied.sku)|\(applied.warehouse)|\(applied.operatorName)|" +
        "\(applied.dateFrom)|\(applied.dateTo)|\(refreshToken)|\(env.dataVersion)"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                summaryBlock
                filterCard
                resultBlock
            }
            .padding(.horizontal, ERPTheme.pagePadding)
            .padding(.top, 8).padding(.bottom, 96)
        }
        .background(ERPTheme.background.ignoresSafeArea())
        .navigationTitle("出库查找")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showCreate = true } label: {
                    Label("登记出库", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showCreate) {
            OutboundCreateView { refreshToken += 1; applied = draftQuery }
                .environmentObject(env)
        }
        .task(id: taskKey) { await load() }
        .refreshable { await load() }
    }

    // MARK: - 汇总

    private var summaryBlock: some View {
        let s = result?.summary
        return HStack(spacing: 12) {
            statTile(title: "出库单", value: s.map { ERPFormat.number($0.count) } ?? "—", tone: .info)
            statTile(title: "出库总量", value: s.map { ERPFormat.number($0.totalQuantity) } ?? "—", tone: .danger)
            statTile(title: "涉及仓库", value: s.map { "\($0.warehouses.count)" } ?? "—", tone: .success)
        }
    }

    private func statTile(title: String, value: String, tone: StatusTone) -> some View {
        ERPCard(padding: 13) {
            Text(title).font(.caption).foregroundStyle(ERPTheme.textSecondary)
            Text(value)
                .font(.title3.monospacedDigit().weight(.bold))
                .foregroundStyle(ERPTheme.tone(tone))
                .padding(.top, 5)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 筛选

    private var filterCard: some View {
        ERPCard {
            SectionHeader(title: "查找条件", subtitle: "关键词、仓库、日期区间、经办人、SKU 可组合使用")

            TextField("单号 / 商品 / 领用方 / 备注", text: $keyword)
                .textFieldStyle(.roundedBorder)
                .font(.subheadline)
            TextField("SKU / 商品编码", text: $sku)
                .textFieldStyle(.roundedBorder)
                .font(.subheadline)

            if let options = result?.options, !options.warehouses.isEmpty || !options.operators.isEmpty {
                HStack(spacing: 12) {
                    Picker("仓库", selection: $warehouse) {
                        Text("全部仓库").tag("")
                        ForEach(options.warehouses, id: \.self) { Text($0).tag($0) }
                    }
                    .pickerStyle(.menu)
                    Picker("经办人", selection: $operatorName) {
                        Text("全部经办人").tag("")
                        ForEach(options.operators, id: \.self) { Text($0).tag($0) }
                    }
                    .pickerStyle(.menu)
                }
                .font(.caption)
                .padding(.vertical, 4)
            }

            Toggle("按日期区间筛选", isOn: $useDateRange)
                .font(.subheadline)
            if useDateRange {
                HStack {
                    DatePicker("起", selection: $fromDate, displayedComponents: .date)
                        .labelsHidden()
                    Text("至").font(.caption).foregroundStyle(ERPTheme.textSecondary)
                    DatePicker("止", selection: $toDate, displayedComponents: .date)
                        .labelsHidden()
                }
            }

            HStack(spacing: 10) {
                Button {
                    applied = draftQuery
                    refreshToken += 1
                } label: {
                    Label("查找", systemImage: "magnifyingglass")
                        .font(.subheadline.weight(.medium))
                }
                .buttonStyle(.borderedProminent)

                Button("重置") {
                    keyword = ""; sku = ""; warehouse = ""; operatorName = ""
                    useDateRange = false
                    applied = OutboundQuery()
                    refreshToken += 1
                }
                .buttonStyle(.bordered)
                .font(.subheadline)
            }
            .padding(.top, 6)
        }
    }

    // MARK: - 结果

    @ViewBuilder private var resultBlock: some View {
        switch phase {
        case .loading, .idle:
            ProgressView("正在检索出库记录…")
                .frame(maxWidth: .infinity).padding(30)
        case .failed(let message):
            VStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.title2).foregroundStyle(ERPTheme.danger)
                Text(message).font(.caption).foregroundStyle(ERPTheme.textSecondary)
                Button("重试") { Task { await load() } }.buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity).padding(30)
        case .loaded:
            let rows = result?.items ?? []
            SectionHeader(title: "出库明细", subtitle: "共 \(result?.total ?? 0) 条匹配记录")
            if rows.isEmpty {
                EmptyStateView(symbol: "magnifyingglass", title: "没有符合条件的出库记录",
                               message: "调整筛选条件，或点击右上角登记一笔出库")
            } else {
                ForEach(rows) { mv in outboundCard(mv) }
            }
        }
    }

    private func outboundCard(_ mv: StockMovement) -> some View {
        ERPCard(padding: 13) {
            HStack(spacing: 12) {
                IconTile(symbol: "arrow.up.circle.fill", tone: .danger, size: 38)
                VStack(alignment: .leading, spacing: 4) {
                    Text(mv.productName).font(.subheadline.weight(.medium)).lineLimit(1)
                    Text("\(mv.code) · \(mv.sku ?? "—")")
                        .font(.caption2).foregroundStyle(ERPTheme.textTertiary)
                    Text("\(mv.warehouse) · \(mv.date) · \(mv.operatorName)")
                        .font(.caption2).foregroundStyle(ERPTheme.textTertiary)
                    if let receiver = mv.receiver, !receiver.isEmpty {
                        Text("领用方：\(receiver)")
                            .font(.caption2).foregroundStyle(ERPTheme.textSecondary)
                    }
                }
                Spacer()
                Text("-\(ERPFormat.number(mv.quantity)) \(mv.unit ?? "")")
                    .font(.subheadline.monospacedDigit().weight(.semibold))
                    .foregroundStyle(ERPTheme.danger)
            }
        }
    }

    private func load() async {
        phase = .loading
        do {
            result = try await env.repositories.inventory.searchOutbound(applied)
            phase = .loaded
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }
}

// MARK: - 登记出库

struct OutboundCreateView: View {
    @EnvironmentObject private var env: AppEnvironment
    @Environment(\.dismiss) private var dismiss
    let onDone: () -> Void

    @State private var items: [InventoryItem] = []
    @State private var selectedSKU = ""
    @State private var quantity = "1"
    @State private var warehouse = ""
    @State private var receiver = ""
    @State private var note = ""
    @State private var date = Date()
    @State private var busy = false
    @State private var errorText = ""

    private static let day: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    var body: some View {
        NavigationStack {
            Form {
                Section("商品") {
                    if items.isEmpty {
                        Text("暂无可用库存，请先在「拍照入库」建立库存")
                            .font(.caption).foregroundStyle(ERPTheme.textSecondary)
                    } else {
                        Picker("SKU", selection: $selectedSKU) {
                            ForEach(items) { item in
                                Text("\(item.sku) · \(item.productName)（可用 \(ERPFormat.number(item.quantity)) \(item.unit)）")
                                    .tag(item.sku)
                            }
                        }
                        .pickerStyle(.navigationLink)
                    }
                }
                Section("出库信息") {
                    TextField("数量", text: $quantity)
                        .keyboardType(.numberPad)
                    TextField("仓库（留空取默认仓）", text: $warehouse)
                    TextField("领用方 / 客户", text: $receiver)
                    TextField("备注", text: $note)
                    DatePicker("出库日期", selection: $date, displayedComponents: .date)
                }
                if !errorText.isEmpty {
                    Section {
                        Text(errorText).font(.caption).foregroundStyle(ERPTheme.danger)
                    }
                }
            }
            .navigationTitle("登记出库")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("确认") { Task { await submit() } }
                        .disabled(busy || selectedSKU.isEmpty)
                }
            }
            .task {
                do {
                    items = try await env.repositories.inventory
                        .list(query: nil, lowStockOnly: false)
                        .filter { $0.quantity > 0 }
                    if selectedSKU.isEmpty { selectedSKU = items.first?.sku ?? "" }
                } catch {
                    errorText = error.localizedDescription
                }
            }
        }
    }

    private func submit() async {
        guard let qty = Int(quantity), qty > 0 else {
            errorText = "请填写有效的出库数量"
            return
        }
        busy = true
        defer { busy = false }
        let draft = OutboundDraft(
            sku: selectedSKU, quantity: qty,
            warehouse: warehouse.trimmingCharacters(in: .whitespacesAndNewlines),
            receiver: receiver.trimmingCharacters(in: .whitespacesAndNewlines),
            note: note.trimmingCharacters(in: .whitespacesAndNewlines),
            date: Self.day.string(from: date))
        do {
            _ = try await env.repositories.inventory.createOutbound(draft)
            env.refresh()
            onDone()
            dismiss()
        } catch {
            errorText = error.localizedDescription
        }
    }
}
