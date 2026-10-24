import Foundation

/// Reads and writes `Theme` as an Opaline theme file. Missing roles are derived on read; writing is always complete.
extension Theme: Codable {
    public static let format = "opaline-theme"
    public static let formatVersion = 1
    public static let schemaURL = "https://raw.githubusercontent.com/Arthurmtro/Opaline/main/schema/theme.schema.json"

    public init(from decoder: Decoder) throws {
        let root = try decoder.container(keyedBy: AnyKey.self)
        if let format = try root.decodeIfPresent(String.self, forKey: AnyKey("format")), format != Self.format {
            throw DecodingError.dataCorruptedError(forKey: AnyKey("format"), in: root, debugDescription: "expected \"\(Self.format)\", found \"\(format)\"")
        }
        let name = try root.decode(String.self, forKey: AnyKey("name"))
        let appearance = try root.decodeIfPresent(Appearance.self, forKey: AnyKey("appearance")) ?? .dark
        let primary = try ThemeVariant(decoding: root, appearance: appearance)

        var wallpaper = WallpaperStyle.derived(name: name)
        if let section = try root.optionalNested("wallpaper") {
            try section.overlay(&wallpaper, [("holo", \WallpaperStyle.holo)])
            try section.overlay(&wallpaper, [("tagline", \WallpaperStyle.tagline)])
            try section.overlay(&wallpaper, WallpaperStyle.textFields)
            wallpaper.monogram = try section.decodeIfPresent(String.self, forKey: AnyKey("monogram"))
            wallpaper.wordmark = try section.decodeIfPresent(String.self, forKey: AnyKey("wordmark"))
        }

        self.init(
            id: try root.decodeIfPresent(String.self, forKey: AnyKey("id")) ?? ThemeStore.slug(name),
            name: name,
            author: try root.decodeIfPresent(String.self, forKey: AnyKey("author")) ?? "",
            appearance: appearance,
            palette: primary.palette,
            terminal: primary.terminal,
            syntax: primary.syntax,
            backdrop: primary.backdrop,
            browser: primary.browser,
            wallpaper: wallpaper,
            assets: try root.decodeIfPresent([String: String].self, forKey: AnyKey("assets")) ?? [:],
            alternate: try root.optionalNested("alternate").map { try ThemeVariant(decoding: $0, appearance: appearance.opposite) }
        )
    }

    public func encode(to encoder: Encoder) throws {
        var root = encoder.container(keyedBy: AnyKey.self)
        try root.encode(Self.schemaURL, forKey: AnyKey("$schema"))
        try root.encode(Self.format, forKey: AnyKey("format"))
        try root.encode(Self.formatVersion, forKey: AnyKey("version"))
        try root.encode(id, forKey: AnyKey("id"))
        try root.encode(name, forKey: AnyKey("name"))
        try root.encode(author, forKey: AnyKey("author"))
        try root.encode(appearance, forKey: AnyKey("appearance"))
        try primaryVariant.encode(into: &root)

        var wallpaperSection = root.nestedContainer(keyedBy: AnyKey.self, forKey: AnyKey("wallpaper"))
        try wallpaperSection.encode(wallpaper.holo, forKey: AnyKey("holo"))
        try wallpaperSection.encode(wallpaper.tagline, forKey: AnyKey("tagline"))
        try wallpaperSection.write(wallpaper, WallpaperStyle.textFields)
        try wallpaperSection.encodeIfPresent(wallpaper.monogram, forKey: AnyKey("monogram"))
        try wallpaperSection.encodeIfPresent(wallpaper.wordmark, forKey: AnyKey("wordmark"))

        if let alternate {
            var section = root.nestedContainer(keyedBy: AnyKey.self, forKey: AnyKey("alternate"))
            try alternate.encode(into: &section)
        }
        if !assets.isEmpty {
            try root.encode(assets, forKey: AnyKey("assets"))
        }
    }
}

/// The color sections shared by a theme's root and its `alternate`.
extension ThemeVariant {
    init(decoding container: KeyedDecodingContainer<AnyKey>, appearance: Appearance) throws {
        let colors = try container.nestedContainer(keyedBy: AnyKey.self, forKey: AnyKey("palette"))
        var variant = ThemeVariant.derived(
            base: try colors.decode(HexColor.self, forKey: AnyKey("base")),
            text: try colors.decode(HexColor.self, forKey: AnyKey("text")),
            accent: try colors.decode(HexColor.self, forKey: AnyKey("accent")),
            appearance: appearance
        )
        try colors.overlay(&variant.palette, Palette.fields)
        variant.terminal = TerminalPalette.derived(from: variant.palette, appearance: appearance)
        if let ansi = try container.optionalNested("terminal")?.decodeIfPresent([HexColor].self, forKey: AnyKey("ansi")) {
            guard ansi.count == 16 else {
                throw DecodingError.dataCorrupted(.init(codingPath: container.codingPath + [AnyKey("terminal"), AnyKey("ansi")],
                                                        debugDescription: "needs exactly 16 colors, found \(ansi.count)"))
            }
            variant.terminal.ansi = ansi
        }
        variant.syntax = SyntaxPalette.derived(from: variant.palette, terminal: variant.terminal)
        try container.optionalNested("syntax")?.overlay(&variant.syntax, SyntaxPalette.fields)
        variant.backdrop = Backdrop.derived(from: variant.palette, appearance: appearance)
        if let section = try container.optionalNested("backdrop") {
            try section.overlay(&variant.backdrop, [("glow", \Backdrop.glow)])
            try section.overlay(&variant.backdrop, [("glowStrength", \Backdrop.glowStrength), ("grain", \Backdrop.grain), ("webHue", \Backdrop.webHue)])
        }
        variant.browser = BrowserStyle.derived(from: variant.palette)
        if let section = try container.optionalNested("browser") {
            try section.overlay(&variant.browser, [("colors", \BrowserStyle.colors)])
            try section.overlay(&variant.browser, [("opacity", \BrowserStyle.opacity), ("texture", \BrowserStyle.texture)])
        }
        self = variant
    }

    func encode(into container: inout KeyedEncodingContainer<AnyKey>) throws {
        var colors = container.nestedContainer(keyedBy: AnyKey.self, forKey: AnyKey("palette"))
        try colors.write(palette, Palette.fields)
        var terminalSection = container.nestedContainer(keyedBy: AnyKey.self, forKey: AnyKey("terminal"))
        try terminalSection.encode(terminal.ansi, forKey: AnyKey("ansi"))
        var syntaxSection = container.nestedContainer(keyedBy: AnyKey.self, forKey: AnyKey("syntax"))
        try syntaxSection.write(syntax, SyntaxPalette.fields)
        var backdropSection = container.nestedContainer(keyedBy: AnyKey.self, forKey: AnyKey("backdrop"))
        try backdropSection.encode(backdrop.glow, forKey: AnyKey("glow"))
        try backdropSection.write(backdrop, [("glowStrength", \Backdrop.glowStrength), ("grain", \Backdrop.grain), ("webHue", \Backdrop.webHue)])
        var browserSection = container.nestedContainer(keyedBy: AnyKey.self, forKey: AnyKey("browser"))
        try browserSection.encode(browser.colors, forKey: AnyKey("colors"))
        try browserSection.write(browser, [("opacity", \BrowserStyle.opacity), ("texture", \BrowserStyle.texture)])
    }
}

extension Palette {
    /// JSON key and property of every role, in documentation order.
    public static var fields: [(String, WritableKeyPath<Palette, HexColor>)] { [
        ("base", \.base), ("text", \.text), ("accent", \.accent),
        ("deep", \.deep), ("surface", \.surface), ("elevated", \.elevated), ("hover", \.hover),
        ("highlight", \.highlight), ("selection", \.selection), ("border", \.border), ("borderSubtle", \.borderSubtle),
        ("accentSoft", \.accentSoft), ("accentDeep", \.accentDeep), ("accentDim", \.accentDim),
        ("textMuted", \.textMuted), ("textSubtle", \.textSubtle), ("textFaint", \.textFaint),
        ("success", \.success), ("warning", \.warning), ("error", \.error), ("info", \.info),
    ] }
}

extension SyntaxPalette {
    public static var fields: [(String, WritableKeyPath<SyntaxPalette, HexColor>)] { [
        ("keyword", \.keyword), ("function", \.function), ("type", \.type), ("string", \.string), ("number", \.number),
        ("comment", \.comment), ("property", \.property), ("variable", \.variable), ("special", \.special),
        ("operator", \.operator), ("punctuation", \.punctuation),
    ] }
}

extension WallpaperStyle {
    static var textFields: [(String, WritableKeyPath<WallpaperStyle, String>)] { [
        ("ringText", \.ringText), ("cornerTopLeft", \.cornerTopLeft),
        ("cornerBottomLeft", \.cornerBottomLeft), ("cornerBottomRight", \.cornerBottomRight),
    ] }
}

struct AnyKey: CodingKey {
    var stringValue: String
    var intValue: Int? { nil }

    init(_ string: String) { stringValue = string }
    init?(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { nil }
}

private extension KeyedDecodingContainer where Key == AnyKey {
    func optionalNested(_ key: String) throws -> KeyedDecodingContainer<AnyKey>? {
        contains(AnyKey(key)) ? try nestedContainer(keyedBy: AnyKey.self, forKey: AnyKey(key)) : nil
    }

    /// Replaces each property whose key is present in the container.
    func overlay<Root, Value: Decodable>(_ value: inout Root, _ fields: [(String, WritableKeyPath<Root, Value>)]) throws {
        for (key, path) in fields {
            if let decoded = try decodeIfPresent(Value.self, forKey: AnyKey(key)) {
                value[keyPath: path] = decoded
            }
        }
    }
}

private extension KeyedEncodingContainer where Key == AnyKey {
    mutating func write<Root, Value: Encodable>(_ value: Root, _ fields: [(String, WritableKeyPath<Root, Value>)]) throws {
        for (key, path) in fields {
            try encode(value[keyPath: path], forKey: AnyKey(key))
        }
    }
}

/// Theme files: the exchange format for import, export and the built-in themes.
public enum ThemeFile {
    public struct ImportError: LocalizedError, Equatable {
        public var message: String
        public var errorDescription: String? { message }
    }

    public static func encode(_ theme: Theme) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
        return try encoder.encode(theme)
    }

    /// Accepts a theme file, or text that contains one (a chat answer with a ```json fence, for instance).
    public static func decode(_ data: Data) throws -> Theme {
        let text = String(decoding: data, as: UTF8.self)
        guard let start = text.firstIndex(of: "{"), let end = text.lastIndex(of: "}") else {
            throw ImportError(message: "No theme found: the text has no JSON object.")
        }
        do {
            return try JSONDecoder().decode(Theme.self, from: Data(text[start...end].utf8))
        } catch let error as DecodingError {
            throw ImportError(message: describe(error))
        }
    }

    static func describe(_ error: DecodingError) -> String {
        func path(_ codingPath: [CodingKey]) -> String {
            let joined = codingPath.map { $0.intValue.map { "[\($0)]" } ?? ".\($0.stringValue)" }.joined()
            return joined.isEmpty ? "the file" : String(joined.trimmingPrefix("."))
        }
        switch error {
        case .keyNotFound(let key, let context):
            return "\(path(context.codingPath + [key])) is missing."
        case .typeMismatch(_, let context), .valueNotFound(_, let context):
            return "\(path(context.codingPath)) has the wrong type: \(context.debugDescription)"
        case .dataCorrupted(let context):
            return context.codingPath.isEmpty ? "The file is not valid JSON." : "\(path(context.codingPath)): \(context.debugDescription)"
        @unknown default:
            return error.localizedDescription
        }
    }
}
