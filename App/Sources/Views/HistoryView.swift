import SwiftUI
import OpalineKit

struct HistoryView: View {
    @Environment(AppModel.self) private var model
    let theme: Theme
    @State private var restoring: Snapshot?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                SectionTitle(title: "History", subtitle: "Every apply keeps the files it replaced. Restore one to go back to how things were before it.")
                if model.snapshots.isEmpty {
                    GlassCard {
                        HStack(spacing: 14) {
                            Image(systemName: "clock.arrow.circlepath").font(.system(size: 26)).foregroundStyle(theme.palette.accent.color)
                            Text("Nothing yet. Apply a theme and its snapshot shows up here.").foregroundStyle(Color.primary.opacity(0.7))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                ForEach(model.snapshots) { snapshot in
                    SnapshotRow(snapshot: snapshot, theme: theme) { restoring = snapshot }
                }
            }
            .padding(44)
        }
        .confirmationDialog("Restore the state before \(restoring?.themeName ?? "")?", isPresented: Binding(get: { restoring != nil }, set: { if !$0 { restoring = nil } })) {
            Button("Restore") {
                if let restoring { model.restore(restoring) }
            }
        } message: {
            Text("The files this apply changed go back to their previous content. Apps that need it restart.")
        }
    }
}

private struct SnapshotRow: View {
    @Environment(AppModel.self) private var model
    let snapshot: Snapshot
    let theme: Theme
    let onRestore: () -> Void

    var body: some View {
        let applied = model.theme(id: snapshot.themeID)
        GlassCard(padding: 16) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(applied.map { LinearGradient(colors: [$0.palette.base.color, $0.palette.accent.color], startPoint: .topLeading, endPoint: .bottomTrailing) }
                              ?? LinearGradient(colors: [.gray, .black], startPoint: .top, endPoint: .bottom))
                    Image(systemName: "paintpalette.fill").foregroundStyle(.white.opacity(0.85))
                }
                .frame(width: 44, height: 44)
                VStack(alignment: .leading, spacing: 4) {
                    Text(snapshot.themeName).font(.system(size: 15, weight: .semibold))
                    Text("\(snapshot.date.formatted(date: .abbreviated, time: .shortened)) · \(snapshot.targetIDs.count) apps · \(snapshot.entries.count) files")
                        .font(.system(size: 12)).foregroundStyle(Color.primary.opacity(0.55))
                }
                Spacer()
                HStack(spacing: -6) {
                    ForEach(model.targets.filter { snapshot.targetIDs.contains($0.info.id) }.prefix(7), id: \.info.id) { target in
                        TargetIcon(info: target.info, size: 26, tint: theme.palette.accent.color)
                    }
                }
                Button("Restore", action: onRestore).buttonStyle(PillButtonStyle())
                Button { model.deleteSnapshot(snapshot) } label: { Image(systemName: "trash") }
                    .buttonStyle(PillButtonStyle())
            }
        }
    }
}
