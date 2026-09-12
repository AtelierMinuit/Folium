import SwiftUI
import ScribeMacCore

/// Timeline visual del registro cronológico de transiciones de estado.
/// Muestra cada evento con hora, badge de estado coloreado y mensaje técnico.
public struct TransitionLogTimelineView: View {
    let events: [StateTransitionEvent]

    public var body: some View {
        if events.isEmpty {
            Text("Sin eventos registrados.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(events.enumerated()), id: \.element.id) { index, event in
                    HStack(alignment: .top, spacing: 8) {
                        // Línea temporal
                        VStack(spacing: 0) {
                            Circle()
                                .fill(colorForState(event.state))
                                .frame(width: 8, height: 8)

                            if index < events.count - 1 {
                                Rectangle()
                                    .fill(Color.secondary.opacity(0.3))
                                    .frame(width: 1)
                                    .frame(minHeight: 20)
                            }
                        }
                        .frame(width: 8)

                        // Contenido del evento
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(event.formattedTime)
                                    .font(.system(.caption2, design: .monospaced))
                                    .foregroundStyle(.tertiary)

                                Text(event.state.description)
                                    .font(.caption2.bold())
                                    .foregroundStyle(colorForState(event.state))
                            }

                            Text(event.message)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)

                            // Metadata adicional si existe
                            if let metadata = event.metadata, !metadata.isEmpty {
                                HStack(spacing: 4) {
                                    ForEach(Array(metadata.sorted(by: { $0.key < $1.key })), id: \.key) { key, value in
                                        Text("\(key): \(value)")
                                            .font(.system(.caption2, design: .monospaced))
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                            }
                        }
                        .padding(.bottom, index < events.count - 1 ? 8 : 0)
                    }
                }
            }
        }
    }

    private func colorForState(_ state: DocumentState) -> Color {
        switch state {
        case .received, .parsing, .resolvable, .queued: return .secondary
        case .inspecting: return .purple
        case .downloading: return .blue
        case .validating, .finalizing: return .orange
        case .completed: return .green
        case .restricted, .authenticationRequired: return .yellow
        case .unsupported, .cancelled: return .gray
        case .failed: return .red
        }
    }
}
