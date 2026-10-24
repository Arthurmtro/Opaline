import Foundation

/// An app the user added: a template rendered with theme tokens and written to a file.
public struct CustomTargetDefinition: Codable, Hashable, Identifiable, Sendable {
    public var id: String
    public var name: String
    /// App bundle for the icon and, with `quitsApp`, to close it during the write.
    public var appPath: String?
    public var quitsApp: Bool
    /// `~/...` path of the written file.
    public var outputPath: String
    /// File content with `{{token}}` placeholders, see `ThemeTokens.render`.
    public var template: String
    /// Optional shell command run after writing, to make the app reload.
    public var reloadCommand: String?

    public init(id: String = UUID().uuidString, name: String, appPath: String? = nil, quitsApp: Bool = false,
                outputPath: String, template: String, reloadCommand: String? = nil) {
        self.id = id
        self.name = name
        self.appPath = appPath
        self.quitsApp = quitsApp
        self.outputPath = outputPath
        self.template = template
        self.reloadCommand = reloadCommand
    }
}

public struct CustomTarget: ThemeTarget {
    public var definition: CustomTargetDefinition

    public init(definition: CustomTargetDefinition) {
        self.definition = definition
    }

    public var info: TargetInfo {
        let appURL = definition.appPath.map { URL(fileURLWithPath: $0) }
        return TargetInfo(
            id: "custom.\(definition.id)",
            name: definition.name,
            summary: "Writes \(definition.outputPath) from your template.",
            symbol: "puzzlepiece.extension",
            appURL: appURL,
            bundleIdentifier: appURL.flatMap { Bundle(url: $0)?.bundleIdentifier },
            quitsApp: definition.quitsApp,
            isCustom: true
        )
    }

    public func files(in context: TargetContext) -> [URL] { [context.environment.url(definition.outputPath)] }

    public func isInstalled(in context: TargetContext) -> Bool {
        definition.appPath.map { URL(fileURLWithPath: $0).exists } ?? true
    }

    public func changes(for theme: Theme, in context: TargetContext) async throws -> [FileChange] {
        [FileChange(url: context.environment.url(definition.outputPath), text: ThemeTokens.render(definition.template, theme: theme))]
    }

    public func didApply(_ theme: Theme, in context: TargetContext) async throws {
        guard let command = definition.reloadCommand, !command.isEmpty else { return }
        try await Shell.runCommand(command)
    }
}

/// Custom targets live in `<support>/targets/<id>.json`.
public struct CustomTargetStore: Sendable {
    public let environment: OpalineEnvironment

    public init(environment: OpalineEnvironment) {
        self.environment = environment
    }

    public var directory: URL {
        environment.supportDirectory.appending(path: "targets", directoryHint: .isDirectory)
    }

    public func load() throws -> [CustomTargetDefinition] {
        guard directory.exists else { return [] }
        return try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }
            .map { try JSONDecoder().decode(CustomTargetDefinition.self, from: Data(contentsOf: $0)) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    public func save(_ definition: CustomTargetDefinition) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        try encoder.encode(definition).write(to: directory.appending(path: "\(definition.id).json"), options: .atomic)
    }

    public func delete(_ definition: CustomTargetDefinition) throws {
        try FileManager.default.removeItem(at: directory.appending(path: "\(definition.id).json"))
    }
}

public enum BuiltInTargets {
    public static let all: [any ThemeTarget] = [
        GhosttyTarget(), CmuxTarget(), ClaudeCodeTarget(), ZedTarget(), ZenTarget(), GitHubTarget(), WallpaperTarget(),
    ]
}
