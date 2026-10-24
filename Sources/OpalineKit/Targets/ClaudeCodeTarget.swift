import Foundation

/// A Claude Code custom theme, selected through `theme` in `~/.claude/settings.json`.
/// A custom theme has one base, so a light and dark theme writes the variant of the Mac's appearance and Opaline
/// rewrites it on each switch; Claude Code reloads theme files live.
public struct ClaudeCodeTarget: ThemeTarget {
    public init() {}

    public var info: TargetInfo {
        TargetInfo(
            id: "claude-code",
            name: "Claude Code",
            summary: "Spinner, dialogs, prompt border, your messages and mouse selection.",
            symbol: "sparkle",
            followsAppearanceThroughOpaline: true
        )
    }

    private func settings(_ context: TargetContext) -> URL { context.environment.url("~/.claude/settings.json") }
    private func themeFile(_ theme: Theme, _ context: TargetContext) -> URL { context.environment.url("~/.claude/themes/\(theme.id).json") }

    public func files(in context: TargetContext) -> [URL] {
        [settings(context), context.environment.url("~/.claude/themes/")]
    }

    public func isInstalled(in context: TargetContext) -> Bool {
        context.environment.url("~/.claude").exists
    }

    public func changes(for theme: Theme, in context: TargetContext) async throws -> [FileChange] {
        let current = context.read(settings(context)) ?? "{}\n"
        let updated = try JSONCEditor.set(["theme"], to: JSONCEditor.literal("custom:\(theme.id)"), in: current)
        return [
            FileChange(url: themeFile(theme, context), contents: try Self.themeFile(theme.variant(context.appearance))),
            FileChange(url: settings(context), text: updated),
        ]
    }

    static func themeFile(_ theme: Theme) throws -> Data {
        let palette = theme.palette
        let overrides: [String: HexColor] = [
            "claude": palette.accent,
            "suggestion": palette.accentSoft,
            "permission": palette.accent,
            "permissionShimmer": palette.accentSoft,
            "claudeBlue_FOR_SYSTEM_SPINNER": palette.accent,
            "claudeBlueShimmer_FOR_SYSTEM_SPINNER": palette.accentSoft,
            "rate_limit_fill": palette.accent,
            "remember": palette.accentSoft,
            "promptBorder": palette.accentDeep,
            "inactive": palette.textMuted,
            "subtle": palette.textFaint,
            "selectionBg": palette.selection,
            "userMessageBackground": palette.highlight,
            "userMessageBackgroundHover": palette.highlight.mixed(with: palette.accent, 0.1),
        ]
        let document: [String: Any] = [
            "name": theme.name,
            "base": theme.appearance == .dark ? "dark" : "light",
            "overrides": overrides.mapValues(\.opaqueHex),
        ]
        return try JSONSerialization.data(withJSONObject: document, options: [.prettyPrinted, .sortedKeys])
    }
}
