import SwiftUI
import OpalineKit

/// Live progress of an apply or restore, one row per app around a progress ring.
struct ApplySheet: View {
    @Environment(AppModel.self) private var model
    let theme: Theme

    var body: some View {
        if let run = model.run {
            VStack(spacing: 24) {
                ZStack {
                    Circle().stroke(Color.primary.opacity(0.1), lineWidth: 10)
                    Circle()
                        .trim(from: 0, to: run.fraction)
                        .stroke(theme.holoGradient, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: run.fraction)
                    VStack(spacing: 4) {
                        if run.finished {
                            Image(systemName: run.error == nil ? "checkmark" : "exclamationmark.triangle.fill")
                                .font(.system(size: 34, weight: .bold))
                                .foregroundStyle(theme.palette.accent.color)
                                .transition(.scale.combined(with: .opacity))
                        } else {
                            Text("\(Int(run.fraction * 100))%").font(.system(size: 30, weight: .bold, design: .rounded))
                        }
                    }
                }
                .frame(width: 130, height: 130)

                VStack(spacing: 6) {
                    Text(run.finished ? (run.kind == .apply ? "\(theme.name) is on" : "Restored") : run.title)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                    Text(run.error ?? (run.finished ? "Every app below is up to date." : "Writing each app's config, with a snapshot to undo it."))
                        .font(.system(size: 13))
                        .foregroundStyle(Color.primary.opacity(0.6))
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: 2) {
                    ForEach(run.targets) { info in
                        row(info, phase: run.phases[info.id] ?? .waiting)
                    }
                }
                .padding(8)
                .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                Button(run.finished ? "Done" : "Working…") { model.run = nil }
                    .buttonStyle(PillButtonStyle(prominent: true, tint: theme.palette.accent.color))
                    .disabled(!run.finished)
                    .keyboardShortcut(.defaultAction)
            }
            .padding(36)
            .frame(width: 520)
            .background(ThemeBackdrop(theme: theme))
            .preferredColorScheme(theme.colorScheme)
            .animation(.easeInOut, value: run.finished)
        }
    }

    private func row(_ info: TargetInfo, phase: ApplyEvent.Phase) -> some View {
        HStack(spacing: 12) {
            TargetIcon(info: info, size: 28, tint: theme.palette.accent.color)
            VStack(alignment: .leading, spacing: 2) {
                Text(info.name).font(.system(size: 13, weight: .semibold))
                Text(detail(phase)).font(.system(size: 11)).foregroundStyle(Color.primary.opacity(0.55)).lineLimit(2)
            }
            Spacer()
            indicator(phase)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func detail(_ phase: ApplyEvent.Phase) -> String {
        switch phase {
        case .waiting: "Waiting"
        case .closingApp: "Closing the app"
        case .writing: "Writing"
        case .reloading: "Reloading"
        case .done: "Done"
        case .skipped(let reason): reason
        case .failed(let reason): reason
        }
    }

    @ViewBuilder
    private func indicator(_ phase: ApplyEvent.Phase) -> some View {
        switch phase {
        case .waiting:
            Circle().strokeBorder(Color.primary.opacity(0.25), lineWidth: 1.5).frame(width: 18, height: 18)
        case .closingApp, .writing, .reloading:
            ProgressView().controlSize(.small)
        case .done:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(theme.palette.accent.color).font(.system(size: 18))
        case .skipped:
            Image(systemName: "minus.circle.fill").foregroundStyle(Color.primary.opacity(0.45)).font(.system(size: 18))
        case .failed:
            Image(systemName: "xmark.circle.fill").foregroundStyle(theme.palette.error.color).font(.system(size: 18))
        }
    }
}
