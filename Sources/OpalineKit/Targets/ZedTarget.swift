import Foundation

/// A Zed theme family file, selected in `~/.config/zed/settings.json`.
public struct ZedTarget: ThemeTarget {
    public init() {}

    public var info: TargetInfo {
        TargetInfo(
            id: "zed",
            name: "Zed",
            summary: "Editor, panels, git status, terminal and syntax highlighting.",
            symbol: "chevron.left.forwardslash.chevron.right",
            appURL: OpalineEnvironment.current.application("Zed"),
            bundleIdentifier: "dev.zed.Zed"
        )
    }

    private func settings(_ context: TargetContext) -> URL { context.environment.url("~/.config/zed/settings.json") }
    private func themeFile(_ theme: Theme, _ context: TargetContext) -> URL { context.environment.url("~/.config/zed/themes/\(theme.id).json") }

    public func files(in context: TargetContext) -> [URL] {
        [settings(context), context.environment.url("~/.config/zed/themes/")]
    }

    public func isInstalled(in context: TargetContext) -> Bool {
        context.environment.application("Zed").exists || context.environment.url("~/.config/zed").exists
    }

    public func changes(for theme: Theme, in context: TargetContext) async throws -> [FileChange] {
        let current = context.read(settings(context)) ?? "{}\n"
        return [
            FileChange(url: themeFile(theme, context), contents: try Self.themeFile(theme)),
            FileChange(url: settings(context), text: try Self.settings(current, theme: theme)),
        ]
    }

    /// `theme` is either a name or `{ mode, light, dark }`; keep the user's shape. A theme with both appearances
    /// sets the object with `mode: system` so Zed follows the Mac.
    static func settings(_ current: String, theme: Theme) throws -> String {
        let existingIsObject = try JSONCEditor.value(at: ["theme"], in: current)?.hasPrefix("{") ?? false
        guard theme.alternate != nil else {
            let name = JSONCEditor.literal(theme.name)
            return existingIsObject
                ? try JSONCEditor.set(["theme", theme.appearance.rawValue], to: name, in: current)
                : try JSONCEditor.set(["theme"], to: name, in: current)
        }
        let light = JSONCEditor.literal(theme.variantName(.light)), dark = JSONCEditor.literal(theme.variantName(.dark))
        guard existingIsObject else {
            return try JSONCEditor.set(["theme"], to: "{ \"mode\": \"system\", \"light\": \(light), \"dark\": \(dark) }", in: current)
        }
        return try [(["theme", "mode"], JSONCEditor.literal("system")), (["theme", "light"], light), (["theme", "dark"], dark)]
            .reduce(current) { try JSONCEditor.set($1.0, to: $1.1, in: $0) }
    }

    static func themeFile(_ theme: Theme) throws -> Data {
        let family: [String: Any] = [
            "$schema": "https://zed.dev/schema/themes/v0.2.0.json",
            "name": theme.name,
            "author": theme.author,
            "themes": theme.appearances.map { appearance in
                ["name": theme.variantName(appearance), "appearance": appearance.rawValue, "style": style(theme.variant(appearance))]
            },
        ]
        return try JSONSerialization.data(withJSONObject: family, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
    }

    private static func style(_ theme: Theme) -> [String: Any] {
        let p = theme.palette
        let ansi = theme.terminal.ansi
        func hex(_ color: HexColor) -> String { color.hex }
        func tint(_ color: HexColor, _ alpha: Double) -> String { color.withAlpha(alpha).hex }
        let clear = "#00000000"

        var style: [String: Any] = [
            "background": hex(p.deep),
            "surface.background": hex(p.surface),
            "elevated_surface.background": hex(p.elevated),
            "panel.background": hex(p.surface),
            "editor.background": hex(p.base),
            "editor.gutter.background": hex(p.base),
            "editor.subheader.background": hex(p.surface),
            "editor.foreground": hex(p.text),
            "editor.active_line.background": hex(p.base.mixed(with: p.elevated, 0.6)),
            "editor.highlighted_line.background": hex(p.elevated),
            "editor.line_number": hex(p.textFaint),
            "editor.active_line_number": hex(p.accentSoft),
            "editor.invisible": hex(p.border.mixed(with: p.textFaint, 0.4)),
            "editor.wrap_guide": hex(p.borderSubtle),
            "editor.active_wrap_guide": hex(p.border),
            "editor.indent_guide": hex(p.borderSubtle),
            "editor.indent_guide_active": hex(p.accentDim),
            "editor.document_highlight.read_background": tint(p.accent, 0.12),
            "editor.document_highlight.write_background": tint(p.accent, 0.2),
            "editor.document_highlight.bracket_background": tint(p.accent, 0.18),
            "title_bar.background": hex(p.deep),
            "title_bar.inactive_background": hex(p.deep.mixed(with: .init(red: 0, green: 0, blue: 0), 0.15)),
            "toolbar.background": hex(p.base),
            "tab_bar.background": hex(p.deep),
            "tab.inactive_background": hex(p.deep),
            "tab.active_background": hex(p.base),
            "status_bar.background": hex(p.deep),
            "pane.focused_border": hex(p.accent),
            "pane_group.border": hex(p.borderSubtle),
            "panel.focused_border": hex(p.accentDim),
            "panel.indent_guide": hex(p.borderSubtle),
            "panel.indent_guide_active": hex(p.accentDim),
            "panel.indent_guide_hover": hex(p.accentDeep),
            "border": hex(p.border),
            "border.variant": hex(p.borderSubtle),
            "border.focused": hex(p.accent),
            "border.selected": hex(p.accentDeep),
            "border.transparent": clear,
            "border.disabled": hex(p.borderSubtle),
            "element.background": hex(p.elevated),
            "element.hover": hex(p.hover),
            "element.active": hex(p.selection),
            "element.selected": hex(p.selection),
            "element.disabled": hex(p.base.mixed(with: p.elevated, 0.6)),
            "ghost_element.background": clear,
            "ghost_element.hover": hex(p.elevated),
            "ghost_element.active": hex(p.hover),
            "ghost_element.selected": hex(p.selection),
            "ghost_element.disabled": clear,
            "drop_target.background": tint(p.accent, 0.15),
            "text": hex(p.text),
            "text.muted": hex(p.textMuted),
            "text.placeholder": hex(p.textSubtle),
            "text.disabled": hex(p.textFaint),
            "text.accent": hex(p.accent),
            "link_text.hover": hex(p.accentSoft),
            "icon": hex(p.text.mixed(with: p.textMuted, 0.6)),
            "icon.muted": hex(p.textMuted),
            "icon.disabled": hex(p.textFaint),
            "icon.placeholder": hex(p.textSubtle),
            "icon.accent": hex(p.accent),
            "scrollbar.track.background": clear,
            "scrollbar.track.border": clear,
            "scrollbar.thumb.background": tint(p.accent, 0.15),
            "scrollbar.thumb.hover_background": tint(p.accent, 0.25),
            "scrollbar.thumb.border": clear,
            "search.match_background": tint(p.accent, 0.25),
            "accents": [p.accent, theme.syntax.function, p.warning, theme.syntax.special, theme.syntax.number, ansi[12]].map(hex),
            "terminal.background": hex(p.base),
            "terminal.ansi.background": hex(p.base),
            "terminal.foreground": hex(p.text),
            "terminal.bright_foreground": hex(p.text.mixed(with: .init(red: 1, green: 1, blue: 1), 0.5)),
            "terminal.dim_foreground": hex(p.textMuted),
            "players": [
                ["cursor": hex(p.accent), "background": hex(p.accent), "selection": tint(p.selection, 0.6)],
                ["cursor": hex(theme.syntax.function), "background": hex(theme.syntax.function), "selection": tint(theme.syntax.function, 0.2)],
                ["cursor": hex(p.warning), "background": hex(p.warning), "selection": tint(p.warning, 0.2)],
                ["cursor": hex(theme.syntax.special), "background": hex(theme.syntax.special), "selection": tint(theme.syntax.special, 0.2)],
            ],
        ]

        let statuses: [(String, HexColor)] = [
            ("error", p.error), ("warning", p.warning), ("info", p.info), ("hint", p.textMuted),
            ("success", p.success), ("created", p.success), ("modified", p.warning), ("deleted", p.error),
            ("renamed", p.info), ("conflict", theme.syntax.number), ("ignored", p.textSubtle),
            ("hidden", p.textSubtle), ("unreachable", theme.syntax.comment), ("predictive", theme.syntax.comment),
        ]
        for (name, color) in statuses {
            style[name] = hex(color)
            style["\(name).background"] = tint(color, 0.12)
            style["\(name).border"] = tint(color, 0.4)
        }

        let ansiNames = ["black", "red", "green", "yellow", "blue", "magenta", "cyan", "white"]
        for (index, name) in ansiNames.enumerated() {
            style["terminal.ansi.\(name)"] = hex(ansi[index])
            style["terminal.ansi.bright_\(name)"] = hex(ansi[index + 8])
            style["terminal.ansi.dim_\(name)"] = hex(ansi[index].mixed(with: p.base, 0.3))
        }

        let s = theme.syntax
        func token(_ color: HexColor, italic: Bool = false, bold: Bool = false) -> [String: Any] {
            var value: [String: Any] = ["color": hex(color)]
            if italic { value["font_style"] = "italic" }
            if bold { value["font_weight"] = 700 }
            return value
        }
        style["syntax"] = [
            "attribute": token(s.type), "boolean": token(s.number), "comment": token(s.comment, italic: true),
            "comment.doc": token(s.comment.mixed(with: p.textMuted, 0.3), italic: true), "constant": token(s.number),
            "constructor": token(s.type), "embedded": token(p.text), "emphasis": token(p.accentSoft, italic: true),
            "emphasis.strong": token(p.accentSoft, bold: true), "enum": token(s.type), "function": token(s.function),
            "function.method": token(s.function), "hint": token(s.comment, italic: true), "keyword": token(s.keyword),
            "label": token(s.special), "link_text": token(s.function), "link_uri": token(s.function, italic: true),
            "number": token(s.number), "operator": token(s.operator), "predictive": token(p.textSubtle, italic: true),
            "preproc": token(s.special), "primary": token(p.text), "property": token(s.property),
            "punctuation": token(s.punctuation), "punctuation.bracket": token(p.text.mixed(with: p.textMuted, 0.6)),
            "punctuation.delimiter": token(s.punctuation), "punctuation.list_marker": token(s.keyword),
            "punctuation.special": token(s.special), "string": token(s.string), "string.escape": token(s.function),
            "string.regex": token(s.special), "string.special": token(s.type), "string.special.symbol": token(s.type),
            "tag": token(s.keyword), "text.literal": token(s.string), "title": token(p.accent, bold: true),
            "type": token(s.type), "type.builtin": token(s.type), "variable": token(s.variable),
            "variable.special": token(s.special), "variant": token(s.type),
        ]

        return style
    }
}
