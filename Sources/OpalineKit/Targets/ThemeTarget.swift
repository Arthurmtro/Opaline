import Foundation

/// A file a target wants to write.
public struct FileChange: Sendable {
    public var url: URL
    public var contents: Data

    public init(url: URL, contents: Data) {
        self.url = url
        self.contents = contents
    }

    public init(url: URL, text: String) {
        self.init(url: url, contents: Data(text.utf8))
    }
}

/// What the UI shows about a target.
public struct TargetInfo: Sendable, Hashable, Identifiable {
    public var id: String
    public var name: String
    public var summary: String
    /// SF Symbol used when the app has no icon.
    public var symbol: String
    /// App bundle used for the icon and, with `quitsApp`, for closing and reopening it.
    public var appURL: URL?
    public var bundleIdentifier: String?
    /// The app overwrites these files while running, so it is closed during the write and reopened after.
    public var quitsApp: Bool
    /// The app takes one variant at a time but reloads it live: Opaline rewrites it when the Mac switches appearance.
    public var followsAppearanceThroughOpaline: Bool
    public var isCustom: Bool

    public init(
        id: String, name: String, summary: String, symbol: String, appURL: URL? = nil,
        bundleIdentifier: String? = nil, quitsApp: Bool = false, followsAppearanceThroughOpaline: Bool = false, isCustom: Bool = false
    ) {
        self.id = id
        self.name = name
        self.summary = summary
        self.symbol = symbol
        self.appURL = appURL
        self.bundleIdentifier = bundleIdentifier
        self.quitsApp = quitsApp
        self.followsAppearanceThroughOpaline = followsAppearanceThroughOpaline
        self.isCustom = isCustom
    }
}

public struct TargetContext: Sendable {
    public var environment: OpalineEnvironment
    public var themes: ThemeStore
    /// The Mac's appearance, for targets that can't follow it themselves (`TargetInfo.followsAppearanceThroughOpaline`).
    public var appearance: Appearance

    public init(environment: OpalineEnvironment, appearance: Appearance = .system) {
        self.environment = environment
        self.themes = ThemeStore(environment: environment)
        self.appearance = appearance
    }

    func read(_ url: URL) -> String? {
        try? String(contentsOf: url, encoding: .utf8)
    }
}

public protocol ThemeTarget: Sendable {
    var info: TargetInfo { get }
    /// The paths the target writes, for display.
    func files(in context: TargetContext) -> [URL]
    func isInstalled(in context: TargetContext) -> Bool
    /// Files to write. Called right before writing, so it sees what earlier targets wrote.
    func changes(for theme: Theme, in context: TargetContext) async throws -> [FileChange]
    /// Runs after the files are written: reload a config, set the desktop picture...
    func didApply(_ theme: Theme, in context: TargetContext) async throws
    /// State outside files that a restore must put back (the desktop picture, for instance).
    func capturedState(in context: TargetContext) async -> [String: String]
    func restoreState(_ state: [String: String], in context: TargetContext) async throws
}

public extension ThemeTarget {
    func didApply(_ theme: Theme, in context: TargetContext) async throws {}
    func capturedState(in context: TargetContext) async -> [String: String] { [:] }
    func restoreState(_ state: [String: String], in context: TargetContext) async throws {}
}

public enum TargetError: LocalizedError {
    case missingFile(String)
    case invalidConfig(String)
    case unsupported(String)

    public var errorDescription: String? {
        switch self {
        case .missingFile(let path): "Missing file: \(path)"
        case .invalidConfig(let detail): "Invalid config: \(detail)"
        case .unsupported(let detail): detail
        }
    }
}
