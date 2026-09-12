import SwiftUI
import FoliumCore

/// Vista principal de Folium: NavigationSplitView de 3 columnas con inspector nativo.
/// Sidebar (Bandeja con conteos) + Contenido (tarjetas o captura vacía) + Inspector técnico.
public struct MainSplitView: View {
    @Environment(AppEnvironment.self) private var env
    @Bindable var model: AppModel

    public init(model: AppModel) {
        self.model = model
    }

    public var body: some View {
        NavigationSplitView {
            sidebarContent
                .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 260)
        } content: {
            contentArea
                .navigationSplitViewColumnWidth(min: 400, ideal: 600)
        } detail: {
            if let job = model.selectedJob(from: env.queue) {
                InspectorTechnicalView(job: job)
            } else {
                Text("Selecciona un documento para ver sus detalles técnicos.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .inspector(isPresented: $model.isInspectorPresented) {
            if let job = model.selectedJob(from: env.queue) {
                InspectorTechnicalView(job: job)
                    .inspectorColumnWidth(min: 280, ideal: 320, max: 400)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 36))
                        .foregroundStyle(.secondary)
                    Text("Sin documento seleccionado")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text("Selecciona un documento de la lista para ver su diagnóstico técnico completo.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .inspectorColumnWidth(min: 280, ideal: 320, max: 400)
            }
        }
        .safeAreaInset(edge: .bottom) {
            BottomStatusBarView(model: model)
        }
        .searchable(text: $model.searchText, prompt: "Buscar por título, autor o URL...")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    model.inputURL = ""
                    model.errorMessage = nil
                    model.statusMessage = nil
                } label: {
                    Label("Nueva captura", systemImage: "plus")
                }
                .help("Nueva captura de enlace (⌘N)")

                Button {
                    model.isInspectorPresented.toggle()
                } label: {
                    Label("Inspector", systemImage: "sidebar.trailing")
                }
                .help("Alternar Inspector técnico (⌥⌘I)")
            }
        }
        .frame(
            minWidth: 1000, idealWidth: 1180,
            minHeight: 600, idealHeight: 760
        )
    }

    // MARK: - Sidebar

    @ViewBuilder
    private var sidebarContent: some View {
        List(selection: $model.selectedCategory) {
            Section("Bandeja") {
                ForEach([SidebarCategory.biblioteca, .descargas, .cola, .terminados, .errores]) { category in
                    NavigationLink(value: category) {
                        Label(category.rawValue, systemImage: category.icon)
                            .badge(category == .biblioteca ? 0 : model.badgeCount(for: category, queue: env.queue))
                    }
                }
            }

            Section("Colecciones") {
                NavigationLink(value: SidebarCategory.favoritos) {
                    Label(SidebarCategory.favoritos.rawValue, systemImage: SidebarCategory.favoritos.icon)
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Folium")
    }

    // MARK: - Content Area

    @ViewBuilder
    private var contentArea: some View {
        if model.selectedCategory == .biblioteca {
            LibraryView(onlyFavorites: false)
        } else if model.selectedCategory == .favoritos {
            LibraryView(onlyFavorites: true)
        } else {
            queueContentArea
        }
    }

    @ViewBuilder
    private var queueContentArea: some View {
        let _ = model.refreshTrigger
        let jobs = model.filteredJobs(from: env.queue)

        if jobs.isEmpty && env.queue.jobs.isEmpty {
            EmptyCaptureView(model: model)
        } else if jobs.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 36))
                    .foregroundStyle(.secondary)
                Text("Sin resultados")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Text("No hay documentos que coincidan con el filtro actual.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            JobListContentView(
                jobs: jobs,
                selectedJobId: $model.selectedJobId,
                model: model
            )
            .navigationTitle(model.selectedCategory.rawValue)
        }
    }
}
