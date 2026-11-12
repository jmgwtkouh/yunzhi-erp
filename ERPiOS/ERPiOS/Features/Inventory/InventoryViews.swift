import SwiftUI

struct InventoryListView: View {
    @EnvironmentObject private var env: AppEnvironment
    @StateObject private var vm = LoadListViewModel<InventoryItem>()
    @State private var query = ""
    @State private var lowOnly = false
    @State private var showStockIn = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                stockInEntry

                HStack(spacing: 10) {
                    Button {
                        withAnimation { lowOnly.toggle() }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: lowOnly ? "checkmark.circle.fill" : "circle")
                            Text("仅看低库存")
                        }
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(lowOnly ? ERPTheme.danger.opacity(0.12) : ERPTheme.card, in: Capsule())
                        .foregroundStyle(lowOnly ? ERPTheme.danger : ERPTheme.textSecondary)
                    }
                    .buttonStyle(.plain)
                    Spacer()
                    NavigationLink(value: AppRoute.movementList) {
                        Text("出入库记录").font(.caption.weight(.medium))
                    }
                    NavigationLink(value: AppRoute.outboundSearch) {
                        Text("出库查找").font(.caption.weight(.medium))
                    }
                }

                switch vm.phase {
                case .loaded:
                    if vm.items.isEmpty {
                        EmptyStateView(symbol: "shippingbox", title: "没有匹配的库存记录")
                    } else {
                        ForEach(vm.items) { item in inventoryCard(item) }
                    }
                default:
                    LoadStateBlock(phase: vm.phase) { Task { await load() } }
                }
            }
            .padding(.horizontal, ERPTheme.pagePadding)
            .padding(.top, 8).padding(.bottom, 96)
        }
        .background(ERPTheme.background.ignoresSafeArea())
        .navigationTitle("库存查询")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $query, prompt: "搜索商品名称或 SKU")
        .sheet(isPresented: $showStockIn) {
            StockInView().environmentObject(env)
        }
        .task(id: "\(query)|\(lowOnly)|\(env.dataVersion)") {
            await load()
            if ProcessInfo.processInfo.arguments.contains("-erpStockIn=1") { showStockIn = true }
        }
        .refreshable { await load() }
    }

    private var stockInEntry: some View {
        Button { showStockIn = true } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(LinearGradient(colors: [ERPTheme.brand, ERPTheme.accent],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: 3) {
                    Text("拍照入库")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(ERPTheme.textPrimary)
                    Text("拍下到货单，自动识别商品与数量")
                        .font(.caption2)
                        .foregroundStyle(ERPTheme.textTertiary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(ERPTheme.textTertiary)
            }
            .padding(14)
            .background(ERPTheme.card, in: RoundedRectangle(cornerRadius: ERPTheme.cardRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: ERPTheme.cardRadius, style: .continuous)
                    .strokeBorder(ERPTheme.brand.opacity(0.16), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func load() async {
        let q = query
        let low = lowOnly
        await vm.load { try await env.repositories.inventory.list(query: q, lowStockOnly: low) }
    }

    private func adjust(_ item: InventoryItem, delta: Int) {
        Task {
            try? await env.repositories.inventory.adjust(itemId: item.id, delta: delta)
            await load()
        }
    }

    @ViewBuilder
    private func inventoryCard(_ item: InventoryItem) -> some View {
        ERPCard(padding: 14) {
            HStack(alignment: .top) {
                IconTile(symbol: item.isLowStock ? "exclamationmark.triangle" : "shippingbox",
                         tone: item.isLowStock ? .danger : .success, size: 40)
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.productName).font(.subheadline.weight(.semibold)).lineLimit(1)
                    Text("\(item.sku) · \(item.warehouse)")
                        .font(.caption).foregroundStyle(ERPTheme.textSecondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(ERPFormat.number(item.quantity))
                        .font(.headline.monospacedDigit()).foregroundStyle(ERPTheme.textPrimary)
                    Text(item.unit).font(.caption2).foregroundStyle(ERPTheme.textTertiary)
                }
            }
            ProgressBar(value: Double(item.quantity) / Double(max(1, item.safetyStock * 3)),
                        tone: item.isLowStock ? .danger : .success)
                .padding(.top, 10)
            HStack {
                Text("安全库存 \(ERPFormat.number(item.safetyStock)) · 更新 \(item.updatedAt)")
                    .font(.caption2).foregroundStyle(ERPTheme.textTertiary)
                Spacer()
                Button("−10") { adjust(item, delta: -10) }
                    .font(.caption.weight(.semibold)).buttonStyle(.bordered).tint(ERPTheme.danger)
                Button("+10") { adjust(item, delta: 10) }
                    .font(.caption.weight(.semibold)).buttonStyle(.bordered).tint(ERPTheme.success)
            }
            .padding(.top, 8)
        }
    }
}

struct MovementListView: View {
    @EnvironmentObject private var env: AppEnvironment
    @StateObject private var vm = LoadListViewModel<StockMovement>()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                switch vm.phase {
                case .loaded:
                    if vm.items.isEmpty { EmptyStateView(title: "暂无出入库记录") }
                    ForEach(vm.items) { mv in
                        ERPCard(padding: 13) {
                            HStack(spacing: 12) {
                                IconTile(symbol: mv.type == .inbound ? "arrow.down.to.line" :
                                            mv.type == .outbound ? "arrow.up.from.line" : "arrow.left.arrow.right",
                                         tone: mv.type.tone, size: 38)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(mv.productName).font(.subheadline.weight(.medium)).lineLimit(1)
                                    HStack(spacing: 5) {
                                        Text("\(mv.code) · \(mv.warehouse)")
                                            .font(.caption2).foregroundStyle(ERPTheme.textTertiary)
                                        if mv.hasPhoto {
                                            Image(systemName: "camera.fill")
                                                .font(.system(size: 8, weight: .semibold))
                                                .foregroundStyle(ERPTheme.brand)
                                                .padding(3)
                                                .background(ERPTheme.brand.opacity(0.12), in: Circle())
                                        }
                                    }
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 4) {
                                    Text("\(mv.type == .outbound ? "-" : "+")\(ERPFormat.number(mv.quantity))")
                                        .font(.subheadline.monospacedDigit().weight(.semibold))
                                        .foregroundStyle(ERPTheme.tone(mv.type.tone))
                                    Text("\(mv.date) · \(mv.operatorName)")
                                        .font(.caption2).foregroundStyle(ERPTheme.textTertiary)
                                }
                            }
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
        .navigationTitle("出入库记录")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: env.dataVersion) { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        await vm.load { try await env.repositories.inventory.movements() }
    }
}
