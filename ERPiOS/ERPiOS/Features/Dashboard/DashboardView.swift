import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var env: AppEnvironment
    @StateObject private var vm = LoadItemViewModel<DashboardSnapshot>()

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                greetingCard
                switch vm.phase {
                case .loaded:
                    if let snapshot = vm.item { content(snapshot) }
                default:
                    LoadStateBlock(phase: vm.phase) { Task { await load() } }
                }
            }
            .padding(.horizontal, ERPTheme.pagePadding)
            .padding(.top, 8)
            .padding(.bottom, 96)
        }
        .background(ERPTheme.background.ignoresSafeArea())
        .navigationTitle("工作台")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 5) {
                    Circle().fill(env.dataSource == .mock ? ERPTheme.warning : ERPTheme.success)
                        .frame(width: 6, height: 6)
                    Text(env.dataSource == .mock ? "本地演示" : "云端已连接")
                        .font(.caption2)
                        .foregroundStyle(ERPTheme.textSecondary)
                }
            }
        }
        .task(id: env.dataVersion) { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        await vm.load { try await env.repositories.dashboard.snapshot() }
    }

    private var greetingCard: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(colors: [ERPTheme.brandDeep, ERPTheme.brand],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 7) {
                    Text("你好，\(env.currentUser.name)")
                        .font(.title2.weight(.bold)).foregroundStyle(.white)
                    Text("\(ERPFormat.today()) · \(env.currentUser.department)")
                        .font(.caption).foregroundStyle(.white.opacity(0.82))
                }
                Spacer()
                Image(systemName: "globe.asia.australia")
                    .font(.system(size: 52)).foregroundStyle(.white.opacity(0.20))
            }
            .padding(18)
        }
        .frame(height: 112)
        .clipShape(RoundedRectangle(cornerRadius: ERPTheme.cardRadius, style: .continuous))
    }

    @ViewBuilder
    private func content(_ s: DashboardSnapshot) -> some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(s.kpis) { kpi in kpiCard(kpi) }
        }

        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "快捷操作")
            ERPCard(padding: 14) {
                HStack(spacing: 0) {
                    ForEach(quickActions) { action in
                        Button {
                            env.router.openFromDashboard(action.route)
                        } label: {
                            VStack(spacing: 8) {
                                IconTile(symbol: action.symbol, tone: action.tone, size: 46)
                                Text(action.title).font(.caption).foregroundStyle(ERPTheme.textSecondary)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }

        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "我的待办", subtitle: "需要你处理的单据")
            ERPCard(padding: 6) {
                ForEach(s.todos) { todo in
                    Button {
                        env.router.openFromDashboard(route(for: todo.routeKey))
                    } label: {
                        HStack(spacing: 12) {
                            IconTile(symbol: todo.symbol, tone: .info, size: 38)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(todo.title).font(.subheadline.weight(.medium))
                                    .foregroundStyle(ERPTheme.textPrimary)
                                Text(todo.subtitle).font(.caption)
                                    .foregroundStyle(ERPTheme.textTertiary)
                            }
                            Spacer()
                            Text("\(todo.count)")
                                .font(.subheadline.monospacedDigit().weight(.bold))
                                .foregroundStyle(.white)
                                .frame(minWidth: 26, minHeight: 26)
                                .background(ERPTheme.brand, in: Capsule())
                            Image(systemName: "chevron.right").font(.caption)
                                .foregroundStyle(ERPTheme.textTertiary)
                        }
                        .padding(.horizontal, 10).padding(.vertical, 9)
                    }
                    .buttonStyle(.plain)
                    if todo.id != s.todos.last?.id {
                        Divider().padding(.leading, 60)
                    }
                }
            }
        }

        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "异常提醒", subtitle: "库存与回款风险")
            ForEach(s.alerts, id: \.self) { alert in
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption).foregroundStyle(ERPTheme.warning)
                    Text(alert).font(.caption).foregroundStyle(ERPTheme.textSecondary)
                    Spacer()
                }
                .padding(12)
                .background(ERPTheme.warning.opacity(0.10),
                            in: RoundedRectangle(cornerRadius: ERPTheme.tileRadius, style: .continuous))
            }
        }

        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "近 12 个月销售趋势", subtitle: "单位：万元")
            ERPCard { BarChartView(points: s.salesTrend, height: 158) }
        }

        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "最近订单", actionTitle: "查看全部") {
                env.router.openFromDashboard(.salesList)
            }
            ForEach(s.recentOrders) { order in
                NavigationLink(value: AppRoute.salesDetail(order.id)) {
                    DocumentRow(code: order.code, title: order.customerName, date: order.date,
                                amount: order.amount, status: order.status.rawValue,
                                tone: order.status.tone, extra: "负责人 \(order.owner)")
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func kpiCard(_ kpi: KPI) -> some View {
        ERPCard(padding: 14) {
            HStack(alignment: .top) {
                IconTile(symbol: kpi.symbol, tone: kpi.tone, size: 36)
                Spacer()
                Text(ERPFormat.signedPercent(kpi.delta / 100))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(kpi.delta >= 0 ? ERPTheme.success : ERPTheme.danger)
            }
            Text(kpi.title).font(.caption).foregroundStyle(ERPTheme.textSecondary)
                .padding(.top, 10)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(kpi.value).font(.title2.monospacedDigit().weight(.bold))
                    .foregroundStyle(ERPTheme.textPrimary)
                Text(kpi.unit).font(.caption2).foregroundStyle(ERPTheme.textTertiary)
            }
        }
    }

    private struct QuickAction: Identifiable {
        let id = UUID()
        let title: String
        let symbol: String
        let tone: StatusTone
        let route: AppRoute
    }

    private var quickActions: [QuickAction] {
        [QuickAction(title: "销售订单", symbol: "doc.text", tone: .info, route: .salesList),
         QuickAction(title: "采购管理", symbol: "cart", tone: .accent, route: .purchaseList),
         QuickAction(title: "库存查询", symbol: "shippingbox", tone: .success, route: .inventoryList),
         QuickAction(title: "生产工单", symbol: "gearshape.2", tone: .warning, route: .productionList)]
    }

    private func route(for key: String) -> AppRoute {
        switch key {
        case "sales": return .salesList
        case "purchase": return .purchaseList
        case "production": return .productionList
        case "finance": return .financeList
        default: return .salesList
        }
    }
}
