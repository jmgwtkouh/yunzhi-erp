import SwiftUI

// MARK: - 统一设计 token（玻璃拟态 · 与管理台 login.html 一致）

private enum Ink {
    static let primary = Color.black                                     // 主文字 · 纯黑
    static let secondary = Color(red: 0.25, green: 0.25, blue: 0.27)     // #404045 辅助文字
    static let faint = Color(red: 0.43, green: 0.43, blue: 0.47)         // #6E6E78 弱化文字
    static let ok = Color(red: 0.059, green: 0.616, blue: 0.463)
    static let bad = Color(red: 0.851, green: 0.325, blue: 0.310)
    /// 品牌图标渐变 #4c82ff → #8b5cf6
    static let logoGradient = LinearGradient(
        colors: [Color(red: 0.298, green: 0.510, blue: 1.0),
                 Color(red: 0.545, green: 0.361, blue: 0.965)],
        startPoint: .topLeading, endPoint: .bottomTrailing)
    /// 登录按钮蓝紫渐变 #4d5df3 → #6d4ef2
    static let buttonGradient = LinearGradient(
        colors: [Color(red: 0.302, green: 0.365, blue: 0.953),
                 Color(red: 0.427, green: 0.306, blue: 0.949)],
        startPoint: .leading, endPoint: .trailing)
}

/// 白色地球经纬线图标（与 Web 端 logo SVG 同形）
struct EarthGridMark: View {
    var lineWidth: CGFloat = 1.7
    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            ZStack {
                Circle()
                    .strokeBorder(lineWidth: lineWidth)
                    .frame(width: s * 0.75, height: s * 0.75)
                Ellipse()
                    .stroke(lineWidth: lineWidth)
                    .frame(width: s * 0.34, height: s * 0.75)
                Path { p in
                    p.move(to: CGPoint(x: s * 0.125, y: s * 0.5))
                    p.addLine(to: CGPoint(x: s * 0.875, y: s * 0.5))
                }
                .stroke(style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            }
            .foregroundStyle(.white)
            .frame(width: s, height: s)
        }
    }
}

/// 悬浮光泽球体（与 Web 端同一视觉：蓝/紫渐变 + 高光）
struct OrbView: View {
    var size: CGFloat
    var colors: [Color]
    var body: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: colors,
                                     center: UnitPoint(x: 0.32, y: 0.28),
                                     startRadius: 0,
                                     endRadius: size * 0.62))
                .shadow(color: (colors.last ?? .black).opacity(0.30),
                        radius: size * 0.16, y: size * 0.10)
            Circle()
                .fill(RadialGradient(colors: [Color.white.opacity(0.85), Color.white.opacity(0)],
                                     center: UnitPoint(x: 0.30, y: 0.26),
                                     startRadius: 0, endRadius: size * 0.34))
        }
        .frame(width: size, height: size)
    }
}

/// 会缓慢漂浮的装饰球：三条不同周期的正弦波叠加，形成不重复的有机漂移
struct FloatingOrb: View {
    var size: CGFloat
    var colors: [Color]
    var center: CGPoint
    var phase: Double
    var amplitude: CGFloat
    var period: Double
    var opacity: Double = 1
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let live = reduceMotion ? 0.0 : 1.0
            // x / y 用不同周期，避免轨迹变成一条直线或椭圆
            let dx = CGFloat(sin(t * 2 * .pi / period + phase)) * amplitude * live
            let dy = CGFloat(cos(t * 2 * .pi / (period * 1.27) + phase * 1.7)) * amplitude * 0.85 * live
            let breathe = 1 + CGFloat(sin(t * 2 * .pi / (period * 1.9) + phase * 0.6)) * 0.035 * live

            OrbView(size: size, colors: colors)
                .scaleEffect(breathe)
                .opacity(opacity)
                .position(x: center.x + dx, y: center.y + dy)
        }
    }
}

private let orbBlue: [Color] = [
    Color(red: 0.776, green: 0.831, blue: 1.0),
    Color(red: 0.490, green: 0.592, blue: 0.984),
    Color(red: 0.290, green: 0.388, blue: 0.941),
    Color(red: 0.184, green: 0.247, blue: 0.780)]
private let orbPurple: [Color] = [
    Color(red: 0.871, green: 0.831, blue: 1.0),
    Color(red: 0.655, green: 0.545, blue: 0.980),
    Color(red: 0.486, green: 0.361, blue: 0.941),
    Color(red: 0.337, green: 0.212, blue: 0.788)]

// MARK: - 登录页（玻璃拟态 · 与管理台登录页同一视觉语言）

struct LoginView: View {
    @EnvironmentObject private var env: AppEnvironment
    @State private var username = ""
    @State private var password = ""
    @State private var busy = false
    @State private var errorMessage: String?

    /// 服务状态定义与 Web 端一致：服务在线 / 服务离线 / 本地演示模式
    private enum ServerStatus: Equatable {
        case checking
        case online(version: String)
        case offline
        case localDemo
    }
    @State private var status: ServerStatus = .checking

    var body: some View {
        ZStack {
            // 白底：纯白为主，只在四角留极淡冷色光，避免整屏发灰
            LinearGradient(
                colors: [Color.white,
                         Color(red: 0.988, green: 0.988, blue: 0.995),
                         Color(red: 0.957, green: 0.961, blue: 0.978)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            // 悬浮光泽球：压到四角、低透明度，缓慢漂浮（小球的位移更明显，大球几乎只呼吸）
            GeometryReader { geo in
                let w = geo.size.width, h = geo.size.height
                FloatingOrb(size: w * 0.10, colors: orbPurple,
                            center: CGPoint(x: w * 0.02, y: h * 0.06),
                            phase: 0.4, amplitude: 22, period: 12, opacity: 0.45)
                FloatingOrb(size: w * 0.40, colors: orbBlue,
                            center: CGPoint(x: w * 1.02, y: h * 0.07),
                            phase: 2.1, amplitude: 28, period: 17, opacity: 0.55)
                FloatingOrb(size: w * 0.62, colors: orbPurple,
                            center: CGPoint(x: w * 0.02, y: h * 0.94),
                            phase: 4.3, amplitude: 20, period: 23, opacity: 0.42)
                FloatingOrb(size: w * 0.20, colors: orbBlue,
                            center: CGPoint(x: w * 0.95, y: h * 0.86),
                            phase: 5.6, amplitude: 26, period: 15, opacity: 0.40)
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    Spacer(minLength: 40)
                    loginCard
                        .padding(.horizontal, 22)
                    Spacer(minLength: 40)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .preferredColorScheme(.light)
        .task { await probeServer() }
    }

    // MARK: 玻璃卡片

    private var loginCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 品牌标识（居中）
            VStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(Ink.logoGradient)
                    EarthGridMark(lineWidth: 1.7)
                        .frame(width: 23, height: 23)
                }
                .frame(width: 44, height: 44)
                .shadow(color: Color(red: 0.275, green: 0.431, blue: 0.980).opacity(0.34), radius: 13, y: 6)

                VStack(spacing: 3) {
                    Text("云智 ERP")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Ink.primary)
                    Text("Enterprise Resource Planning")
                        .font(.system(size: 9, weight: .medium))
                        .tracking(1.9)
                        .textCase(.uppercase)
                        .foregroundStyle(Ink.faint)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 22)

            // 标题
            VStack(spacing: 6) {
                Text("欢迎回来")
                    .font(.system(size: 24, weight: .heavy))
                    .foregroundStyle(Ink.primary)
                Text("登录以继续访问企业管理控制台")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Ink.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 18)

            statusChip
                .frame(maxWidth: .infinity)
                .padding(.bottom, 18)

            VStack(alignment: .leading, spacing: 14) {
                field(title: "用户名") {
                    TextField("请输入用户名", text: $username,
                              prompt: Text("请输入用户名").foregroundColor(Ink.faint))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.asciiCapable)
                        .foregroundStyle(Ink.primary)
                        .font(.system(size: 16, weight: .medium))
                }

                field(title: "密码") {
                    SecureField("请输入密码", text: $password,
                                prompt: Text("请输入密码").foregroundColor(Ink.faint))
                        .foregroundStyle(Ink.primary)
                        .font(.system(size: 16, weight: .medium))
                }

                if let message = errorMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(Ink.bad)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Ink.bad.opacity(0.10),
                                    in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                }

                Button { login() } label: {
                    HStack {
                        Spacer()
                        if busy { ProgressView().tint(.white) }
                        Text(busy ? "登录中..." : "登录")
                            .font(.system(size: 14, weight: .semibold))
                            .tracking(2)
                        Spacer()
                    }
                    .padding(13)
                    .background(Ink.buttonGradient,
                                in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                    .foregroundStyle(.white)
                    .shadow(color: Color(red: 0.302, green: 0.365, blue: 0.953).opacity(0.34),
                            radius: 13, y: 7)
                }
                .buttonStyle(PressableButtonStyle())
                .disabled(busy)
                .padding(.top, 2)
            }

        }
        .padding(26)
        .background(cardBackground)
    }

    private var statusChip: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(statusColor)
                .frame(width: 6, height: 6)
            Text(statusText)
                .font(.system(size: 11))
                .foregroundStyle(Ink.secondary)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.86), in: Capsule())
        .overlay(Capsule().stroke(Color(red: 0.067, green: 0.094, blue: 0.235).opacity(0.10), lineWidth: 1))
    }

    private var statusText: String {
        switch status {
        case .checking: return "正在连接服务器..."
        case .online: return "服务在线"
        case .offline: return "服务离线"
        case .localDemo: return "本地演示模式"
        }
    }

    private var statusColor: Color {
        switch status {
        case .checking: return Color(red: 0.878, green: 0.627, blue: 0.125)
        case .online, .localDemo: return Ink.ok
        case .offline: return Ink.bad
        }
    }

    /// 白底磨砂玻璃卡片：白填充为主 + 系统毛玻璃只做轻微模糊 + 白色折射描边
    private var cardBackground: some View {
        let shape = RoundedRectangle(cornerRadius: 24, style: .continuous)
        return ZStack {
            // 毛玻璃只留一点模糊，不透明度压到很低，避免系统材质的中性灰把卡片染脏
            shape.fill(.ultraThinMaterial)
                .opacity(0.34)
            // 主体是白：左上略亮、右下略透，形成玻璃体积
            shape.fill(
                LinearGradient(colors: [Color.white.opacity(0.88),
                                        Color.white.opacity(0.70),
                                        Color.white.opacity(0.80)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            // 外圈极细的冷色发丝线，让白卡在白底上也有清晰边界
            shape.stroke(Color(red: 0.067, green: 0.094, blue: 0.235).opacity(0.055), lineWidth: 1)
            // 折射高光描边：左上亮、右下淡
            shape.stroke(
                LinearGradient(colors: [Color.white.opacity(1.0),
                                        Color.white.opacity(0.45),
                                        Color.white.opacity(0.10),
                                        Color.white.opacity(0.55)],
                               startPoint: .topLeading, endPoint: .bottomTrailing),
                lineWidth: 1.1
            )
            // 顶部镜面反光细线
            VStack {
                LinearGradient(colors: [.clear, Color.white.opacity(0.95), .clear],
                               startPoint: .leading, endPoint: .trailing)
                    .frame(height: 1)
                    .padding(.horizontal, 30)
                Spacer(minLength: 0)
            }
        }
        .compositingGroup()
        .shadow(color: Color(red: 0.09, green: 0.12, blue: 0.28).opacity(0.13),
                radius: 30, y: 16)
        .shadow(color: Color(red: 0.09, green: 0.12, blue: 0.28).opacity(0.05),
                radius: 6, y: 2)
    }

    /// 输入框：白底 + 发丝描边（干净、文字对比强）
    @ViewBuilder
    private func field<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Ink.primary)
            content()
                .padding(.horizontal, 13)
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.94),
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color(red: 0.067, green: 0.094, blue: 0.235).opacity(0.10), lineWidth: 1)
                )
                .shadow(color: Color(red: 0.09, green: 0.12, blue: 0.28).opacity(0.04),
                        radius: 2, y: 1)
        }
    }

    /// 动态获取服务状态与版本（与 Web 端同一后端 /health 数据源）
    private func probeServer() async {
        if env.dataSource == .mock {
            status = .localDemo
            return
        }
        let base = env.apiConfiguration.baseURLString
        guard let url = URL(string: base + "/health") else {
            status = .offline
            return
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 6
        request.cachePolicy = .reloadIgnoringLocalCacheData
        struct Health: Decodable { let version: String? }
        do {
            let (data, resp) = try await URLSession.shared.data(for: request)
            if let http = resp as? HTTPURLResponse, http.statusCode == 200,
               let health = try? JSONDecoder().decode(Health.self, from: data) {
                status = .online(version: health.version ?? "-")
            } else {
                status = .offline
            }
        } catch {
            status = .offline
        }
    }

    private func login() {
        guard !username.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "请输入用户名"
            return
        }
        guard !password.isEmpty else {
            errorMessage = "请输入密码"
            return
        }
        busy = true
        errorMessage = nil
        let name = username.trimmingCharacters(in: .whitespaces)
        Task {
            do {
                let session = try await env.repositories.auth.login(username: name, password: password)
                env.signIn(session)
            } catch let err {
                errorMessage = err.localizedDescription
            }
            busy = false
        }
    }
}

/// 登录按钮按压反馈（轻微，无闪烁动画）
private struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.92 : 1)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - 修改密码

struct ChangePasswordView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var env: AppEnvironment
    @State private var oldPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var busy = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("原密码") {
                    SecureField("当前密码", text: $oldPassword)
                }
                Section("新密码（至少 8 位）") {
                    SecureField("新密码", text: $newPassword)
                    SecureField("确认新密码", text: $confirmPassword)
                }
                if let message = errorMessage {
                    Section { Text(message).font(.caption).foregroundStyle(ERPTheme.danger) }
                }
                Section {
                    Text("修改成功后需要重新登录。")
                        .font(.caption).foregroundStyle(ERPTheme.textSecondary)
                }
            }
            .navigationTitle("修改密码")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(busy ? "保存中" : "保存") { save() }.disabled(busy)
                }
            }
        }
    }

    private func save() {
        guard newPassword.count >= 8 else {
            errorMessage = "新密码至少 8 位"
            return
        }
        guard newPassword == confirmPassword else {
            errorMessage = "两次输入的新密码不一致"
            return
        }
        busy = true
        errorMessage = nil
        Task {
            do {
                try await env.repositories.auth.changePassword(old: oldPassword, new: newPassword)
                dismiss()
                env.signOut()
            } catch let err {
                errorMessage = err.localizedDescription
            }
            busy = false
        }
    }
}
