import SwiftUI
import OpalineKit

struct ThemeEditorView: View {
    @State private var draft: Theme
    /// Which appearance the color rows edit.
    @State private var editing: Appearance
    let onSave: (Theme) -> Void
    let onCancel: () -> Void

    init(theme: Theme, onSave: @escaping (Theme) -> Void, onCancel: @escaping () -> Void) {
        _draft = State(initialValue: theme)
        _editing = State(initialValue: theme.appearance)
        self.onSave = onSave
        self.onCancel = onCancel
    }

    /// The colors of the edited appearance; writes go to the primary or the alternate variant.
    private var variant: Binding<Theme> {
        Binding(get: { draft.variant(editing) }, set: { draft.update($0) })
    }

    var body: some View {
        HStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    general
                    group("Backgrounds", [
                        ("Chrome", \.palette.deep), ("Panels", \.palette.surface), ("Content", \.palette.base),
                        ("Raised", \.palette.elevated), ("Hover", \.palette.hover), ("Highlight", \.palette.highlight),
                        ("Selection", \.palette.selection), ("Border", \.palette.border), ("Subtle border", \.palette.borderSubtle),
                    ])
                    group("Accent", [
                        ("Accent", \.palette.accent), ("Soft", \.palette.accentSoft), ("Deep", \.palette.accentDeep), ("Dim", \.palette.accentDim),
                    ])
                    group("Text", [
                        ("Text", \.palette.text), ("Muted", \.palette.textMuted), ("Subtle", \.palette.textSubtle), ("Faint", \.palette.textFaint),
                    ])
                    group("Status", [
                        ("Success", \.palette.success), ("Warning", \.palette.warning), ("Error", \.palette.error), ("Info", \.palette.info),
                    ])
                    terminal
                    group("Syntax", [
                        ("Keyword", \.syntax.keyword), ("Function", \.syntax.function), ("Type", \.syntax.type), ("String", \.syntax.string),
                        ("Number", \.syntax.number), ("Comment", \.syntax.comment), ("Property", \.syntax.property), ("Variable", \.syntax.variable),
                        ("Special", \.syntax.special), ("Operator", \.syntax.operator), ("Punctuation", \.syntax.punctuation),
                    ])
                    backdrop
                    browser
                    wallpaper
                }
                .padding(28)
            }
            .frame(width: 470)
            .background(.black.opacity(0.25))

            VStack(spacing: 20) {
                ThemePreview(theme: draft.variant(editing), debounce: true, showsAppearanceToggle: false)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                HStack {
                    Spacer()
                    Button("Cancel", action: onCancel)
                        .buttonStyle(PillButtonStyle())
                        .keyboardShortcut(.cancelAction)
                    Button("Save Theme") { onSave(draft) }
                        .buttonStyle(PillButtonStyle(prominent: true, tint: draft.palette.accent.color))
                        .keyboardShortcut(.defaultAction)
                }
            }
            .padding(28)
        }
        .frame(width: 1180, height: 780)
        .background(ThemeBackdrop(theme: draft.variant(editing)))
        .preferredColorScheme(draft.variant(editing).colorScheme)
    }

    private var general: some View {
        VStack(alignment: .leading, spacing: 12) {
            heading("Theme")
            TextField("Name", text: $draft.name).textFieldStyle(.roundedBorder)
            TextField("Author", text: $draft.author).textFieldStyle(.roundedBorder)
            variants
        }
    }

    /// Single themes choose their appearance and can add the other one; dual themes switch the edited variant.
    private var variants: some View {
        VStack(alignment: .leading, spacing: 8) {
            if draft.alternate == nil {
                HStack {
                    Picker("Appearance", selection: $draft.appearance) {
                        ForEach(Appearance.allCases, id: \.self) { Text($0.rawValue.capitalized) }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .onChange(of: draft.appearance) { editing = draft.appearance }
                    Button("Add \(draft.appearance.opposite.rawValue.capitalized) Version") {
                        draft.alternate = ThemeVariant.opposite(of: draft)
                        editing = draft.appearance.opposite
                    }
                    .buttonStyle(PillButtonStyle())
                }
                Text("Add the other version and apps that support it follow the Mac's light and dark switch.")
                    .font(.system(size: 11)).foregroundStyle(Color.primary.opacity(0.5))
            } else {
                HStack {
                    Picker("Editing", selection: $editing) {
                        ForEach(draft.appearances, id: \.self) { appearance in
                            Label(appearance.rawValue.capitalized, systemImage: appearance == .dark ? "moon.fill" : "sun.max.fill").tag(appearance)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    Button("Remove \(draft.appearance.opposite.rawValue.capitalized)") {
                        draft.alternate = nil
                        editing = draft.appearance
                    }
                    .buttonStyle(PillButtonStyle())
                }
                Text("Editing the \(editing.rawValue) colors. Zed, the terminal, cmux, Zen and the wallpaper switch with the Mac.")
                    .font(.system(size: 11)).foregroundStyle(Color.primary.opacity(0.5))
            }
        }
    }

    private var terminal: some View {
        VStack(alignment: .leading, spacing: 12) {
            heading("Terminal")
            ForEach([0, 8], id: \.self) { offset in
                HStack(spacing: 8) {
                    ForEach(0..<8, id: \.self) { index in
                        ColorSwatchPicker(color: variant.terminal.ansi[offset + index])
                            .help("\(offset == 0 ? "" : "Bright ")\(TerminalPalette.names[index])")
                    }
                }
            }
        }
    }

    private var backdrop: some View {
        VStack(alignment: .leading, spacing: 12) {
            heading("Glow")
            ColorRow(title: "Glow", color: variant.backdrop.glow)
            SliderRow(title: "Strength", value: variant.backdrop.glowStrength, range: 0...0.6)
            SliderRow(title: "Grain", value: variant.backdrop.grain, range: 0...8)
            SliderRow(title: "Web hue", value: variant.backdrop.webHue, range: 0...359, format: "%.0f°")
        }
    }

    private var browser: some View {
        VStack(alignment: .leading, spacing: 12) {
            heading("Browser")
            ForEach(draft.variant(editing).browser.colors.indices, id: \.self) { index in
                ColorRow(title: index == 0 ? "Primary" : "Secondary", color: variant.browser.colors[index])
            }
            SliderRow(title: "Opacity", value: variant.browser.opacity, range: 0.3...0.8)
            SliderRow(title: "Grain", value: variant.browser.texture, range: 0...1)
        }
    }

    private var wallpaper: some View {
        VStack(alignment: .leading, spacing: 12) {
            heading("Wallpaper")
            HStack(spacing: 8) {
                ForEach(draft.wallpaper.holo.indices, id: \.self) { index in
                    ColorSwatchPicker(color: $draft.wallpaper.holo[index])
                }
            }
            TextField("Ring text", text: $draft.wallpaper.ringText).textFieldStyle(.roundedBorder)
            TextField("Tagline, comma separated", text: Binding(
                get: { draft.wallpaper.tagline.joined(separator: ", ") },
                set: { draft.wallpaper.tagline = $0.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) } }
            )).textFieldStyle(.roundedBorder)
            HStack {
                TextField("Top left", text: $draft.wallpaper.cornerTopLeft)
                TextField("Bottom left", text: $draft.wallpaper.cornerBottomLeft)
                TextField("Bottom right", text: $draft.wallpaper.cornerBottomRight)
            }
            .textFieldStyle(.roundedBorder)
        }
    }

    private func group(_ title: String, _ rows: [(String, WritableKeyPath<Theme, HexColor>)]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            heading(title)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 18), GridItem(.flexible())], spacing: 10) {
                ForEach(rows, id: \.0) { row in
                    ColorRow(title: row.0, color: variant[dynamicMember: row.1])
                }
            }
        }
    }

    private func heading(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 11, weight: .bold)).kerning(1.4)
            .foregroundStyle(draft.palette.accent.color)
    }
}

struct ColorRow: View {
    let title: String
    @Binding var color: HexColor
    @State private var text = ""

    var body: some View {
        HStack(spacing: 10) {
            ColorSwatchPicker(color: $color)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 12, weight: .medium))
                TextField("#000000", text: $text)
                    .font(.system(size: 11, design: .monospaced))
                    .textFieldStyle(.plain)
                    .foregroundStyle(Color.primary.opacity(0.6))
                    .onSubmit { if let parsed = HexColor(text) { color = parsed } else { text = color.hex } }
            }
            Spacer(minLength: 0)
        }
        .onAppear { text = color.hex }
        .onChange(of: color) { text = color.hex }
    }
}

struct ColorSwatchPicker: View {
    @Binding var color: HexColor

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(color.color)
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Color.primary.opacity(0.18), lineWidth: 1))
            ColorPicker("", selection: Binding(get: { color.color }, set: { color = HexColor($0) }), supportsOpacity: false)
                .labelsHidden()
                .opacity(0.02)
        }
        .frame(width: 30, height: 30)
    }
}

private struct SliderRow: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    var format = "%.2f"

    var body: some View {
        HStack {
            Text(title).font(.system(size: 12, weight: .medium)).frame(width: 80, alignment: .leading)
            Slider(value: $value, in: range)
            Text(String(format: format, value)).font(.system(size: 11, design: .monospaced)).foregroundStyle(Color.primary.opacity(0.6)).frame(width: 46, alignment: .trailing)
        }
    }
}
