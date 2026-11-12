import SwiftUI

@main
struct ERPiOSApp: App {
    @StateObject private var environment = AppEnvironment()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(environment)
                .preferredColorScheme(environment.colorScheme)
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var env: AppEnvironment

    var body: some View {
        Group {
            if env.isAuthenticated { mainTabs } else { LoginView() }
        }
    }

    private var mainTabs: some View {
        TabView(selection: Binding(get: { env.router.selectedTab },
                                   set: { env.router.selectedTab = $0 })) {
            ForEach(AppTab.allCases) { tab in
                tabContainer(for: tab)
                    .tabItem {
                        Label(tab.rawValue,
                              systemImage: env.router.selectedTab == tab ? tab.selectedSymbol : tab.symbol)
                    }
                    .tag(tab)
            }
        }
        .tint(ERPTheme.brand)
    }

    @ViewBuilder
    private func tabContainer(for tab: AppTab) -> some View {
        NavigationStack(path: env.router.binding(for: tab)) {
            rootContent(for: tab)
                .navigationDestination(for: AppRoute.self) { route in
                    RouteDestination(route: route)
                }
        }
    }

    @ViewBuilder
    private func rootContent(for tab: AppTab) -> some View {
        switch tab {
        case .dashboard: DashboardView()
        case .business: BusinessHubView()
        case .reports: ReportsView()
        case .settings: SettingsView()
        }
    }
}
