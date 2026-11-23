import Foundation

/// Cockpit's user theme, `theme.json` in its home: the `light` and `dark` blocks of its tokens, so Cockpit follows the
/// Mac's appearance itself and reloads the file live. The release reads `~/.cockpit`, a dev build `~/.cockpit-dev`.
public struct CockpitTarget: ThemeTarget {
    public init() {}

    public var info: TargetInfo {
        TargetInfo(
            id: "cockpit",
            name: "Cockpit",
            summary: "Surfaces, text, accent, diff, code and terminal colors, light and dark.",
            symbol: "gauge.with.dots.needle.33percent",
            appURL: OpalineEnvironment.current.url("~/Applications/Cockpit.app")
        )
    }

    public func files(in context: TargetContext) -> [URL] {
        let dev = context.environment.url("~/.cockpit-dev")
        return ([context.environment.url("~/.cockpit")] + (dev.exists ? [dev] : [])).map { $0.appending(path: "theme.json") }
    }

    public func isInstalled(in context: TargetContext) -> Bool {
        context.environment.url("~/Applications/Cockpit.app").exists || context.environment.url("~/.local/bin/cockpit").exists
    }

    public func changes(for theme: Theme, in context: TargetContext) async throws -> [FileChange] {
        try files(in: context).map { url in
            FileChange(url: url, text: try Self.file(context.read(url) ?? "{}\n", theme: theme))
        }
    }

    /// `current` with every token of both blocks set; the rest of the file (fonts, radius, comments) is kept.
    static func file(_ current: String, theme: Theme) throws -> String {
        try Appearance.allCases.reduce(current) { text, appearance in
            // A new member goes first: setting them in reverse leaves a new file in alphabetical order.
            try tokens(theme.variant(appearance)).sorted { $0.key > $1.key }.reduce(text) { text, token in
                try JSONCEditor.set(["cssVars", appearance.rawValue, token.key], to: JSONCEditor.literal(token.value), in: text)
            }
        }
    }

    /// Cockpit's tokens for one variant. Text levels and tones are mixed towards `text` until they pass WCAG AA as
    /// Cockpit checks it: text 4.5:1 on every ground, each tone on its own 12 % pill too, control edges 3:1.
    static func tokens(_ theme: Theme) -> [String: String] {
        let p = theme.palette
        let dark = theme.appearance == .dark
        let grounds = [p.base, p.elevated, p.surface]
        func tone(_ color: HexColor) -> HexColor {
            stride(from: 0.0, through: 1, by: 0.02).lazy
                .map { color.mixed(with: p.text, $0) }
                .first { candidate in
                    grounds.allSatisfy { candidate.contrast(with: $0) >= 4.5 && candidate.contrast(with: $0.mixed(with: candidate, 0.12)) >= 4.5 }
                } ?? p.text
        }
        let accent = tone(p.accent)
        let black = HexColor(red: 0, green: 0, blue: 0), white = HexColor(red: 1, green: 1, blue: 1)
        let nearBlack = accent.mixed(with: black, 0.93)
        let onAccent = accent.contrast(with: nearBlack) >= accent.contrast(with: white) ? nearBlack : white
        let muted = p.textMuted.legible(on: grounds, ratio: 4.5, toward: p.text)
        let secondary = muted.mixed(with: p.text, 0.5)
        let headings = dark ? [0.2, 0.45, 0.7, 0.88].map { accent.mixed(with: white, $0) } : [0, 0.25, 0.5, 1].map { accent.mixed(with: p.text, $0) }
        let (success, warning, error) = (tone(p.success), tone(p.warning), tone(p.error))

        var colors: [String: HexColor] = [
            "background": p.base,
            "card": p.elevated,
            "popover": p.elevated,
            "secondary": p.elevated,
            "surface": p.surface,
            "sidebar": p.surface,
            "muted": p.hover,
            "accent": p.highlight,
            "sidebar-accent": p.highlight,
            "wash": p.highlight,
            "border": p.border,
            "rule": p.borderSubtle,
            "sidebar-border": p.borderSubtle,
            "input": p.textSubtle.legible(on: grounds, ratio: 3, toward: p.text),
            "muted-foreground": muted,
            "text-secondary": secondary,
            "sidebar-foreground": secondary,
            "brand": accent,
            "ring": accent,
            "brand-foreground": onAccent,
            "primary": dark ? accent : p.text,
            "primary-foreground": dark ? onAccent : p.elevated,
            "success": success,
            "warn": warning,
            "danger": error,
            "destructive": error,
            "info": tone(p.info),
            "diff-added": p.success,
            "diff-deleted": p.error,
        ]
        for name in ["foreground", "card-foreground", "popover-foreground", "secondary-foreground", "accent-foreground",
                     "sidebar-accent-foreground", "prose-text"] {
            colors[name] = p.text
        }
        for (level, heading) in headings.enumerated() {
            colors["prose-h\(level + 1)"] = heading
        }
        let s = theme.syntax
        let syntax = ["keyword": s.keyword, "function": s.function, "type": s.type, "string": s.string, "number": s.number,
                      "comment": s.comment, "property": s.property]
        for (role, color) in syntax {
            colors["syntax-\(role)"] = color
        }
        for (index, color) in theme.terminal.ansi.enumerated() {
            colors["ansi-\(index)"] = color
        }

        var tokens = colors.mapValues(\.opaqueHex)
        let (r, g, b) = accent.rgbBytes
        tokens["prose-code-bg"] = String(format: "rgba(%d, %d, %d, %.2f)", r, g, b, dark ? 0.10 : 0.08)
        tokens["prose-rule"] = "rgba(\(r), \(g), \(b), 0.35)"
        return tokens
    }
}
