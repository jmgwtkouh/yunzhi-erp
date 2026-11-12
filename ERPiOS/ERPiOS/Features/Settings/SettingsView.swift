import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var env: AppEnvironment
    @State private var showResetConfirm = false
    @State private var showChangePassword = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                profileCard

                if env.dataSource == .remote {
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeader(title: "账号", subtitle: "当前登录账号")
                        ERPCard {
                            InfoRow(label: "用户名", value: env.authUser?.username ?? "—")
                            InfoRow(label: "显示名", value: env.authUser?.displayName ?? "—")
                            InfoRow(label: "角色", value: env.authUser?.role == "admin" ? "管理员" : "普通用户")
                            HStack(spacing: 10) {
                                Button { showChangePassword = true } label: {
                                    Label("修改密码", systemImage: "key")
                                }
                                .buttonStyle(.bordered)
                                Button(role: .destructive) { env.signOut() } label: {
                                    Label("退出登录", systemImage: "rectangle.portrait.and.arrow.right")
                                }
                                .buttonStyle(.bordered)
                            }
                            .font(.caption)
                            .padding(.top, 8)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: "数据源", subtitle: "当前业务层通过 Repository 协议取数")
                    ERPCard(padding: 4) {
                        HStack(spacing: 12) {
                            IconTile(symbol: env.dataSource == .mock ? "internaldrive" : "cloud",
                                     tone: env.dataSource == .mock ? .warning : .success, size: 38)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(env.dataSource.rawValue)
                                    .font(.subheadline.weight(.semibold))
                                Text(env.dataSource == .mock ? "数据保存在本机，可离线演示" : "请求已指向配置的服务器")
                                    .font(.caption).foregroundStyle(ERPTheme.textSecondary)
                            }
                            Spacer()
                        }
                        .padding(10)
                        Divider().padding(.leading, 60)
                        NavigationLink(value: AppRoute.dataSourceSettings) {
                            HStack {
                                Label("配置云服务器", systemImage: "link.badge.plus")
                                    .font(.subheadline)
                                Spacer()
                                Image(systemName: "chevron.right").font(.caption)
                                    .foregroundStyle(ERPTheme.textTertiary)
                            }
                            .padding(10)
                        }
                        .buttonStyle(.plain)
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: "外观")
                    ERPCard {
                        Picker("主题", selection: $env.appearance) {
                            ForEach(AppearanceMode.allCases) { mode in
                                Text(mode.title).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: "本地演示数据")
                    ERPCard {
                        Text("清空本机所有业务数据，此操作不可撤销。")
                            .font(.caption).foregroundStyle(ERPTheme.textSecondary)
                        Button(role: .destructive) { showResetConfirm = true } label: {
                            Label("清空本地数据", systemImage: "arrow.counterclockwise")
                                .font(.subheadline.weight(.medium))
                        }
                        .padding(.top, 6)
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: "关于")
                    ERPCard {
                        InfoRow(label: "应用版本", value: "0.1.0 (Framework)")
                        InfoRow(label: "架构", value: "SwiftUI · MVVM · Repository")
                        InfoRow(label: "最低系统", value: "iOS 17.0")
                        InfoRow(label: "云接口", value: "REST v1（预留）")
                        InfoRow(label: "登录账号", value: env.currentUser.employeeNo)
                    }
                }
            }
            .padding(.horizontal, ERPTheme.pagePadding)
            .padding(.top, 8).padding(.bottom, 96)
        }
        .background(ERPTheme.background.ignoresSafeArea())
        .navigationTitle("我的")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showChangePassword) {
            ChangePasswordView().environmentObject(env)
        }
        .alert("清空本地数据？", isPresented: $showResetConfirm) {
            Button("重置", role: .destructive) { env.resetMockData() }
            Button("取消", role: .cancel) { }
        } message: {
            Text("本机所有业务数据将被清除，此操作不可撤销。")
        }
    }

    private var profileCard: some View {
        ERPCard {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(ERPTheme.gradient(.info))
                    Text(String(env.currentUser.name.prefix(1)))
                        .font(.title2.weight(.bold)).foregroundStyle(.white)
                }
                .frame(width: 54, height: 54)
                VStack(alignment: .leading, spacing: 4) {
                    Text(env.currentUser.name).font(.headline)
                    Text("\(env.currentUser.role) · \(env.currentUser.department)")
                        .font(.caption).foregroundStyle(ERPTheme.textSecondary)
                    Text(env.currentUser.employeeNo).font(.caption2)
                        .foregroundStyle(ERPTheme.textTertiary)
                }
                Spacer()
            }
        }
    }
}

// MARK: - 云数据源配置

struct DataSourceSettingsView: View {
    @EnvironmentObject private var env: AppEnvironment
    @State private var baseURL = ""
    @State private var token = ""
    @State private var message: String?

    private let endpoints: [(String, String)] = [
        ("工作台", "GET  v1/dashboard/summary"),
        ("销售订单", "GET  v1/sales-orders"),
        ("采购订单", "GET  v1/purchase-orders"),
        ("库存 / 流水", "GET  v1/inventory/items · /movements"),
        ("生产工单", "GET  v1/work-orders"),
        ("应收应付", "GET  v1/invoices"),
        ("基础资料", "GET  v1/master/{customers,suppliers,products}"),
        ("报表", "GET  v1/reports/overview")
    ]

    var body: some View {
        Form {
            Section("当前状态") {
                HStack {
                    Text("数据源")
                    Spacer()
                    Text(env.dataSource.rawValue)
                        .foregroundStyle(env.dataSource == .mock ? ERPTheme.warning : ERPTheme.success)
                }
                HStack {
                    Text("配置状态")
                    Spacer()
                    Text(env.isCloudReady ? "已填写服务器" : "未配置")
                        .foregroundStyle(ERPTheme.textSecondary)
                }
            }

            Section("服务器配置") {
                TextField("https://api.yourcompany.com", text: $baseURL)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                SecureField("Bearer Token（可选）", text: $token)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }

            Section {
                Button {
                    let ok = env.connectCloud(baseURL: baseURL, token: token)
                    message = ok
                        ? "已切换到云服务器，各页面会自动重新拉取数据。若后端未就绪，可在错误提示中点「切回本地演示」。"
                        : "服务器地址无效：请填写形如 http://公网IP:8080 的真实地址（不能使用示例地址 api.example.com）。当前数据源保持不变。"
                } label: {
                    Label("保存并启用云服务", systemImage: "cloud.fill")
                }
                Button {
                    env.useLocalData()
                    message = "已切回本地演示数据。"
                } label: {
                    Label("切回本地演示", systemImage: "internaldrive")
                }
            }

            Section("接口契约（后端联调对照）") {
                ForEach(endpoints, id: \.0) { item in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.0).font(.subheadline)
                        Text(item.1).font(.caption2.monospaced())
                            .foregroundStyle(ERPTheme.textTertiary)
                    }
                    .padding(.vertical, 2)
                }
            }

            Section {
                Text("所有业务页面只依赖 Domain/Repositories.swift 中的协议，切换数据源不需要改动任何界面代码。返回体字段与 Domain 模型一致即可；若后端使用 snake_case，把 Network.swift 中 decoder.keyDecodingStrategy 改为 .convertFromSnakeCase。")
                    .font(.caption)
                    .foregroundStyle(ERPTheme.textSecondary)
            }
        }
        .navigationTitle("数据源")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // 未配置时不显示示例地址，避免用户直接点保存而误切到云端
            baseURL = env.apiConfiguration.isConfigured ? env.apiConfiguration.baseURLString : ""
            token = env.apiConfiguration.token
        }
        .alert("提示",
               isPresented: Binding(get: { message != nil },
                                    set: { if !$0 { message = nil } })) {
            Button("好", role: .cancel) { }
        } message: {
            Text(message ?? "")
        }
    }
}
