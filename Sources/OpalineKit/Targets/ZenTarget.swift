import Foundation

/// Zen's default profile, found through `installs.ini` (the profile the installed app opens).
struct ZenProfile {
    static let bundleIdentifier = "app.zen-browser.zen"
    static let cssBlockStart = "/* >>> opaline (managed, edits are overwritten) >>> */"
    static let cssBlockEnd = "/* <<< opaline <<< */"

    static func directory(in environment: OpalineEnvironment) -> URL? {
        let root = environment.url("~/Library/Application Support/zen")
        for file in ["installs.ini", "profiles.ini"] {
            guard let text = try? String(contentsOf: root.appending(path: file), encoding: .utf8) else { continue }
            let path = text.components(separatedBy: "\n")
                .first { $0.hasPrefix("Default=") && $0.contains("/") }
                .map { String($0.dropFirst("Default=".count)) }
            if let path { return root.appending(path: path, directoryHint: .isDirectory) }
        }
        return nil
    }
}

/// Zen workspaces: gradient, opacity and grain of every space, dark or light window, no macOS blur behind the theme.
/// Zen keeps one gradient per space and picks its text colors from it, so the other variant of a light and dark theme
/// comes from `userChrome.css`, under a `prefers-color-scheme` query.
public struct ZenTarget: ThemeTarget {
    public init() {}

    public var info: TargetInfo {
        TargetInfo(
            id: "zen",
            name: "Zen",
            summary: "Workspace gradient and window scheme. Zen restarts during the change.",
            symbol: "globe",
            appURL: OpalineEnvironment.current.application("Zen"),
            bundleIdentifier: ZenProfile.bundleIdentifier,
            quitsApp: true
        )
    }

    public func files(in context: TargetContext) -> [URL] {
        guard let profile = ZenProfile.directory(in: context.environment) else { return [] }
        return ["zen-sessions.jsonlz4", "prefs.js", "chrome/userChrome.css"].map { profile.appending(path: $0) }
    }

    public func isInstalled(in context: TargetContext) -> Bool {
        ZenProfile.directory(in: context.environment) != nil
    }

    public func changes(for theme: Theme, in context: TargetContext) async throws -> [FileChange] {
        guard let profile = ZenProfile.directory(in: context.environment) else { throw TargetError.missingFile("Zen profile") }
        let sessions = profile.appending(path: "zen-sessions.jsonlz4")
        let prefs = profile.appending(path: "prefs.js")
        let userChrome = profile.appending(path: "chrome/userChrome.css")
        guard sessions.exists else { throw TargetError.missingFile(context.environment.display(sessions)) }
        return [
            FileChange(url: sessions, contents: try MozLZ4.encode(Self.sessions(try MozLZ4.decode(Data(contentsOf: sessions)), theme: theme))),
            FileChange(url: userChrome, text: Self.userChrome(context.read(userChrome) ?? "", theme: theme)),
            FileChange(url: prefs, text: FirefoxPrefs.set([
                // 0 dark, 1 light, 2 follows the Mac.
                ("zen.view.window.scheme", .int(theme.alternate != nil ? 2 : (theme.appearance == .dark ? 0 : 1))),
                ("zen.widget.macos.window-vibrancy", .bool(false)),
                ("toolkit.legacyUserProfileCustomizations.stylesheets", .bool(true)),
            ], in: context.read(prefs) ?? "")),
        ]
    }

    static let textTokens = [
        "--toolbox-textcolor", "--toolbox-textcolor-inactive", "--toolbar-color", "--toolbar-field-color",
        "--toolbox-text-color", "--toolbox-text-color-current", "--toolbox-text-color-inactive", "--toolbar-text-color",
        "--tab-text-color", "--tab-text-color-hover", "--tab-text-color-selected", "--sidebar-text-color", "--lwt-text-color",
    ]

    /// Zen's own two-color layout (`ZenGradientGenerator`): the second color from the bottom left, the first from the
    /// top right, over the first as a solid base; the toolbar gets a plain blend.
    static func gradients(_ colors: [String], fallback: String) -> (window: String, toolbar: String) {
        guard colors.count > 1 else { return (colors.first ?? fallback, colors.first ?? fallback) }
        let (first, second) = (colors[0], colors[1])
        return (
            "linear-gradient(150deg, \(first) 30%, transparent 120%), linear-gradient(-30deg, \(second) 30%, transparent 120%), \(first)",
            "linear-gradient(-30deg, \(second) 0%, \(first) 100%)"
        )
    }

    /// The managed block of `userChrome.css`: empty for a single theme, the alternate variant's window otherwise.
    /// User `!important` rules win over the values Zen sets inline from the space's gradient.
    static func userChrome(_ current: String, theme: Theme) -> String {
        var lines = [ZenProfile.cssBlockStart]
        if let alternate = theme.alternate {
            let variant = theme.variant(alternate.appearance)
            let scheme = alternate.appearance.rawValue
            let (window, toolbar) = Self.gradients(variant.browser.colors.map(\.opaqueHex), fallback: variant.palette.base.opaqueHex)
            lines += [
                "@media (prefers-color-scheme: \(scheme)) {",
                "  .zen-browser-generic-background {",
                "    --zen-main-browser-background: \(window) !important;",
                "    --zen-main-browser-background-old: \(window) !important;",
                "    --zen-main-browser-background-toolbar: \(toolbar) !important;",
                "    --zen-main-browser-background-toolbar-old: \(toolbar) !important;",
                "  }",
                // Zen's own and Firefox's text tokens, on the root, the sidebar and each space, where Zen sets them inline.
                "  :root, #navigator-toolbox, #browser, zen-workspace {",
                "    color-scheme: \(scheme) !important;",
                "    --zen-primary-color: \(variant.palette.accent.opaqueHex) !important;",
                "    --toolbar-color-scheme: \(scheme) !important;",
                "    --zen-backdrop-underlay: url(\"chrome://browser/content/zen-styles/zen-backdrop-filters.svg#underlay-\(scheme)\") !important;",
            ] + Self.textTokens.map { "    \($0): \(variant.palette.text.opaqueHex) !important;" } + [
                "  }",
                "  #navigator-toolbox { color: \(variant.palette.text.opaqueHex) !important; }",
                "}",
            ]
        }
        lines.append(ZenProfile.cssBlockEnd)
        return ManagedBlock.replace(in: current, start: ZenProfile.cssBlockStart, end: ZenProfile.cssBlockEnd, with: lines.joined(separator: "\n"))
    }

    static func sessions(_ data: Data, theme: Theme) throws -> Data {
        guard var root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let spaces = root["spaces"] as? [[String: Any]] else {
            throw TargetError.invalidConfig("zen-sessions.jsonlz4 has no spaces")
        }
        let gradient: [[String: Any]] = theme.browser.colors.enumerated().map { index, color in
            let bytes = color.rgbBytes
            return ["c": [bytes.red, bytes.green, bytes.blue], "isCustom": false, "algorithm": "",
                    "isPrimary": index == 0, "lightness": 50, "type": "undefined"]
        }
        root["spaces"] = spaces.map { space in
            var space = space
            space["theme"] = ["type": "gradient", "gradientColors": gradient,
                              "opacity": theme.browser.opacity, "texture": theme.browser.texture]
            return space
        }
        return try JSONSerialization.data(withJSONObject: root)
    }
}

/// GitHub's dark theme recolored with the theme, through Zen's `userContent.css`.
public struct GitHubTarget: ThemeTarget {
    public init() {}

    public var info: TargetInfo {
        TargetInfo(
            id: "github",
            name: "GitHub in Zen",
            summary: "github.com dark mode recolored, with the glow page background.",
            symbol: "chevron.left.slash.chevron.right",
            appURL: OpalineEnvironment.current.application("Zen"),
            bundleIdentifier: ZenProfile.bundleIdentifier,
            quitsApp: true
        )
    }

    public func files(in context: TargetContext) -> [URL] {
        guard let profile = ZenProfile.directory(in: context.environment) else { return [] }
        return [profile.appending(path: "chrome/userContent.css"), profile.appending(path: "prefs.js")]
    }

    public func isInstalled(in context: TargetContext) -> Bool {
        ZenProfile.directory(in: context.environment) != nil
    }

    public func changes(for theme: Theme, in context: TargetContext) async throws -> [FileChange] {
        guard let profile = ZenProfile.directory(in: context.environment) else { throw TargetError.missingFile("Zen profile") }
        let dark = theme.variant(.dark)
        guard dark.appearance == .dark else { throw TargetError.unsupported("GitHub theming follows GitHub's dark palette; light-only themes are skipped.") }
        let css = profile.appending(path: "chrome/userContent.css")
        let prefs = profile.appending(path: "prefs.js")
        let block = [ZenProfile.cssBlockStart, try GitHubStylesheet.css(for: dark), ZenProfile.cssBlockEnd].joined(separator: "\n")
        return [
            FileChange(url: css, text: ManagedBlock.replace(in: Self.unmanaged(context.read(css)), start: ZenProfile.cssBlockStart, end: ZenProfile.cssBlockEnd, with: block)),
            FileChange(url: prefs, text: FirefoxPrefs.set([("toolkit.legacyUserProfileCustomizations.stylesheets", .bool(true))], in: context.read(prefs) ?? "")),
        ]
    }

    /// A stylesheet written before Opaline managed it is replaced wholesale.
    private static func unmanaged(_ text: String?) -> String {
        guard let text, text.contains(ZenProfile.cssBlockStart) else { return "" }
        return text
    }
}
