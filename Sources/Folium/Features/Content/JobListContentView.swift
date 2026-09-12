import SwiftUI
import FoliumCore

/// Lista scrollable de tarjetas de documentos con selección.
public struct JobListContentView: View {
    let jobs: [DocumentJob]
    @Binding var selectedJobId: UUID?
    let model: AppModel

    public var body: some View {
        List(jobs, selection: $selectedJobId) { job in
            JobCardView(job: job, model: model)
                .tag(job.id)
                .listRowSeparator(.visible)
        }
        .listStyle(.inset(alternatesRowBackgrounds: true))
        .navigationTitle(model.selectedCategory.rawValue)
    }
}
