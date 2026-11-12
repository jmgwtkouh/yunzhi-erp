import SwiftUI

struct BusinessHubView: View {
    @EnvironmentObject private var env: AppEnvironment

    private struct Module: Identifiable {
        let id = UUID()
        let title: String
        let symbol: String
        let tone: StatusTone
        let route: AppRoute
    }

    private struct Group: Identifiable {
        let id = UUID()
        let title: String
        let subtitle: String
        let items: [Module]
    }

    private var groups: [Group] {
        [
            Group(title: "销售与采购", subtitle: "从订单到交付的主链路", items: [
                Module(title: "销售订单", symbol: "doc.text.fill", tone: .info, route: .salesList),
                Module(title: "采购订单", symbol: "cart.fill", tone: .accent, route: .purchaseList),
                Module(title: "出入库记录", symbol: "arrow.left.arrow.right", tone: .success, route: .movementList)
            ]),
            Group(title: "仓储与生产", subtitle: "库存、产线与工单进度", items: [
                Module(title: "库存查询", symbol: "shippingbox.fill", tone: .success, route: .inventoryList),
                Module(title: "出库查找", symbol: "magnifyingglass", tone: .info, route: .outboundSearch),
                Module(title: "生产工单", symbol: "gearshape.2.fill", tone: .warning, route: .productionList)
            ]),
            Group(title: "财务与基础资料", subtitle: "往来结算与主数据", items: [
                Module(title: "应收应付", symbol: "banknote.fill", tone: .danger, route: .financeList),
                Module(title: "客户", symbol: "person.2.fill", tone: .info, route: .customers),
                Module(title: "供应商", symbol: "building.2.fill", tone: .accent, route: .suppliers),
                Module(title: "商品", symbol: "cube.box.fill", tone: .success, route: .products)
            ])
        ]
    }

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 12)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                ForEach(groups) { group in
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeader(title: group.title, subtitle: group.subtitle)
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(group.items) { item in
                                NavigationLink(value: item.route) {
                                    VStack(spacing: 10) {
                                        IconTile(symbol: item.symbol, tone: item.tone, size: 46)
                                        Text(item.title)
                                            .font(.caption.weight(.medium))
                                            .foregroundStyle(ERPTheme.textPrimary)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(ERPTheme.card,
                                                in: RoundedRectangle(cornerRadius: ERPTheme.cardRadius,
                                                                     style: .continuous))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                Button {
                    env.router.push(.dataSourceSettings)
                } label: {
                    HStack(spacing: 12) {
                        IconTile(symbol: "cloud", tone: env.dataSource == .mock ? .warning : .success, size: 40)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("数据源：\(env.dataSource.rawValue)")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(ERPTheme.textPrimary)
                            Text("业务层已按 Repository 协议解耦，联云无需改界面")
                                .font(.caption).foregroundStyle(ERPTheme.textSecondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption)
                            .foregroundStyle(ERPTheme.textTertiary)
                    }
                    .padding(14)
                    .background(ERPTheme.card,
                                in: RoundedRectangle(cornerRadius: ERPTheme.cardRadius, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, ERPTheme.pagePadding)
            .padding(.top, 8)
            .padding(.bottom, 96)
        }
        .background(ERPTheme.background.ignoresSafeArea())
        .navigationTitle("业务")
        .navigationBarTitleDisplayMode(.inline)
    }
}
