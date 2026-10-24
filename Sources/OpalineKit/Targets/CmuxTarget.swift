import Foundation

/// cmux chrome: accent, sidebar tint, selected workspace and focused pane border.
public struct CmuxTarget: ThemeTarget {
    public init() {}

    static let cli = URL(fileURLWithPath: "/Applications/cmux.app/Contents/Resources/bin/cmux")

    public var info: TargetInfo {
        TargetInfo(
            id: "cmux",
            name: "cmux",
            summary: "Accent, sidebar tint, selected workspace and focused pane.",
            symbol: "rectangle.split.3x1",
            appURL: OpalineEnvironment.current.application("cmux"),
            bundleIdentifier: "com.cmuxterm.app"
        )
    }

    private func config(_ context: TargetContext) -> URL { context.environment.url("~/.config/cmux/cmux.json") }

    public func files(in context: TargetContext) -> [URL] { [config(context)] }

    public func isInstalled(in context: TargetContext) -> Bool {
        context.environment.application("cmux").exists
    }

    public func changes(for theme: Theme, in context: TargetContext) async throws -> [FileChange] {
        let current = context.read(config(context)) ?? "{\n  \"schemaVersion\": 1\n}\n"
        return [FileChange(url: config(context), text: try Self.config(current, theme: theme))]
    }

    public func didApply(_ theme: Theme, in context: TargetContext) async throws {
        _ = try? await Shell.run(Self.cli, ["reload-config"])
    }

    static func config(_ current: String, theme: Theme) throws -> String {
        let palette = theme.palette
        // A theme with both appearances lets cmux follow the Mac, with a sidebar tint per mode.
        func tint(_ appearance: Appearance) -> String {
            theme.alternate == nil ? "null" : JSONCEditor.literal(theme.variant(appearance).palette.base.opaqueHex)
        }
        let values: [([String], String)] = [
            (["app", "appearance"], JSONCEditor.literal(theme.alternate == nil ? theme.appearance.rawValue : "system")),
            (["app", "accentColor"], JSONCEditor.literal(palette.accent.opaqueHex)),
            (["sidebarAppearance", "tintColor"], JSONCEditor.literal(palette.base.opaqueHex)),
            (["sidebarAppearance", "lightModeTintColor"], tint(.light)),
            (["sidebarAppearance", "darkModeTintColor"], tint(.dark)),
            (["sidebarAppearance", "tintOpacity"], "0.85"),
            (["workspaceColors", "selectionColor"], JSONCEditor.literal(palette.selection.opaqueHex)),
            (["activePaneBorderColor"], JSONCEditor.literal(palette.accent.opaqueHex)),
        ]
        return try values.reduce(current) { try JSONCEditor.set($1.0, to: $1.1, in: $0) }
    }
}
