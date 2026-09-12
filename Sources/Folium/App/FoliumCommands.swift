import SwiftUI

/// Atajos de teclado nativos de macOS para Folium.
/// ⌘N: Nueva descarga, ⇧⌘V: Pegar y analizar, ⌥⌘I: Alternar inspector.
struct FoliumCommands: Commands {
    @Binding var isInspectorPresented: Bool
    let onNewDownload: () -> Void
    let onPasteAndAnalyze: () -> Void
    let onOpenSelected: () -> Void
    let onQuickLook: () -> Void
    let onFind: () -> Void

    var body: some Commands {
        // Grupo Archivo: Nueva descarga, pegar, abrir
        CommandGroup(after: .newItem) {
            Button("Nueva Descarga") {
                onNewDownload()
            }
            .keyboardShortcut("n", modifiers: .command)

            Button("Pegar y Analizar") {
                onPasteAndAnalyze()
            }
            .keyboardShortcut("v", modifiers: [.command, .shift])

            Divider()

            Button("Abrir Documento") {
                onOpenSelected()
            }
            .keyboardShortcut("o", modifiers: .command)
        }

        // Grupo Edición: Buscar
        CommandGroup(after: .pasteboard) {
            Button("Buscar en Folium") {
                onFind()
            }
            .keyboardShortcut("f", modifiers: .command)
        }

        // Grupo Vista: Alternar inspector y vista rápida
        CommandGroup(after: .sidebar) {
            Button(isInspectorPresented ? "Ocultar Inspector" : "Mostrar Inspector") {
                isInspectorPresented.toggle()
            }
            .keyboardShortcut("i", modifiers: [.command, .option])

            Button("Vista Rápida") {
                onQuickLook()
            }
            .keyboardShortcut(.space, modifiers: [])
        }
    }
}
