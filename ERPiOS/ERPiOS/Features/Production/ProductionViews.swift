import SwiftUI

struct ProductionListView: View {
    @EnvironmentObject private var env: AppEnvironment
    @StateObject private var vm = LoadListViewModel<WorkOrder>()
    @State private var filter = "全部"

    private var filters: [String] { ["全部"] + WorkOrderStatus.allCases.map(\.rawValue) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                FilterChips(options: filters, selection: $filter)
                switch vm.phase {
                case .loaded:
                    if vm.items.isEmpty { EmptyStateView(symbol: "gearshape.2", title: "没有匹配的工单") }
                    ForEach(vm.items) { order in workOrderCard(order) }
                default:
                    LoadStateBlock(phase: vm.phase) { Task { await load() } }
                }
            }
            .padding(.horizontal, ERPTheme.pagePadding)
            .padding(.top, 8).padding(.bottom, 96)
        }
        .background(ERPTheme.background.ignoresSafeArea())
        .navigationTitle("生产工单")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: "\(filter)|\(env.dataVersion)") { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        let status = WorkOrderStatus(rawValue: filter)
        await vm.load { try await env.repositories.production.list(status: status) }
    }

    private func report(_ order: WorkOrder) {
        Task {
            let next = min(order.planQty, order.doneQty + 50)
            try? await env.repositories.production.reportProgress(id: order.id, doneQty: next)
            await load()
        }
    }

    @ViewBuilder
    private func workOrderCard(_ order: WorkOrder) -> some View {
        ERPCard(padding: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(order.code).font(.caption.monospacedDigit())
                        .foregroundStyle(ERPTheme.textTertiary)
                    Text(order.productName).font(.subheadline.weight(.semibold)).lineLimit(1)
                    Text(order.line).font(.caption).foregroundStyle(ERPTheme.textSecondary)
                }
                Spacer()
                StatusBadge(text: order.status.rawValue, tone: order.status.tone)
            }
            HStack {
                Text("完成 \(ERPFormat.number(order.doneQty)) / \(ERPFormat.number(order.planQty))")
                    .font(.caption).foregroundStyle(ERPTheme.textSecondary)
                Spacer()
                Text(ERPFormat.percent(order.progress))
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(ERPTheme.brand)
            }
            .padding(.top, 12)
            ProgressBar(value: order.progress, tone: order.status == .paused ? .danger : .info)
                .padding(.top, 6)
            HStack {
                Text("\(order.startDate) 至 \(order.dueDate)")
                    .font(.caption2).foregroundStyle(ERPTheme.textTertiary)
                Spacer()
                Button("报工 +50") { report(order) }
                    .font(.caption.weight(.semibold))
                    .buttonStyle(.bordered).tint(ERPTheme.brand)
                    .disabled(order.status == .completed)
            }
            .padding(.top, 8)
        }
    }
}
