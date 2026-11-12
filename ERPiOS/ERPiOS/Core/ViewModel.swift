import SwiftUI

enum LoadPhase: Equatable {
    case idle
    case loading
    case loaded
    case failed(String)
}

/// 通用列表加载状态机：所有业务列表页复用，联云后无需改动
@MainActor
final class LoadListViewModel<T>: ObservableObject {
    @Published private(set) var items: [T] = []
    @Published private(set) var phase: LoadPhase = .idle

    func load(_ fetch: @escaping () async throws -> [T]) async {
        phase = .loading
        do {
            let result = try await fetch()
            items = result
            phase = .loaded
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }
}

/// 通用详情加载状态机
@MainActor
final class LoadItemViewModel<T>: ObservableObject {
    @Published private(set) var item: T?
    @Published private(set) var phase: LoadPhase = .idle

    func load(_ fetch: @escaping () async throws -> T?) async {
        phase = .loading
        do {
            item = try await fetch()
            phase = .loaded
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }
}
