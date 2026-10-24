import Foundation

/// Values for every role a theme file leaves out, derived from its base, text and accent colors.
extension ThemeVariant {
    static func derived(base: HexColor, text: HexColor, accent: HexColor, appearance: Appearance) -> ThemeVariant {
        let palette = Palette.derived(base: base, text: text, accent: accent, appearance: appearance)
        let terminal = TerminalPalette.derived(from: palette, appearance: appearance)
        return ThemeVariant(
            appearance: appearance,
            palette: palette,
            terminal: terminal,
            syntax: SyntaxPalette.derived(from: palette, terminal: terminal),
            backdrop: Backdrop.derived(from: palette, appearance: appearance),
            browser: BrowserStyle.derived(from: palette)
        )
    }

    /// A starting point for the opposite appearance: base and text swap roles, the accent is adjusted to keep contrast.
    public static func opposite(of theme: Theme) -> ThemeVariant {
        let p = theme.palette
        let appearance = theme.appearance.opposite
        let base = appearance == .light
            ? p.text.mixed(with: HexColor(red: 1, green: 1, blue: 1), 0.35)
            : p.text.mixed(with: HexColor(red: 0, green: 0, blue: 0), 0.25)
        let text = appearance == .light ? p.deep : p.base
        let accent = p.accent.mixed(with: text, appearance == .light ? 0.35 : 0.2)
        return derived(base: base, text: text, accent: accent, appearance: appearance)
    }
}

extension Palette {
    static func derived(base: HexColor, text: HexColor, accent: HexColor, appearance: Appearance) -> Palette {
        let black = HexColor(red: 0, green: 0, blue: 0)
        let deep = appearance == .dark ? base.mixed(with: black, 0.25) : base.mixed(with: text, 0.04)
        let status = StatusColors.defaults(appearance)
        return Palette(
            deep: deep,
            surface: base.mixed(with: deep, 0.5),
            base: base,
            elevated: base.mixed(with: text, 0.06),
            hover: base.mixed(with: text, 0.1),
            highlight: base.mixed(with: accent, 0.15),
            selection: base.mixed(with: accent, 0.28),
            border: base.mixed(with: text, 0.13),
            borderSubtle: base.mixed(with: text, 0.08),
            accent: accent,
            accentSoft: accent.mixed(with: text, 0.35),
            accentDeep: accent.mixed(with: base, 0.4),
            accentDim: accent.mixed(with: base, 0.6),
            text: text,
            textMuted: text.mixed(with: base, 0.42),
            textSubtle: text.mixed(with: base, 0.6),
            textFaint: text.mixed(with: base, 0.72),
            success: status.success,
            warning: status.warning,
            error: status.error,
            info: status.info
        )
    }
}

struct StatusColors {
    var success, warning, error, info, blue, magenta, cyan: HexColor

    static func defaults(_ appearance: Appearance) -> StatusColors {
        switch appearance {
        case .dark:
            StatusColors(success: HexColor("#88CF94")!, warning: HexColor("#E3C07D")!, error: HexColor("#E07A72")!,
                         info: HexColor("#7CC6BE")!, blue: HexColor("#7FA8D9")!, magenta: HexColor("#C49ADB")!, cyan: HexColor("#7CC6BE")!)
        case .light:
            StatusColors(success: HexColor("#1A7F37")!, warning: HexColor("#9A6700")!, error: HexColor("#CF222E")!,
                         info: HexColor("#1B7C83")!, blue: HexColor("#0969DA")!, magenta: HexColor("#8250DF")!, cyan: HexColor("#1B7C83")!)
        }
    }
}

extension TerminalPalette {
    static func derived(from palette: Palette, appearance: Appearance) -> TerminalPalette {
        let status = StatusColors.defaults(appearance)
        let black = appearance == .dark ? palette.base.mixed(with: palette.text, 0.12) : palette.text
        let white = appearance == .dark ? palette.text.mixed(with: palette.base, 0.12) : palette.base.mixed(with: palette.text, 0.25)
        let normal = [black, palette.error, palette.success, palette.warning, status.blue, status.magenta, status.cyan, white]
        let towards = appearance == .dark ? HexColor(red: 1, green: 1, blue: 1) : HexColor(red: 0, green: 0, blue: 0)
        let bright = normal.enumerated().map { index, color in
            index == 0 ? palette.textMuted : color.mixed(with: towards, 0.22)
        }
        return TerminalPalette(ansi: normal + bright)
    }
}

extension SyntaxPalette {
    static func derived(from palette: Palette, terminal: TerminalPalette) -> SyntaxPalette {
        SyntaxPalette(
            keyword: palette.accent,
            function: terminal.ansi[6],
            type: palette.warning,
            string: palette.success,
            number: palette.error.mixed(with: palette.warning, 0.3),
            comment: palette.textSubtle,
            property: palette.text.mixed(with: palette.textMuted, 0.5),
            variable: palette.text,
            special: terminal.ansi[5],
            operator: palette.accentSoft,
            punctuation: palette.textMuted
        )
    }
}

extension Backdrop {
    static func derived(from palette: Palette, appearance: Appearance) -> Backdrop {
        Backdrop(glow: palette.accent, glowStrength: appearance == .dark ? 0.2 : 0.12, grain: 2.5, webHue: palette.accent.hsl.hue)
    }
}

extension BrowserStyle {
    static func derived(from palette: Palette) -> BrowserStyle {
        BrowserStyle(colors: [palette.base, palette.base.mixed(with: palette.accent, 0.35)], opacity: 0.8, texture: 0.125)
    }
}

extension WallpaperStyle {
    /// Opaline's iridescent stops: mint, lime, apricot, rose, lilac, sky.
    public static let opalineHolo = ["#88CF94", "#C9E66B", "#F2C46D", "#F29BB0", "#B9A3F0", "#7CC6E8"].compactMap(HexColor.init)

    static func derived(name: String) -> WallpaperStyle {
        WallpaperStyle(holo: opalineHolo, tagline: [], ringText: name.uppercased(), cornerTopLeft: "",
                       cornerBottomLeft: "", cornerBottomRight: "", monogram: nil, wordmark: nil)
    }
}
