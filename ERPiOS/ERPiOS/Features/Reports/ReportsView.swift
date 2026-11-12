import SwiftUI

struct ReportsView: View {
    @EnvironmentObject private var env: AppEnvironment
    @StateObject private var vm = LoadItemViewModel<ReportBundle>()
    @State private var series = "销售"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                switch vm.phase {
                case .loaded:
                    if let bundle = vm.item { content(bundle) }
                default:
                    LoadStateBlock(phase: vm.phase) { Task { await load() } }
                }
            }
            .padding(.horizontal, ERPTheme.pagePadding)
            .padding(.top, 8).padding(.bottom, 96)
        }
        .background(ERPTheme.background.ignoresSafeArea())
        .navigationTitle("报表中心")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: env.dataVersion) { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        await vm.load { try await env.repositories.reports.bundle() }
    }

    @ViewBuilder
    private func content(_ bundle: ReportBundle) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "经营趋势", subtitle: "近 12 个月 · 单位：万元")
            ERPCard {
                Picker("趋势", selection: $series) {
                    Text("销售").tag("销售")
                    Text("采购").tag("采购")
                }
                .pickerStyle(.segmented)
                .padding(.bottom, 8)
                let points = series == "销售" ? bundle.salesTrend : bundle.purchaseTrend
                BarChartView(points: points,
                             tint: series == "销售" ? ERPTheme.brand : ERPTheme.purple,
                             height: 170)
                let total = points.reduce(0) { $0 + $1.value }
                let peak = points.max(by: { $0.value < $1.value })
                HStack(spacing: 12) {
                    summaryTile("累计", String(format: "%.0f 万", total))
                    summaryTile("月均", String(format: "%.0f 万", total / Double(max(1, points.count))))
                    summaryTile("峰值", peak?.label ?? "-")
                }
                .padding(.top, 10)
            }
        }

        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "销售品类占比")
            ERPCard {
                HStack(spacing: 18) {
                    DonutChartView(shares: bundle.categoryShare)
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(bundle.categoryShare) { share in
                            MetricRow(label: share.name, value: "\(Int(share.value))%", tone: share.tone)
                        }
                    }
                    Spacer(minLength: 0)
                }
            }
        }

        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "库存分布")
            ERPCard {
                HStack(spacing: 18) {
                    DonutChartView(shares: bundle.warehouseShare)
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(bundle.warehouseShare) { share in
                            MetricRow(label: share.name, value: "\(Int(share.value))%", tone: share.tone)
                        }
                    }
                    Spacer(minLength: 0)
                }
            }
        }

        HStack(spacing: 10) {
            Image(systemName: "info.circle").foregroundStyle(ERPTheme.brand)
            Text("当前为本地演示数据。联云后同一份报表将请求 GET v1/reports/overview。")
                .font(.caption).foregroundStyle(ERPTheme.textSecondary)
        }
        .padding(12)
        .background(ERPTheme.brand.opacity(0.08),
                    in: RoundedRectangle(cornerRadius: ERPTheme.tileRadius, style: .continuous))
    }

    private func summaryTile(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption2).foregroundStyle(ERPTheme.textTertiary)
            Text(value).font(.subheadline.monospacedDigit().weight(.semibold))
                .foregroundStyle(ERPTheme.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(ERPTheme.brand.opacity(0.07),
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
