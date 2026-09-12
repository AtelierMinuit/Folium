import SwiftUI
import SwiftData
import FoliumCore

@main
struct FoliumApp: App {
    @State private var environment = AppEnvironment()
    @State private var appModel = AppModel()

    var body: some Scene {
        // Ventana principal: NavigationSplitView de 3 columnas con inspector nativo
        WindowGroup {
            MainSplitView(model: appModel)
                .environment(environment)
                .modelContainer(environment.store.container)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            FoliumCommands(
                isInspectorPresented: $appModel.isInspectorPresented,
                onNewDownload: {
                    // Enfocar la ventana principal y limpiar el campo para nueva captura
                    appModel.inputURL = ""
                    appModel.errorMessage = nil
                    appModel.statusMessage = nil
                },
                onPasteAndAnalyze: {
                    Task { @MainActor in
                        await appModel.pasteAndAnalyze(environment: environment)
                    }
                }
            )
        }

        // MenuBarExtra: popover rápido para añadir enlaces desde cualquier app
        MenuBarExtra("Folium", systemImage: "arrow.down.circle.fill") {
            MenuBarCompanionView()
                .environment(environment)
        }
        .menuBarExtraStyle(.window)

        // Ventana de ajustes (⌘,)
        Settings {
            SettingsWindowView()
                .environment(environment)
        }
    }
}
