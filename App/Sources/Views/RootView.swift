import SwiftUI
import OpalineKit

enum AppSection: String, CaseIterable, Identifiable {
    case themes, apps, history

    var id: String { rawValue }

    var title: String {
        switch self {
        case .themes: "Themes"
        case .apps: "Apps"
        case .history: "History"
        }
    }

    var symbol: String {
        switch self {
        case .themes: "paintpalette.fill"
        case .apps: "square.grid.2x2.fill"
        case .history: "clock.arrow.circlepath"
        }
    }
}

struct RootView: View {
    @Environment(AppModel.self) private var model
    @State private var section: AppSection = .themes

    var body: some View {
        @Bindable var model = model
        if let theme = model.selectedTheme, let shown = model.shownTheme {
            HStack(spacing: 0) {
                Sidebar(section: $section, theme: shown)
                    .frame(width: 228)
                Group {
                    switch section {
                    case .themes: ThemesView(theme: theme)
                    case .apps: AppsView(theme: shown)
                    case .history: HistoryView(theme: shown)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.opacity)
            }
            .background(ThemeBackdrop(theme: shown))
            .foregroundStyle(.primary)
            .tint(shown.palette.accent.color)
            .preferredColorScheme(shown.colorScheme)
            .animation(.easeInOut(duration: 0.25), value: section)
            .sheet(item: Binding(get: { model.run }, set: { model.run = $0 })) { _ in
                ApplySheet(theme: shown).environment(model)
            }
            .alert("Something went wrong", isPresented: Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(model.errorMessage ?? "")
            }
            .fileImporter(isPresented: $model.isImporting, allowedContentTypes: [.json], allowsMultipleSelection: true) { result in
                if case .success(let urls) = result { model.importThemes(from: urls) }
            }
            .fileExporter(
                isPresented: Binding(get: { model.exporting != nil }, set: { if !$0 { model.exporting = nil } }),
                document: model.exporting.flatMap(model.exportFile(for:)),
                contentType: .json,
                defaultFilename: model.exporting.map { "\($0.id).json" }
            ) { result in
                if case .success(let url) = result { model.show("Saved \(url.lastPathComponent)") }
            }
            .dropDestination(for: URL.self) { urls, _ in
                let files = urls.filter { $0.pathExtension.lowercased() == "json" }
                model.importThemes(from: files)
                return !files.isEmpty
            }
            .overlay(alignment: .bottom) {
                if let toast = model.toast {
                    Label(toast, systemImage: "checkmark.circle.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 11)
                        .background(.ultraThinMaterial, in: Capsule())
                        .overlay(Capsule().strokeBorder(theme.holoGradient, lineWidth: 1.2))
                        .padding(.bottom, 26)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: model.toast)
        } else {
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private struct Sidebar: View {
    @Environment(AppModel.self) private var model
    @Binding var section: AppSection
    let theme: Theme

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 34, height: 34)
                Text("Opaline").font(.system(size: 17, weight: .bold, design: .rounded))
            }
            .padding(.horizontal, 10)
            .padding(.top, 44)
            .padding(.bottom, 22)

            ForEach(AppSection.allCases) { item in
                SidebarItem(section: item, selected: section == item, theme: theme) { section = item }
            }

            Spacer()

            if let applied = model.appliedThemeID.flatMap(model.theme(id:)) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("ON YOUR MAC").font(.system(size: 10, weight: .semibold)).foregroundStyle(Color.primary.opacity(0.45)).kerning(1.2)
                    HStack(spacing: 10) {
                        Circle().fill(applied.palette.accent.color).frame(width: 10, height: 10)
                            .shadow(color: applied.palette.accent.color, radius: 6)
                        Text(applied.name).font(.system(size: 13, weight: .semibold))
                        Spacer()
                        Text("\(model.applied.themeByTarget.values.filter { $0 == applied.id }.count) apps")
                            .font(.system(size: 11)).foregroundStyle(Color.primary.opacity(0.5))
                    }
                }
                .padding(14)
                .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
        .padding(14)
        .frame(maxHeight: .infinity)
        .background(.ultraThinMaterial)
        .overlay(alignment: .trailing) { Rectangle().fill(Color.primary.opacity(0.08)).frame(width: 1) }
    }
}

private struct SidebarItem: View {
    let section: AppSection
    let selected: Bool
    let theme: Theme
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: section.symbol)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(selected ? theme.palette.deep.color : Color.primary.opacity(0.85))
                    .frame(width: 28, height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(selected ? AnyShapeStyle(theme.palette.accent.color) : AnyShapeStyle(Color.primary.opacity(0.08)))
                    )
                Text(section.title)
                    .font(.system(size: 14, weight: selected ? .semibold : .medium))
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(Color.primary.opacity(selected ? 0.12 : (hovering ? 0.06 : 0)))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}
