import Foundation

/// Rotates GitHub's blue-grey dark palette to the theme hue and paints the page with the backdrop glow.
enum GitHubStylesheet {
    private static let blueHues = 190.0...245.0
    private static let saturationScale = 0.5
    private static let neutralMaxSaturation = 0.12
    private static let darkLift = 0.09
    /// Families whose colors carry meaning (labels, syntax, diffs data viz) and must not be recolored.
    private static let keptPrefixes = ["--display-", "--data-", "--ansi-", "--color-prettylights-", "--syntax-", "--contribution-"]

    static func css(for theme: Theme) throws -> String {
        let source = try KitResources.text("github-dark.css")
        guard let open = source.firstIndex(of: "{"), let close = source[open...].firstIndex(of: "}") else {
            throw TargetError.invalidConfig("GitHub palette source")
        }
        var variables: [String: String] = [:]
        let declaration = /(--[\w-]+):\s*([^;}]+)/
        for match in source[source.index(after: open)..<close].matches(of: declaration) {
            let name = String(match.1), value = match.2.trimmingCharacters(in: .whitespaces)
            guard !keptPrefixes.contains(where: name.hasPrefix), let color = HexColor(value),
                  let recolored = recolor(color, hue: theme.backdrop.webHue) else { continue }
            variables[name] = recolored.hex
        }
        let p = theme.palette
        for (name, color) in [
            ("--bgColor-default", p.base), ("--fgColor-default", p.text), ("--fgColor-muted", p.textMuted),
            ("--fgColor-accent", p.accent), ("--borderColor-accent-emphasis", p.accentDeep),
            ("--bgColor-accent-emphasis", p.accentDeep), ("--underlineNav-borderColor-active", p.accent),
            ("--focus-outlineColor", p.accent), ("--selection-bgColor", p.selection.withAlpha(0.7)),
        ] {
            variables[name] = color.hex
        }

        let glow = theme.backdrop.glow.rgbBytes
        let strength = theme.backdrop.glowStrength
        func stop(_ factor: Double, _ at: Int) -> String {
            "rgba(\(glow.red), \(glow.green), \(glow.blue), \(String(format: "%.2f", strength * factor))) \(at)%"
        }
        let background = "radial-gradient(circle farthest-corner at 100% 100%, \(stop(1, 0)), \(stop(0.41, 35)), \(stop(0.09, 70)), transparent 100%) fixed, \(p.base.opaqueHex)"
        let body = variables.sorted { $0.key < $1.key }.map { "      \($0.key): \($0.value) !important;" }.joined(separator: "\n")
        let selector = #":root:is([data-color-mode="dark"], [data-color-mode="auto"])"#
        return """
        @-moz-document domain("github.com") {
          @media (prefers-color-scheme: dark) {
            \(selector) {
        \(body)
            }
            \(selector) body {
              background: \(background) !important;
            }
          }
        }
        """
    }

    static func recolor(_ color: HexColor, hue: Double) -> HexColor? {
        let (sourceHue, sourceSaturation, sourceLightness) = color.hsl
        guard blueHues.contains(sourceHue) else { return nil }
        let neutral = sourceSaturation < 0.35 || sourceLightness < 0.15
        let saturation = neutral
            ? min(sourceSaturation * saturationScale, neutralMaxSaturation)
            : sourceSaturation * saturationScale
        let lightness = sourceLightness < 0.5 ? sourceLightness + darkLift * (1 - sourceLightness / 0.5) : sourceLightness
        return HexColor(hue: hue, saturation: saturation, lightness: lightness, alpha: color.alpha)
    }
}
