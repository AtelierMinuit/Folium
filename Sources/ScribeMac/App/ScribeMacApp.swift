import SwiftUI
import SwiftData
import ScribeMacCore

enum AppTab: String, CaseIterable, Identifiable {
    case home = "Inicio"
    case downloads = "Descargas"
    case library = "Biblioteca"
    case settings = "Ajustes"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .home: return "doc.text.magnifyingglass"
        case .downloads: return "arrow.down.circle"
        case .library: return "books.vertical"
        case .settings: return "gearshape"
        }
    }
}

@main
struct ScribeMacApp: App {
    @State private var environment = AppEnvironment()
    @State private var selectedTab: AppTab = .home

    var body: some Scene {
        WindowGroup {
            NavigationSplitView {
                List(AppTab.allCases, selection: $selectedTab) { tab in
                    NavigationLink(value: tab) {
                        Label(tab.rawValue, systemImage: tab.icon)
                    }
                }
                .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 240)
                .listStyle(.sidebar)
            } detail: {
                switch selectedTab {
                case .home:
                    HomeView()
                case .downloads:
                    DownloadsView()
                case .library:
                    LibraryView()
                case .settings:
                    SettingsView()
                }
            }
            .frame(minWidth: 920, minHeight: 620)
            .environment(environment)
            .modelContainer(environment.store.container)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
    }
}
