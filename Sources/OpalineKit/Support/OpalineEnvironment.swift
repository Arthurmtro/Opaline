import Foundation

/// Where Opaline reads and writes. Tests point `home` at a temporary folder.
public struct OpalineEnvironment: Sendable {
    public var home: URL
    public var supportDirectory: URL
    public var applicationsDirectory: URL

    public init(home: URL, supportDirectory: URL, applicationsDirectory: URL = URL(fileURLWithPath: "/Applications")) {
        self.home = home
        self.supportDirectory = supportDirectory
        self.applicationsDirectory = applicationsDirectory
    }

    public static var current: OpalineEnvironment {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return OpalineEnvironment(
            home: home,
            supportDirectory: home.appending(path: "Library/Application Support/Opaline", directoryHint: .isDirectory)
        )
    }

    /// Resolves `~/...` and home-relative paths.
    public func url(_ path: String) -> URL {
        if path.hasPrefix("~/") { return home.appending(path: String(path.dropFirst(2))) }
        if path.hasPrefix("/") { return URL(fileURLWithPath: path) }
        return home.appending(path: path)
    }

    /// Displays a URL with `~` for the home folder.
    public func display(_ url: URL) -> String {
        let path = url.path(percentEncoded: false)
        let homePath = home.path(percentEncoded: false)
        return path.hasPrefix(homePath) ? "~/" + path.dropFirst(homePath.count).trimmingPrefix("/") : path
    }

    public func application(_ name: String) -> URL {
        applicationsDirectory.appending(path: "\(name).app", directoryHint: .isDirectory)
    }
}

extension URL {
    var exists: Bool { FileManager.default.fileExists(atPath: path(percentEncoded: false)) }
}
