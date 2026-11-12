import SwiftUI

struct FinanceListView: View {
    @EnvironmentObject private var env: AppEnvironment
    @StateObject private var vm = LoadListViewModel<Invoice>()
    @State private var typeFilter = "全部"
    @State private var statusFilter = "全部"
    @State private var settleTarget: Invoice?

    private var typeOptions: [String] { ["全部"] + InvoiceType.allCases.map(\.rawValue) }
    private var statusOptions: [String] { ["全部"] + InvoiceStatus.allCases.map(\.rawValue) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Picker("往来类型", selection: $typeFilter) {
                    ForEach(typeOptions, id: \.self) { Text($0).tag($0) }
                }
                .pickerStyle(.segmented)

                FilterChips(options: statusOptions, selection: $statusFilter)

                if vm.phase == .loaded {
                    ERPCard(padding: 14) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("未结金额").font(.caption).foregroundStyle(ERPTheme.textSecondary)
                                Text(ERPFormat.money(vm.items.reduce(0) { $0 + $1.remaining }))
                                    .font(.title3.monospacedDigit().weight(.bold))
                                    .foregroundStyle(ERPTheme.brand)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("单据数").font(.caption).foregroundStyle(ERPTheme.textSecondary)
                                Text("\(vm.items.count)").font(.title3.monospacedDigit().weight(.bold))
                            }
                        }
                    }
                }

                switch vm.phase {
                case .loaded:
                    if vm.items.isEmpty { EmptyStateView(symbol: "banknote", title: "没有匹配的往来单据") }
                    ForEach(vm.items) { invoice in
                        ERPCard(padding: 14) {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 5) {
                                    HStack(spacing: 6) {
                                        Text(invoice.type.rawValue)
                                            .font(.caption2.weight(.semibold))
                                            .foregroundStyle(invoice.type == .receivable ? ERPTheme.info : ERPTheme.purple)
                                        Text(invoice.code).font(.caption2.monospacedDigit())
                                            .foregroundStyle(ERPTheme.textTertiary)
                                    }
                                    Text(invoice.counterparty).font(.subheadline.weight(.semibold)).lineLimit(1)
                                    Text("到期 \(invoice.dueDate)")
                                        .font(.caption).foregroundStyle(ERPTheme.textSecondary)
                                }
                                Spacer()
                                StatusBadge(text: invoice.status.rawValue, tone: invoice.status.tone)
                            }
                            HStack(alignment: .bottom) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("已结 \(ERPFormat.money(invoice.settled))")
                                        .font(.caption2).foregroundStyle(ERPTheme.textTertiary)
                                    Text("未结 \(ERPFormat.money(invoice.remaining))")
                                        .font(.caption).foregroundStyle(ERPTheme.warning)
                                }
                                Spacer()
                                Text(ERPFormat.money(invoice.amount))
                                    .font(.subheadline.monospacedDigit().weight(.semibold))
                                if invoice.remaining > 0 {
                                    Button("结清") { settleTarget = invoice }
                                        .font(.caption.weight(.semibold))
                                        .buttonStyle(.borderedProminent).tint(ERPTheme.brand)
                                }
                            }
                            .padding(.top, 10)
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
        .navigationTitle("应收应付")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: "\(typeFilter)|\(statusFilter)|\(env.dataVersion)") { await load() }
        .refreshable { await load() }
        .alert("登记结算",
               isPresented: Binding(get: { settleTarget != nil },
                                    set: { if !$0 { settleTarget = nil } })) {
            Button("确认结清") {
                if let target = settleTarget { settle(target) }
            }
            Button("取消", role: .cancel) { }
        } message: {
            Text("将「\(settleTarget?.counterparty ?? "")」这笔 \(ERPFormat.money(settleTarget?.remaining ?? 0)) 登记为已结清？")
        }
    }

    private func load() async {
        let type = InvoiceType(rawValue: typeFilter)
        let status = InvoiceStatus(rawValue: statusFilter)
        await vm.load { try await env.repositories.finance.list(type: type, status: status) }
    }

    private func settle(_ invoice: Invoice) {
        Task {
            try? await env.repositories.finance.settle(id: invoice.id, amount: invoice.remaining)
            await load()
        }
    }
}
