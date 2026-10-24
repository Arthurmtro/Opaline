import Foundation

/// The themes the app shows: the ones shipped in the app, and the user's, which win when they share an id.
public struct ThemeLibrary: Sendable {
    public var themes: [Theme]
    /// Ids of themes shipped in the app (`Resources/Themes/defaults` and the builder's own `custom`).
    public var builtInIDs: Set<String>
    /// Ids saved by the user, including their edits of built-in themes.
    public var userIDs: Set<String>

    public static let empty = ThemeLibrary(themes: [], builtInIDs: [], userIDs: [])

    /// A built-in theme the user has not changed: it can't be deleted.
    public func isPristineBuiltIn(_ theme: Theme) -> Bool {
        builtInIDs.contains(theme.id) && !userIDs.contains(theme.id)
    }

    /// A built-in theme the user edited: deleting their copy brings the original back.
    public func isModifiedBuiltIn(_ theme: Theme) -> Bool {
        builtInIDs.contains(theme.id) && userIDs.contains(theme.id)
    }
}

/// User themes live in `<support>/themes/<id>.json`, in the same format as exported files.
/// Built-in themes are read from the app bundle on every launch, so they update with the app.
public struct ThemeStore: Sendable {
    public let environment: OpalineEnvironment

    public init(environment: OpalineEnvironment) {
        self.environment = environment
    }

    public var directory: URL {
        environment.supportDirectory.appending(path: "themes", directoryHint: .isDirectory)
    }

    public func file(for theme: Theme) -> URL {
        directory.appending(path: "\(theme.id).json")
    }

    public func load() throws -> ThemeLibrary {
        let bundled = try ["defaults", "custom"].flatMap { try Self.themes(in: KitResources.url("Themes/\($0)")) }
        let user = try Self.themes(in: directory)
        let userIDs = Set(user.map(\.id))
        let merged = bundled.filter { !userIDs.contains($0.id) } + user
        return ThemeLibrary(
            themes: merged.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending },
            builtInIDs: Set(bundled.map(\.id)),
            userIDs: userIDs
        )
    }

    private static func themes(in folder: URL) throws -> [Theme] {
        guard folder.exists else { return [] }
        return try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }
            .map { try ThemeFile.decode(Data(contentsOf: $0)) }
    }

    public func save(_ theme: Theme) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try ThemeFile.encode(theme).write(to: file(for: theme), options: .atomic)
    }

    /// Adds a theme read from a file or the clipboard. A theme with the same id is kept and the new one gets a free id.
    @discardableResult
    public func add(_ theme: Theme, existing: [Theme]) throws -> Theme {
        var added = theme
        if existing.contains(where: { $0.id == theme.id }) {
            added.id = Self.uniqueID(for: theme.id, existing: existing)
            if existing.contains(where: { $0.name == theme.name }) { added.name = "\(theme.name) 2" }
        }
        try save(added)
        return added
    }

    public func duplicate(_ theme: Theme, named name: String, existing: [Theme]) throws -> Theme {
        var copy = theme
        copy.name = name
        copy.id = Self.uniqueID(for: name, existing: existing)
        try save(copy)
        return copy
    }

    public func delete(_ theme: Theme) throws {
        try FileManager.default.removeItem(at: file(for: theme))
    }

    public static func slug(_ name: String) -> String {
        let slug = name.lowercased()
            .folding(options: .diacriticInsensitive, locale: nil)
            .map { $0.isLetter || $0.isNumber ? String($0) : "-" }
            .joined()
            .split(separator: "-")
            .joined(separator: "-")
        return slug.isEmpty ? "theme" : slug
    }

    public static func uniqueID(for name: String, existing: [Theme]) -> String {
        let base = slug(name)
        let taken = Set(existing.map(\.id))
        var candidate = base
        var counter = 2
        while taken.contains(candidate) {
            candidate = "\(base)-\(counter)"
            counter += 1
        }
        return candidate
    }
}
