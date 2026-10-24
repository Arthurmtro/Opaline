import SwiftUI
import UniformTypeIdentifiers
import OpalineKit

struct AppsView: View {
    @Environment(AppModel.self) private var model
    let theme: Theme
    @State private var editing: CustomTargetDefinition?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(alignment: .bottom) {
                    SectionTitle(title: "Apps", subtitle: "Choose which apps wear the theme. Add any app with a config file and a template.")
                    Spacer()
                    Button {
                        editing = CustomTargetDefinition(name: "", outputPath: "~/.config/", template: Self.starterTemplate)
                    } label: {
                        Label("Add App", systemImage: "plus")
                    }
                    .buttonStyle(PillButtonStyle(prominent: true, tint: theme.palette.accent.color))
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 16)], spacing: 16) {
                    ForEach(model.targets, id: \.info.id) { target in
                        AppCard(target: target, theme: theme) {
                            editing = model.customTargets.first { "custom.\($0.id)" == target.info.id }
                        }
                    }
                }
            }
            .padding(44)
        }
        .sheet(item: $editing) { definition in
            CustomAppEditor(definition: definition, theme: theme) { saved in
                model.save(saved)
                editing = nil
            } onDelete: {
                model.delete(definition)
                editing = nil
            } onCancel: {
                editing = nil
            }
        }
    }

    static let starterTemplate = """
    # Colors from the active Opaline theme.
    background = {{palette.base}}
    foreground = {{palette.text}}
    accent = {{palette.accent}}
    selection = {{palette.selection}}
    """
}

private struct AppCard: View {
    @Environment(AppModel.self) private var model
    let target: any ThemeTarget
    let theme: Theme
    let onEdit: () -> Void
    @State private var hovering = false

    var body: some View {
        let installed = model.isInstalled(target)
        let enabled = model.isEnabled(target)
        GlassCard(padding: 18) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 14) {
                    TargetIcon(info: target.info, size: 46, tint: theme.palette.accent.color)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(target.info.name).font(.system(size: 15, weight: .semibold))
                        status(installed: installed)
                    }
                    Spacer()
                    Toggle("", isOn: Binding(get: { enabled }, set: { model.setEnabled($0, for: target) }))
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .disabled(!installed)
                }
                Text(target.info.summary)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.primary.opacity(0.65))
                    .fixedSize(horizontal: false, vertical: true)
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(model.files(of: target), id: \.self) { path in
                        Text(path)
                            .font(.system(size: 10.5, design: .monospaced))
                            .foregroundStyle(Color.primary.opacity(0.42))
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                if target.info.isCustom {
                    Button("Edit", action: onEdit).buttonStyle(PillButtonStyle())
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .opacity(installed ? 1 : 0.55)
        .scaleEffect(hovering ? 1.01 : 1)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: hovering)
        .onHover { hovering = $0 }
    }

    @ViewBuilder
    private func status(installed: Bool) -> some View {
        if !installed {
            StatusPill(text: "Not installed", tone: .neutral)
        } else if let themeID = model.applied.themeByTarget[target.info.id], let applied = model.theme(id: themeID) {
            StatusPill(text: applied.name, tone: applied.id == theme.id ? .positive : .neutral)
        } else if target.info.quitsApp {
            StatusPill(text: "Restarts to apply", tone: .warning)
        } else {
            StatusPill(text: "Ready", tone: .neutral)
        }
    }
}

/// Add or edit a user-defined app: where to write, what to write, how to reload.
private struct CustomAppEditor: View {
    @State private var draft: CustomTargetDefinition
    let theme: Theme
    let onSave: (CustomTargetDefinition) -> Void
    let onDelete: () -> Void
    let onCancel: () -> Void
    @State private var choosingApp = false
    private let isNew: Bool

    init(definition: CustomTargetDefinition, theme: Theme, onSave: @escaping (CustomTargetDefinition) -> Void,
         onDelete: @escaping () -> Void, onCancel: @escaping () -> Void) {
        _draft = State(initialValue: definition)
        isNew = definition.name.isEmpty
        self.theme = theme
        self.onSave = onSave
        self.onDelete = onDelete
        self.onCancel = onCancel
    }

    private let tokens = ["palette.base", "palette.deep", "palette.surface", "palette.elevated", "palette.accent", "palette.accentSoft",
                          "palette.text", "palette.textMuted", "palette.selection", "palette.border", "syntax.keyword", "syntax.string",
                          "terminal.ansi.0", "terminal.ansi.1", "terminal.ansi.2", "terminal.ansi.4", "name", "appearance"]

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 16) {
                Text(isNew ? "Add an App" : "Edit \(draft.name)").font(.system(size: 22, weight: .bold, design: .rounded))
                HStack(spacing: 12) {
                    TargetIcon(info: CustomTarget(definition: draft).info, size: 40, tint: theme.palette.accent.color)
                    Button(draft.appPath == nil ? "Choose App…" : "Change App…") { choosingApp = true }
                        .buttonStyle(PillButtonStyle())
                    Toggle("Close the app while writing", isOn: $draft.quitsApp)
                        .disabled(draft.appPath == nil)
                }
                field("Name") { TextField("Kitty", text: $draft.name) }
                field("File to write") { TextField("~/.config/kitty/theme.conf", text: $draft.outputPath).font(.system(.body, design: .monospaced)) }
                field("Reload command (optional)") {
                    TextField("kill -SIGUSR1 $(pgrep kitty)", text: Binding(get: { draft.reloadCommand ?? "" }, set: { draft.reloadCommand = $0.isEmpty ? nil : $0 }))
                        .font(.system(.body, design: .monospaced))
                }
                field("Template") {
                    TextEditor(text: $draft.template)
                        .font(.system(size: 12, design: .monospaced))
                        .scrollContentBackground(.hidden)
                        .padding(8)
                        .background(.black.opacity(0.3), in: RoundedRectangle(cornerRadius: 10))
                        .frame(minHeight: 180)
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(tokens, id: \.self) { token in
                            Button("{{\(token)}}") { draft.template += "{{\(token)}}" }
                                .font(.system(size: 10.5, design: .monospaced))
                                .buttonStyle(PillButtonStyle())
                        }
                    }
                }
                Text("Filters: {{palette.accent | rgb}}, | nohash, | opaque, | upper, | lower.")
                    .font(.system(size: 11)).foregroundStyle(Color.primary.opacity(0.5))
            }
            .padding(28)
            .frame(width: 520)

            VStack(alignment: .leading, spacing: 12) {
                Text("PREVIEW WITH \(theme.name.uppercased())").font(.system(size: 11, weight: .bold)).kerning(1.4).foregroundStyle(theme.palette.accent.color)
                ScrollView {
                    Text(ThemeTokens.render(draft.template, theme: theme))
                        .font(.system(size: 12, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(14)
                .background(theme.palette.base.color, in: RoundedRectangle(cornerRadius: 12))
                Spacer()
                HStack {
                    if !isNew { Button("Delete", role: .destructive, action: onDelete).buttonStyle(PillButtonStyle()) }
                    Spacer()
                    Button("Cancel", action: onCancel).buttonStyle(PillButtonStyle()).keyboardShortcut(.cancelAction)
                    Button("Save") { onSave(draft) }
                        .buttonStyle(PillButtonStyle(prominent: true, tint: theme.palette.accent.color))
                        .keyboardShortcut(.defaultAction)
                        .disabled(draft.name.isEmpty || draft.outputPath.count < 3)
                }
            }
            .padding(28)
            .background(.black.opacity(0.2))
        }
        .frame(width: 960, height: 640)
        .background(ThemeBackdrop(theme: theme))
        .preferredColorScheme(theme.colorScheme)
        .fileImporter(isPresented: $choosingApp, allowedContentTypes: [.application]) { result in
            guard let url = try? result.get() else { return }
            draft.appPath = url.path(percentEncoded: false)
            if draft.name.isEmpty { draft.name = url.deletingPathExtension().lastPathComponent }
        }
    }

    private func field<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.primary.opacity(0.7))
            content().textFieldStyle(.roundedBorder)
        }
    }
}
