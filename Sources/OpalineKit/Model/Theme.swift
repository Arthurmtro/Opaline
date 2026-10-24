import Foundation

public enum Appearance: String, Codable, Sendable, CaseIterable {
    case dark, light

    /// The Mac's current appearance.
    public static var system: Appearance {
        UserDefaults.standard.string(forKey: "AppleInterfaceStyle") == "Dark" ? .dark : .light
    }
}

/// A theme is a set of color roles. Each target translates the roles into its own config format.
/// On disk it is one JSON file (see `docs/THEME_FORMAT.md`); everything but the name and three colors is optional.
public struct Theme: Identifiable, Hashable, Sendable {
    public var id: String
    public var name: String
    public var author: String
    public var appearance: Appearance
    public var palette: Palette
    public var terminal: TerminalPalette
    public var syntax: SyntaxPalette
    public var backdrop: Backdrop
    public var browser: BrowserStyle
    public var wallpaper: WallpaperStyle
    /// Files referenced by the theme (SVG logos), keyed by name, stored inline.
    public var assets: [String: String]
    /// Colors for the opposite appearance. Apps that follow the Mac's light/dark switch get both.
    public var alternate: ThemeVariant?
}

/// The colors of a theme for one appearance.
public struct ThemeVariant: Hashable, Sendable {
    public var appearance: Appearance
    public var palette: Palette
    public var terminal: TerminalPalette
    public var syntax: SyntaxPalette
    public var backdrop: Backdrop
    public var browser: BrowserStyle
}

public extension Appearance {
    var opposite: Appearance { self == .dark ? .light : .dark }
}

public extension Theme {
    var primaryVariant: ThemeVariant {
        ThemeVariant(appearance: appearance, palette: palette, terminal: terminal, syntax: syntax, backdrop: backdrop, browser: browser)
    }

    /// Appearances this theme provides, primary first.
    var appearances: [Appearance] { alternate.map { [appearance, $0.appearance] } ?? [appearance] }

    /// The theme as worn in `appearance`, or the theme itself when it has no such variant.
    func variant(_ appearance: Appearance) -> Theme {
        guard appearance != self.appearance, let alternate, alternate.appearance == appearance else { return self }
        var theme = self
        theme.apply(alternate)
        theme.alternate = primaryVariant
        return theme
    }

    /// Name of one variant for apps that list both: "Sage Dark" and "Sage Light", or the plain name for single themes.
    func variantName(_ appearance: Appearance) -> String {
        alternate == nil ? name : "\(name) \(appearance == .dark ? "Dark" : "Light")"
    }

    /// Replaces the colors of the matching appearance (primary or alternate) with `variant`'s.
    mutating func update(_ variant: Theme) {
        if variant.appearance == appearance {
            apply(variant.primaryVariant)
        } else {
            alternate = variant.primaryVariant
        }
    }

    private mutating func apply(_ variant: ThemeVariant) {
        appearance = variant.appearance
        palette = variant.palette
        terminal = variant.terminal
        syntax = variant.syntax
        backdrop = variant.backdrop
        browser = variant.browser
    }
}

public struct Palette: Hashable, Sendable {
    /// Window chrome: title bars, tab bars, status bars.
    public var deep: HexColor
    /// Side panels.
    public var surface: HexColor
    /// Main content background (editor, terminal, page).
    public var base: HexColor
    /// Popovers, cards, inputs.
    public var elevated: HexColor
    public var hover: HexColor
    /// Raised highlight: your own messages, active rows.
    public var highlight: HexColor
    public var selection: HexColor
    public var border: HexColor
    public var borderSubtle: HexColor
    public var accent: HexColor
    public var accentSoft: HexColor
    public var accentDeep: HexColor
    public var accentDim: HexColor
    public var text: HexColor
    public var textMuted: HexColor
    public var textSubtle: HexColor
    public var textFaint: HexColor
    public var success: HexColor
    public var warning: HexColor
    public var error: HexColor
    public var info: HexColor
}

public struct TerminalPalette: Hashable, Sendable {
    /// The 16 ANSI colors: black, red, green, yellow, blue, magenta, cyan, white, then their bright variants.
    public var ansi: [HexColor]

    public static let names = ["Black", "Red", "Green", "Yellow", "Blue", "Magenta", "Cyan", "White"]
}

public struct SyntaxPalette: Hashable, Sendable {
    public var keyword: HexColor
    public var function: HexColor
    public var type: HexColor
    public var string: HexColor
    public var number: HexColor
    public var comment: HexColor
    public var property: HexColor
    public var variable: HexColor
    public var special: HexColor
    public var `operator`: HexColor
    public var punctuation: HexColor
}

/// Terminal and page background: base color with a glow rising from the bottom-right corner.
public struct Backdrop: Hashable, Sendable {
    public var glow: HexColor
    /// Glow intensity at the corner, 0...1.
    public var glowStrength: Double
    /// Grain standard deviation in 8-bit levels; 0 disables it.
    public var grain: Double
    /// Hue (degrees) that web themes rotate blue-grey palettes to.
    public var webHue: Double
}

/// Browser workspace gradient (Zen).
public struct BrowserStyle: Hashable, Sendable {
    public var colors: [HexColor]
    public var opacity: Double
    public var texture: Double
}

public struct WallpaperStyle: Hashable, Sendable {
    /// Iridescent stops for the logo, in order around the circle.
    public var holo: [HexColor]
    public var tagline: [String]
    public var ringText: String
    public var cornerTopLeft: String
    public var cornerBottomLeft: String
    public var cornerBottomRight: String
    /// Keys of `Theme.assets` holding SVG logos; nil shows the theme initials and name.
    public var monogram: String?
    public var wordmark: String?
}
