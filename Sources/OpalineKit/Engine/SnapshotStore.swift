import Foundation

/// What an apply changed, so it can be undone.
public struct Snapshot: Codable, Identifiable, Hashable, Sendable {
    public struct Entry: Codable, Hashable, Sendable {
        public var targetID: String
        public var path: String
        /// Copy of the original inside the snapshot folder; nil when the file did not exist.
        public var stored: String?
    }

    public var id: String
    public var date: Date
    public var themeID: String
    public var themeName: String
    public var targetIDs: [String]
    public var entries: [Entry]
    public var states: [String: [String: String]]
}

/// Snapshots live in `<support>/snapshots/<id>/` with a `manifest.json` and the original files.
public struct SnapshotStore: Sendable {
    public let environment: OpalineEnvironment

    public init(environment: OpalineEnvironment) {
        self.environment = environment
    }

    public var directory: URL {
        environment.supportDirectory.appending(path: "snapshots", directoryHint: .isDirectory)
    }

    public func folder(for snapshot: Snapshot) -> URL {
        directory.appending(path: snapshot.id, directoryHint: .isDirectory)
    }

    public func begin(theme: Theme, targetIDs: [String], date: Date = .now) throws -> Snapshot {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss-SSS"
        let snapshot = Snapshot(id: "\(formatter.string(from: date))-\(theme.id)", date: date, themeID: theme.id,
                                themeName: theme.name, targetIDs: targetIDs, entries: [], states: [:])
        try FileManager.default.createDirectory(at: folder(for: snapshot).appending(path: "files"), withIntermediateDirectories: true)
        return snapshot
    }

    /// Keeps the original of `url` the first time the snapshot sees it.
    public func preserve(_ url: URL, targetID: String, in snapshot: inout Snapshot) throws {
        let path = url.path(percentEncoded: false)
        guard !snapshot.entries.contains(where: { $0.path == path }) else { return }
        var stored: String?
        if url.exists {
            stored = "files/\(snapshot.entries.count)-\(url.lastPathComponent)"
            try FileManager.default.copyItem(at: url, to: folder(for: snapshot).appending(path: stored!))
        }
        snapshot.entries.append(.init(targetID: targetID, path: path, stored: stored))
    }

    public func save(_ snapshot: Snapshot) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(snapshot).write(to: folder(for: snapshot).appending(path: "manifest.json"), options: .atomic)
    }

    public func load() throws -> [Snapshot] {
        guard directory.exists else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .map { $0.appending(path: "manifest.json") }
            .filter(\.exists)
            .map { try decoder.decode(Snapshot.self, from: Data(contentsOf: $0)) }
            .sorted { $0.date > $1.date }
    }

    /// Puts every original file back and deletes the files the apply created.
    public func restoreFiles(of snapshot: Snapshot) throws {
        for entry in snapshot.entries {
            let url = URL(fileURLWithPath: entry.path)
            if url.exists { try FileManager.default.removeItem(at: url) }
            if let stored = entry.stored {
                try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                try FileManager.default.copyItem(at: folder(for: snapshot).appending(path: stored), to: url)
            }
        }
    }

    public func delete(_ snapshot: Snapshot) throws {
        try FileManager.default.removeItem(at: folder(for: snapshot))
    }
}

/// Which theme each target currently wears.
public struct AppliedState: Codable, Sendable, Equatable {
    public var themeByTarget: [String: String] = [:]
    public var dateByTarget: [String: Date] = [:]

    public init() {}

    static func url(in environment: OpalineEnvironment) -> URL {
        environment.supportDirectory.appending(path: "state.json")
    }

    public static func load(in environment: OpalineEnvironment) -> AppliedState {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode(AppliedState.self, from: Data(contentsOf: url(in: environment)))) ?? AppliedState()
    }

    public func save(in environment: OpalineEnvironment) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try FileManager.default.createDirectory(at: environment.supportDirectory, withIntermediateDirectories: true)
        try encoder.encode(self).write(to: Self.url(in: environment), options: .atomic)
    }
}
