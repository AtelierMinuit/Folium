import SwiftUI
import ScribeMacCore

/// Vista principal de ScribeMac: NavigationSplitView de 3 columnas con inspector nativo.
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
                ForEach(SidebarCategory.allCases) { category in
                    NavigationLink(value: category) {
                        Label(category.rawValue, systemImage: category.icon)
                            .badge(model.badgeCount(for: category, queue: env.queue))
                    }
                }
            }

            Section("Biblioteca") {
                NavigationLink {
                    LibraryView()
                } label: {
                    Label("Documentos", systemImage: "books.vertical")
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("ScribeMac")
    }

    // MARK: - Content Area

    @ViewBuilder
    private var contentArea: some View {
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
                Text("No hay documentos que coincidan con tu búsqueda o filtro.")
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
        }
    }
}
