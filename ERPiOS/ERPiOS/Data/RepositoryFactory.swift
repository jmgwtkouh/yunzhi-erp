import Foundation

/// 数据源装配厂：整个 App 只有这一处决定「读本地」还是「读云端」。
enum RepositoryFactory {
    static func make(mode: DataSourceMode,
                     configuration: APIConfiguration,
                     mock: MockRepositoryProvider,
                     client: URLSessionAPIClient? = nil) -> RepositoryProvider {
        switch mode {
        case .mock:
            return mock
        case .remote:
            let c = client ?? URLSessionAPIClient(configuration: configuration)
            return RemoteRepositoryProvider(client: c)
        }
    }
}
