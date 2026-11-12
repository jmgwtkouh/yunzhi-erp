import SwiftUI

// MARK: - 容器与排版

struct ERPCard<Content: View>: View {
    private let padding: CGFloat
    private let content: Content

    init(padding: CGFloat = 16, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        // 必须用 VStack 把 ViewBuilder 的多个子视图收成一个整体，
        // 否则 TupleView 会把 padding / frame / background 分发到每个子视图，
        // 在 LazyVGrid 中就会被拆成多张卡片。
        VStack(alignment: .leading, spacing: 0) {
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(padding)
        .background(ERPTheme.card, in: RoundedRectangle(cornerRadius: ERPTheme.cardRadius, style: .continuous))
    }
}

struct SectionHeader: View {
    let title: String
    var subtitle: String? = nil
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline).foregroundStyle(ERPTheme.textPrimary)
                if let subtitle = subtitle {
                    Text(subtitle).font(.caption).foregroundStyle(ERPTheme.textSecondary)
                }
            }
            Spacer(minLength: 8)
            if let actionTitle = actionTitle, let action = action {
                Button(action: action) {
                    HStack(spacing: 2) {
                        Text(actionTitle)
                        Image(systemName: "chevron.right")
                    }
                    .font(.subheadline.weight(.medium))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct StatusBadge: View {
    let text: String
    let tone: StatusTone

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(ERPTheme.tone(tone))
            .padding(.horizontal, 9).padding(.vertical, 4)
            .background(ERPTheme.tone(tone).opacity(0.13), in: Capsule())
    }
}

struct IconTile: View {
    let symbol: String
    var tone: StatusTone = .info
    var size: CGFloat = 44

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .fill(ERPTheme.tone(tone).opacity(0.14))
            Image(systemName: symbol)
                .font(.system(size: size * 0.44, weight: .semibold))
                .foregroundStyle(ERPTheme.tone(tone))
        }
        .frame(width: size, height: size)
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    var valueColor: Color = ERPTheme.textPrimary
    var monoAmount: Bool = false

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(label).font(.subheadline).foregroundStyle(ERPTheme.textSecondary)
            Spacer()
            Text(value)
                .font(monoAmount ? .subheadline.monospacedDigit().weight(.semibold) : .subheadline.weight(.medium))
                .foregroundStyle(valueColor)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 7)
    }
}

struct FilterChips: View {
    let options: [String]
    @Binding var selection: String

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(options, id: \.self) { option in
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) { selection = option }
                    } label: {
                        Text(option)
                            .font(.subheadline.weight(selection == option ? .semibold : .regular))
                            .foregroundStyle(selection == option ? Color.white : ERPTheme.textSecondary)
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(selection == option ? ERPTheme.brand : ERPTheme.card,
                                        in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
    }
}

struct ProgressBar: View {
    let value: Double
    var tone: StatusTone = .info
    var height: CGFloat = 8

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(ERPTheme.tone(tone).opacity(0.15))
                Capsule()
                    .fill(ERPTheme.gradient(tone))
                    .frame(width: max(0, min(1, value)) * geo.size.width)
            }
        }
        .frame(height: height)
    }
}

// MARK: - 状态视图

struct LoadingBlock: View {
    var text: String = "加载中..."
    var body: some View {
        VStack(spacing: 10) {
            ProgressView()
            Text(text).font(.caption).foregroundStyle(ERPTheme.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(36)
    }
}

struct EmptyStateView: View {
    var symbol: String = "tray"
    var title: String = "暂无数据"
    var message: String = "调整筛选条件后再试"

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: symbol).font(.system(size: 34)).foregroundStyle(ERPTheme.textTertiary)
            Text(title).font(.subheadline.weight(.medium)).foregroundStyle(ERPTheme.textSecondary)
            Text(message).font(.caption).foregroundStyle(ERPTheme.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(36)
    }
}

struct ErrorStateView: View {
    @EnvironmentObject private var env: AppEnvironment
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "wifi.exclamationmark").font(.system(size: 32)).foregroundStyle(ERPTheme.danger)
            Text(message).font(.caption).foregroundStyle(ERPTheme.textSecondary).multilineTextAlignment(.center)
            Button("重新加载", action: retry).buttonStyle(.borderedProminent).tint(ERPTheme.brand)
            // 云端不可用时给一条自救路径，避免整个 App 停在空白状态
            if env.dataSource == .remote {
                Button { env.signOut() } label: {
                    Label("重新登录", systemImage: "person.crop.circle.badge.exclamationmark")
                }
                .buttonStyle(.bordered).tint(ERPTheme.brand)
                Button {
                    env.useLocalData()
                } label: {
                    Label("切回本地演示", systemImage: "internaldrive")
                }
                .buttonStyle(.bordered).tint(ERPTheme.brand)
                Text("服务器暂不可用？先切回本地数据，配置好地址后再重新启用云服务。")
                    .font(.caption2)
                    .foregroundStyle(ERPTheme.textTertiary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(28)
    }
}

/// 列表页统一的状态分支；内容为空时由调用方插入 EmptyStateView
struct LoadStateBlock: View {
    let phase: LoadPhase
    var isEmpty: Bool = false
    let retry: () -> Void

    @ViewBuilder var body: some View {
        switch phase {
        case .idle, .loading:
            LoadingBlock()
        case .failed(let message):
            ErrorStateView(message: message, retry: retry)
        case .loaded:
            if isEmpty { EmptyStateView() }
        }
    }
}

// MARK: - 业务行

struct DocumentRow: View {
    let code: String
    let title: String
    let date: String
    let amount: Double
    let status: String
    let tone: StatusTone
    var extra: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(code).font(.caption.monospacedDigit()).foregroundStyle(ERPTheme.textTertiary)
                    Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(ERPTheme.textPrimary)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                StatusBadge(text: status, tone: tone)
            }
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(date).font(.caption).foregroundStyle(ERPTheme.textSecondary)
                    if let extra = extra {
                        Text(extra).font(.caption2).foregroundStyle(ERPTheme.textTertiary)
                    }
                }
                Spacer()
                Text(ERPFormat.money(amount))
                    .font(.subheadline.monospacedDigit().weight(.semibold))
                    .foregroundStyle(ERPTheme.textPrimary)
            }
        }
        .padding(14)
        .background(ERPTheme.card, in: RoundedRectangle(cornerRadius: ERPTheme.cardRadius, style: .continuous))
    }
}

struct MetricRow: View {
    let label: String
    let value: String
    var tone: StatusTone = .neutral

    var body: some View {
        HStack {
            Circle().fill(ERPTheme.tone(tone)).frame(width: 8, height: 8)
            Text(label).font(.caption).foregroundStyle(ERPTheme.textSecondary)
            Spacer()
            Text(value).font(.caption.monospacedDigit().weight(.semibold)).foregroundStyle(ERPTheme.textPrimary)
        }
    }
}

// MARK: - 图表（纯 SwiftUI，无第三方依赖）

struct BarChartView: View {
    let points: [ReportPoint]
    var tint: Color = ERPTheme.brand
    var height: CGFloat = 150
    private var maxValue: Double { max(1, points.map(\.value).max() ?? 1) }

    var body: some View {
        HStack(alignment: .bottom, spacing: 5) {
            ForEach(points) { point in
                VStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(LinearGradient(colors: [tint, tint.opacity(0.42)],
                                             startPoint: .top, endPoint: .bottom))
                        .frame(height: max(6, CGFloat(point.value / maxValue) * (height - 26)))
                    Text(point.label)
                        .font(.system(size: 9))
                        .foregroundStyle(ERPTheme.textTertiary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: height)
    }
}

struct DonutChartView: View {
    let shares: [CategoryShare]
    private var total: Double { max(1, shares.reduce(0) { $0 + $1.value }) }

    private func start(_ index: Int) -> CGFloat {
        CGFloat(shares.prefix(index).reduce(0) { $0 + $1.value } / total)
    }
    private func end(_ index: Int) -> CGFloat {
        CGFloat(shares.prefix(index + 1).reduce(0) { $0 + $1.value } / total)
    }

    var body: some View {
        ZStack {
            Circle().stroke(ERPTheme.separator.opacity(0.35), lineWidth: 20)
            ForEach(Array(shares.enumerated()), id: \.element.id) { index, share in
                Circle()
                    .trim(from: start(index), to: end(index))
                    .stroke(ERPTheme.tone(share.tone),
                            style: StrokeStyle(lineWidth: 20, lineCap: .butt))
                    .rotationEffect(.degrees(-90))
            }
            VStack(spacing: 2) {
                Text(shares.isEmpty ? "—" : "100%").font(.title3.weight(.bold)).foregroundStyle(ERPTheme.textPrimary)
                Text(shares.isEmpty ? "暂无数据" : "占比").font(.caption2).foregroundStyle(ERPTheme.textTertiary)
            }
        }
        .frame(width: 132, height: 132)
    }
}
