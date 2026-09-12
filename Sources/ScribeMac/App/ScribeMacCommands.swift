import SwiftUI

/// Atajos de teclado nativos de macOS para ScribeMac.
/// ⌘N: Nueva descarga, ⇧⌘V: Pegar y analizar, ⌥⌘I: Alternar inspector.
struct ScribeMacCommands: Commands {
    @Binding var isInspectorPresented: Bool
    let onNewDownload: () -> Void
    let onPasteAndAnalyze: () -> Void

    var body: some Commands {
        // Grupo Archivo: Nueva descarga y pegar
        CommandGroup(after: .newItem) {
            Button("Nueva Descarga") {
                onNewDownload()
            }
            .keyboardShortcut("n", modifiers: .command)

            Button("Pegar y Analizar") {
                onPasteAndAnalyze()
            }
            .keyboardShortcut("v", modifiers: [.command, .shift])
        }

        // Grupo Vista: Alternar inspector
        CommandGroup(after: .sidebar) {
            Button(isInspectorPresented ? "Ocultar Inspector" : "Mostrar Inspector") {
                isInspectorPresented.toggle()
            }
            .keyboardShortcut("i", modifiers: [.command, .option])
        }
    }
}
