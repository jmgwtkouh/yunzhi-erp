import SwiftUI

enum AppearanceMode: Int, CaseIterable, Identifiable {
    case system = 0, light = 1, dark = 2
    var id: Int { rawValue }
    var title: String {
        switch self {
        case .system: return "跟随系统"
        case .light: return "浅色"
        case .dark: return "深色"
        }
    }
    var scheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

/// 全局依赖注入容器：View 通过 @EnvironmentObject 取得，
/// 切换数据源后 dataVersion +1，所有页面的 .task(id:) 会自动重新拉取。
@MainActor
final class AppEnvironment: ObservableObject {
    private static let modeKey = "erp.datasource.mode"
    private static let configKey = "erp.api.configuration"
    private static let appearanceKey = "erp.appearance"
    private static let sessionKey = "erp.auth.sessionToken"
    private static let userKey = "erp.auth.user"

    @Published var dataSource: DataSourceMode { didSet { persist(); rebuild() } }
    @Published var apiConfiguration: APIConfiguration { didSet { persist(); rebuild() } }
    @Published var appearance: AppearanceMode { didSet { persist() } }
    @Published private(set) var dataVersion: Int = 0
    /// 界面展示用的「当前用户」。
    /// 云端登录时以真实登录账号为准，只有本地演示模式才使用占位账号，
    /// 避免普通账号登录后仍显示成管理员。
    var currentUser: AppUser {
        guard dataSource == .remote else { return Seed.currentUser() }
        guard let user = authUser else {
            // 云端但账号信息尚未就绪：给中性占位，避免误显示演示用「管理员」
            return AppUser(id: "—", name: "未登录", role: "普通用户",
                           department: "—", employeeNo: "—")
        }
        return AppUser(
            id: user.username,
            name: user.displayName.isEmpty ? user.username : user.displayName,
            role: user.role == "admin" ? "管理员" : "普通用户",
            department: "云平台",
            employeeNo: user.username
        )
    }
    @Published private(set) var isAuthenticated: Bool = true
    @Published private(set) var authUser: AuthUser?

    let router = AppRouter()
    let mockProvider: MockRepositoryProvider
    private(set) var repositories: RepositoryProvider
    private(set) var apiClient: URLSessionAPIClient?

    init() {
        let defaults = UserDefaults.standard
        var mode = defaults.string(forKey: Self.modeKey)
            .flatMap { DataSourceMode(rawValue: $0) } ?? .mock
        var config: APIConfiguration = defaults.data(forKey: Self.configKey)
            .flatMap { try? JSONDecoder().decode(APIConfiguration.self, from: $0) } ?? .default
        let appearance = AppearanceMode(rawValue: defaults.integer(forKey: Self.appearanceKey)) ?? .system

        // 防御性回退：若上次切到「云服务器」但地址未配置（或仍是示例地址），
        // 启动自动回到本地数据，避免所有页面因 notConfigured 变成空白。
        if mode == .remote && !config.isConfigured {
            mode = .mock
            defaults.set(DataSourceMode.mock.rawValue, forKey: Self.modeKey)
        }
        // 旧版本可能把示例地址持久化了，统一替换为已部署的服务器地址，
        // 设置页即可看到预填地址，避免再次出现「启用云端却没填地址」。
        if !config.isConfigured {
            config = .default
            if let data = try? JSONEncoder().encode(config) {
                defaults.set(data, forKey: Self.configKey)
            }
        }

        let mock = MockRepositoryProvider()
        self.dataSource = mode
        self.apiConfiguration = config
        self.appearance = appearance
        self.mockProvider = mock
        self.repositories = RepositoryFactory.make(mode: mode, configuration: config, mock: mock)

        // QA 辅助：通过启动参数指定初始 Tab / 页面，便于自动化截图与回归验证。
        // 正常启动时不会带这些参数，行为完全不变。
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-erpTab=business") { router.selectedTab = .business }
        if args.contains("-erpTab=reports") { router.selectedTab = .reports }
        if args.contains("-erpTab=settings") { router.selectedTab = .settings }
        if args.contains("-erpRoute=salesList") {
            router.selectedTab = .business
            router.paths[.business] = [.salesList]
        }
        if args.contains("-erpRoute=inventory") || args.contains("-erpStockIn=1") {
            router.selectedTab = .business
            router.paths[.business] = [.inventoryList]
        }
        if args.contains("-erpRoute=outbound") {
            router.selectedTab = .business
            router.paths[.business] = [.outboundSearch]
        }
        if args.contains("-erpRoute=dataSource") {
            router.selectedTab = .settings
            router.paths[.settings] = [.dataSourceSettings]
        }
        // QA：强制本地模式（截图/回归用）
        if args.contains("-erpLocal=1") {
            if args.contains("-erpDemoSeed=1") { mock.db.loadDemoSeed() }
            dataSource = .mock
        }
        // 强制云端模式（联调/回归用，不写持久化）
        if args.contains("-erpCloud=1") {
            dataSource = .remote
            apiConfiguration = .default
        }
        // 联调：注入会话 Token，用于回归「已登录态 + 云端鉴权请求」
        if let tokenArg = args.first(where: { $0.hasPrefix("-erpToken=") }) {
            defaults.set(String(tokenArg.dropFirst("-erpToken=".count)), forKey: Self.sessionKey)
        }
        rebuild()
    }

    var colorScheme: ColorScheme? { appearance.scheme }
    var isCloudReady: Bool { apiConfiguration.isConfigured }
    /// 本地演示免登录；云端数据源强制登录
    var requiresLogin: Bool { dataSource == .remote }

    func signIn(_ session: AuthSession) {
        let defaults = UserDefaults.standard
        defaults.set(session.token, forKey: Self.sessionKey)
        if let data = try? JSONEncoder().encode(session.user) {
            defaults.set(data, forKey: Self.userKey)
        }
        apiClient?.sessionToken = session.token
        authUser = session.user
        isAuthenticated = true
        dataVersion += 1
    }

    func signOut() {
        let defaults = UserDefaults.standard
        let token = defaults.string(forKey: Self.sessionKey) ?? ""
        defaults.removeObject(forKey: Self.sessionKey)
        defaults.removeObject(forKey: Self.userKey)
        apiClient?.sessionToken = ""
        authUser = nil
        isAuthenticated = (dataSource == .mock)
        if !token.isEmpty && dataSource == .remote {
            Task { try? await repositories.auth.logout() }
        }
        dataVersion += 1
    }

    /// 校验通过才切换，返回 false 表示地址无效（避免进入「云端已连接但无数据」的死状态）
    @discardableResult
    func connectCloud(baseURL: String, token: String) -> Bool {
        let config = APIConfiguration(
            baseURLString: baseURL.trimmingCharacters(in: .whitespacesAndNewlines),
            token: token.trimmingCharacters(in: .whitespacesAndNewlines),
            timeout: 20
        )
        guard config.isConfigured else { return false }
        apiConfiguration = config
        dataSource = .remote
        return true
    }

    func useLocalData() {
        dataSource = .mock
    }

    /// 提交写操作后调用，让各页面的 .task(id: dataVersion) 重新拉取
    func refresh() { dataVersion += 1 }

    func resetMockData() {
        mockProvider.db.reset()
        dataVersion += 1
    }

    private func rebuild() {
        let defaults = UserDefaults.standard
        let savedToken = defaults.string(forKey: Self.sessionKey) ?? ""
        if dataSource == .remote {
            let client = URLSessionAPIClient(configuration: apiConfiguration)
            client.sessionToken = savedToken
            apiClient = client
            repositories = RepositoryFactory.make(mode: .remote,
                                                  configuration: apiConfiguration,
                                                  mock: mockProvider, client: client)
            isAuthenticated = !savedToken.isEmpty
            if let data = defaults.data(forKey: Self.userKey),
               let user = try? JSONDecoder().decode(AuthUser.self, from: data) {
                authUser = user
            } else {
                authUser = nil
                // 有会话但缺账号缓存（如旧版本升级）：向服务端补齐真实角色
                if !savedToken.isEmpty {
                    Task { [weak self] in
                        guard let self,
                              let user = try? await self.repositories.auth.me() else { return }
                        if let data = try? JSONEncoder().encode(user) {
                            UserDefaults.standard.set(data, forKey: Self.userKey)
                        }
                        self.authUser = user
                    }
                }
            }
        } else {
            apiClient = nil
            repositories = mockProvider
            isAuthenticated = true
            authUser = .local
        }
        dataVersion += 1
    }

    private func persist() {
        let defaults = UserDefaults.standard
        defaults.set(dataSource.rawValue, forKey: Self.modeKey)
        defaults.set(appearance.rawValue, forKey: Self.appearanceKey)
        if let data = try? JSONEncoder().encode(apiConfiguration) {
            defaults.set(data, forKey: Self.configKey)
        }
    }
}
