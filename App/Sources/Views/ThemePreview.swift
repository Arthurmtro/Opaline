import SwiftUI
import OpalineKit

/// A miniature desktop drawn with the theme: its wallpaper, an editor, a terminal and a browser sidebar.
struct ThemePreview: View {
    @Environment(AppModel.self) private var model
    let theme: Theme
    /// Waits for edits to settle before rendering the wallpaper, for live editing.
    var debounce = false
    /// Offers a light/dark switch for themes that have both.
    var showsAppearanceToggle = true
    @State private var showsApps = true

    private var shown: Theme { showsAppearanceToggle ? theme.variant(model.appearance) : theme }
    private let designSize = CGSize(width: 680, height: 440)

    var body: some View {
        VStack(spacing: 14) {
            GeometryReader { proxy in
                scene
                    .frame(width: designSize.width, height: designSize.height, alignment: .topLeading)
                    .scaleEffect(min(proxy.size.width / designSize.width, proxy.size.height / designSize.height))
                    .frame(width: proxy.size.width, height: proxy.size.height)
            }
            HStack(spacing: 12) {
                Picker("Preview", selection: $showsApps.animation(.easeInOut(duration: 0.3))) {
                    Label("Apps", systemImage: "macwindow.on.rectangle").tag(true)
                    Label("Wallpaper", systemImage: "photo").tag(false)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
                if showsAppearanceToggle, theme.alternate != nil {
                    Picker("Appearance", selection: Binding(get: { shown.appearance }, set: { model.appearance = $0 }).animation(.easeInOut(duration: 0.3))) {
                        Image(systemName: "moon.fill").tag(Appearance.dark)
                        Image(systemName: "sun.max.fill").tag(Appearance.light)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .fixedSize()
                    .help("Preview the dark or light version")
                }
            }
        }
        .task(id: shown) {
            if debounce { try? await Task.sleep(for: .milliseconds(600)) }
            guard !Task.isCancelled else { return }
            await model.wallpapers.load(shown)
        }
    }

    private var scene: some View {
        ZStack(alignment: .topLeading) {
            WallpaperView(theme: shown)
                .frame(width: designSize.width, height: designSize.height)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(.white.opacity(0.12), lineWidth: 1))
                .shadow(color: .black.opacity(0.35), radius: 24, y: 14)
            if showsApps {
                ZStack(alignment: .topLeading) {
                    BrowserMock(theme: shown)
                        .frame(width: 210, height: 300)
                        .offset(x: 30, y: 70)
                    EditorMock(theme: shown)
                        .frame(width: 420, height: 270)
                        .offset(x: 180, y: 30)
                    TerminalMock(theme: shown)
                        .frame(width: 330, height: 170)
                        .offset(x: 320, y: 240)
                }
                .transition(.opacity.combined(with: .scale(scale: 0.97)))
            }
        }
    }
}

/// The theme's rendered wallpaper, or its colors while the render is on its way.
struct WallpaperView: View {
    @Environment(AppModel.self) private var model
    let theme: Theme

    var body: some View {
        ZStack {
            LinearGradient(colors: [theme.palette.deep.color, theme.palette.base.color], startPoint: .topLeading, endPoint: .bottomTrailing)
            RadialGradient(colors: [theme.backdrop.glow.color.opacity(0.35), .clear], center: .bottomTrailing, startRadius: 0, endRadius: 400)
            if let image = model.wallpapers.images[theme] {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fill)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.4), value: model.wallpapers.images[theme] != nil)
    }
}

private struct MockWindow<Content: View>: View {
    let theme: Theme
    var title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                ForEach([Color(red: 1, green: 0.37, blue: 0.34), Color(red: 1, green: 0.74, blue: 0.18), Color(red: 0.16, green: 0.79, blue: 0.25)], id: \.self) {
                    Circle().fill($0).frame(width: 9, height: 9)
                }
                Text(title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(theme.palette.textMuted.color)
                    .padding(.leading, 6)
                Spacer()
            }
            .padding(.horizontal, 10)
            .frame(height: 26)
            .background(theme.palette.deep.color)
            content
        }
        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).strokeBorder(theme.palette.border.color, lineWidth: 1))
        .shadow(color: .black.opacity(0.45), radius: 22, y: 12)
    }
}

private struct EditorMock: View {
    let theme: Theme

    var body: some View {
        MockWindow(theme: theme, title: "opaline — ThemeStore.swift") {
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 7) {
                    ForEach(["Sources", "Model", "Theme.swift", "ThemeStore.swift", "Targets", "Tests"], id: \.self) { name in
                        let selected = name == "ThemeStore.swift"
                        Text(name)
                            .font(.system(size: 10))
                            .foregroundStyle(selected ? theme.palette.text.color : theme.palette.textMuted.color)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(selected ? theme.palette.selection.color : .clear, in: RoundedRectangle(cornerRadius: 4))
                            .padding(.leading, ["Sources", "Tests"].contains(name) ? 0 : 10)
                    }
                    Spacer()
                }
                .padding(10)
                .frame(width: 130)
                .background(theme.palette.surface.color)

                VStack(alignment: .leading, spacing: 5) {
                    ForEach(Array(codeLines.enumerated()), id: \.offset) { index, line in
                        HStack(spacing: 10) {
                            Text("\(index + 1)")
                                .foregroundStyle(index == 3 ? theme.palette.accentSoft.color : theme.palette.textFaint.color)
                                .frame(width: 14, alignment: .trailing)
                            line
                        }
                        .font(.system(size: 10.5, design: .monospaced))
                        .padding(.vertical, 1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(index == 3 ? theme.palette.base.mixed(with: theme.palette.elevated, 0.6).color : .clear)
                    }
                    Spacer()
                }
                .padding(.vertical, 10)
                .background(theme.palette.base.color)
            }
        }
    }

    private var codeLines: [Text] {
        let s = theme.syntax
        func t(_ text: String, _ color: HexColor) -> Text { Text(text).foregroundStyle(color.color) }
        return [
            t("// Themes live next to their assets.", s.comment).italic(),
            t("public struct ", s.keyword) + t("ThemeStore", s.type) + t(" {", s.punctuation),
            t("  let ", s.keyword) + t("directory", s.variable) + t(": ", s.punctuation) + t("URL", s.type),
            t("  func ", s.keyword) + t("load", s.function) + t("() ", s.punctuation) + t("throws", s.keyword) + t(" -> [", s.punctuation) + t("Theme", s.type) + t("] {", s.punctuation),
            t("    let ", s.keyword) + t("limit", s.variable) + t(" = ", s.operator) + t("256", s.number),
            t("    return ", s.keyword) + t("try ", s.keyword) + t("decode", s.function) + t("(", s.punctuation) + t("\"theme.json\"", s.string) + t(")", s.punctuation),
            t("  }", s.punctuation),
            t("}", s.punctuation),
        ]
    }
}

private struct TerminalMock: View {
    let theme: Theme

    var body: some View {
        MockWindow(theme: theme, title: "zsh — ~/Developer") {
            VStack(alignment: .leading, spacing: 5) {
                line(("❯ ", 2), ("git ", 7), ("status", 15))
                line(("On branch ", 15), ("main", 6))
                line(("  modified: ", 1), ("Sources/Theme.swift", 15))
                line(("  new file: ", 2), ("Themes/opaline.json", 15))
                line(("❯ ", 2), ("swift test", 15))
                line(("✔ ", 2), ("all tests passed", 10))
                HStack(spacing: 0) {
                    Text("❯ ").foregroundStyle(ansi(2))
                    Rectangle().fill(theme.palette.accent.color).frame(width: 7, height: 13)
                }
                Spacer()
                HStack(spacing: 5) {
                    ForEach(0..<8, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 2).fill(ansi(index + 8)).frame(height: 7)
                    }
                }
            }
            .font(.system(size: 10.5, design: .monospaced))
            .padding(10)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(
                ZStack {
                    theme.palette.base.color
                    RadialGradient(colors: [theme.backdrop.glow.color.opacity(theme.backdrop.glowStrength), .clear], center: .bottomTrailing, startRadius: 0, endRadius: 260)
                }
            )
        }
    }

    private func ansi(_ index: Int) -> Color { theme.terminal.ansi[index].color }

    private func line(_ parts: (String, Int)...) -> some View {
        parts.reduce(Text("")) { $0 + Text($1.0).foregroundStyle(ansi($1.1)) }
    }
}

private struct BrowserMock: View {
    let theme: Theme

    var body: some View {
        let colors = theme.browser.colors.map(\.color)
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { _ in Circle().fill(theme.palette.text.color.opacity(0.25)).frame(width: 8, height: 8) }
            }
            RoundedRectangle(cornerRadius: 7).fill(theme.palette.text.color.opacity(0.08)).frame(height: 22)
                .overlay(Text("opaline.app").font(.system(size: 9)).foregroundStyle(theme.palette.textMuted.color).padding(.leading, 8), alignment: .leading)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3), spacing: 6) {
                ForEach(0..<6, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 7)
                        .fill(theme.palette.text.color.opacity(0.07))
                        .frame(height: 30)
                        .overlay(Circle().fill(theme.swatches[(index + 2) % theme.swatches.count].color).frame(width: 11, height: 11))
                }
            }
            ForEach(["Inbox", "Projects", "Design", "Reading"], id: \.self) { folder in
                Label(folder, systemImage: "folder")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(theme.palette.text.color.opacity(0.9))
            }
            RoundedRectangle(cornerRadius: 6)
                .fill(theme.palette.text.color.opacity(0.12))
                .frame(height: 22)
                .overlay(Text("Release notes").font(.system(size: 9.5)).foregroundStyle(theme.palette.text.color).padding(.leading, 8), alignment: .leading)
            Spacer()
        }
        .padding(12)
        .background(
            LinearGradient(colors: colors.count > 1 ? colors : colors + colors, startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(theme.palette.text.color.opacity(0.1), lineWidth: 1))
        .shadow(color: .black.opacity(0.4), radius: 18, y: 10)
    }
}
