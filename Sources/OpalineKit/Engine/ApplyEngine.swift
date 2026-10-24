import AppKit
import Foundation

public struct ApplyEvent: Sendable, Equatable {
    public enum Phase: Sendable, Equatable {
        case waiting
        case closingApp
        case writing
        case reloading
        case done
        case skipped(String)
        case failed(String)
    }

    public var targetID: String
    public var phase: Phase
}

/// Applies a theme to targets, one after the other, with a snapshot to undo it.
public struct ApplyEngine: Sendable {
    public let context: TargetContext
    let snapshots: SnapshotStore

    public init(environment: OpalineEnvironment, appearance: Appearance = .system) {
        context = TargetContext(environment: environment, appearance: appearance)
        snapshots = SnapshotStore(environment: environment)
    }

    public func apply(_ theme: Theme, to targets: [any ThemeTarget], progress: @escaping @Sendable (ApplyEvent) -> Void) async throws -> Snapshot {
        var snapshot = try snapshots.begin(theme: theme, targetIDs: targets.map(\.info.id))
        var state = AppliedState.load(in: context.environment)
        let closed = try await AppLifecycle.close(Self.appsToClose(targets)) { bundleID in
            for target in targets where target.info.bundleIdentifier == bundleID && target.info.quitsApp {
                progress(ApplyEvent(targetID: target.info.id, phase: .closingApp))
            }
        }

        for target in targets {
            let id = target.info.id
            progress(ApplyEvent(targetID: id, phase: .writing))
            do {
                let stateBefore = await target.capturedState(in: context)
                if !stateBefore.isEmpty { snapshot.states[id] = stateBefore }
                let changes = try await target.changes(for: theme, in: context)
                for change in changes {
                    try snapshots.preserve(change.url, targetID: id, in: &snapshot)
                }
                // The manifest is on disk before any write, so an interrupted apply can still be undone.
                try snapshots.save(snapshot)
                for change in changes {
                    try FileManager.default.createDirectory(at: change.url.deletingLastPathComponent(), withIntermediateDirectories: true)
                    try change.contents.write(to: change.url, options: .atomic)
                }
                state.themeByTarget[id] = theme.id
                state.dateByTarget[id] = .now
                try state.save(in: context.environment)
                progress(ApplyEvent(targetID: id, phase: .reloading))
                try await target.didApply(theme, in: context)
                progress(ApplyEvent(targetID: id, phase: .done))
            } catch TargetError.unsupported(let reason) {
                progress(ApplyEvent(targetID: id, phase: .skipped(reason)))
            } catch {
                progress(ApplyEvent(targetID: id, phase: .failed(error.localizedDescription)))
            }
        }

        try snapshots.save(snapshot)
        await AppLifecycle.reopen(closed)
        return snapshot
    }

    /// Rewrites the targets that follow the Mac through Opaline with the variant of `context.appearance`.
    /// They write the same files as at apply time, which the apply's snapshot already holds.
    public func followAppearance(_ themes: [Theme], targets: [any ThemeTarget]) async throws {
        let state = AppliedState.load(in: context.environment)
        for target in targets where target.info.followsAppearanceThroughOpaline {
            guard let theme = themes.first(where: { $0.id == state.themeByTarget[target.info.id] }), theme.alternate != nil else { continue }
            for change in try await target.changes(for: theme, in: context) {
                try change.contents.write(to: change.url, options: .atomic)
            }
        }
    }

    /// Restores a snapshot's files and captured state, closing the apps that need it.
    public func restore(_ snapshot: Snapshot, targets: [any ThemeTarget]) async throws {
        let involved = targets.filter { snapshot.targetIDs.contains($0.info.id) }
        let closed = try await AppLifecycle.close(Self.appsToClose(involved)) { _ in }
        try snapshots.restoreFiles(of: snapshot)
        for target in involved {
            if let state = snapshot.states[target.info.id] {
                try await target.restoreState(state, in: context)
            }
        }
        var state = AppliedState.load(in: context.environment)
        for id in snapshot.targetIDs {
            state.themeByTarget[id] = nil
        }
        try state.save(in: context.environment)
        await AppLifecycle.reopen(closed)
    }

    static func appsToClose(_ targets: [any ThemeTarget]) -> [String] {
        Array(Set(targets.filter(\.info.quitsApp).compactMap(\.info.bundleIdentifier))).sorted()
    }
}

/// Closes apps that rewrite their files on quit, and reopens them afterwards.
enum AppLifecycle {
    struct Closed: Sendable {
        var bundleIdentifier: String
        var url: URL
    }

    enum Failure: LocalizedError {
        case stillRunning(String)
        var errorDescription: String? {
            switch self {
            case .stillRunning(let name): "\(name) did not quit. Close it and try again."
            }
        }
    }

    @MainActor
    static func close(_ bundleIdentifiers: [String], notify: @Sendable (String) -> Void) async throws -> [Closed] {
        var closed: [Closed] = []
        for bundleID in bundleIdentifiers {
            let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            guard let app = running.first, let url = app.bundleURL else { continue }
            notify(bundleID)
            running.forEach { $0.terminate() }
            for _ in 0..<60 where !running.allSatisfy(\.isTerminated) {
                try await Task.sleep(for: .milliseconds(250))
            }
            guard running.allSatisfy(\.isTerminated) else { throw Failure.stillRunning(app.localizedName ?? bundleID) }
            closed.append(Closed(bundleIdentifier: bundleID, url: url))
        }
        return closed
    }

    @MainActor
    static func reopen(_ apps: [Closed]) async {
        for app in apps {
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = false
            _ = try? await NSWorkspace.shared.openApplication(at: app.url, configuration: configuration)
        }
    }
}
