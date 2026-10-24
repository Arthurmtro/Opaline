import AppKit
import Foundation

/// A wallpaper rendered for each screen's exact size, set as the desktop picture.
public struct WallpaperTarget: ThemeTarget {
    public init() {}

    public var info: TargetInfo {
        TargetInfo(
            id: "wallpaper",
            name: "Wallpaper",
            summary: "A wallpaper drawn from the theme, rendered for each screen.",
            symbol: "photo.on.rectangle.angled"
        )
    }

    private func directory(_ context: TargetContext) -> URL {
        context.environment.supportDirectory.appending(path: "wallpapers", directoryHint: .isDirectory)
    }

    /// A HEIC with both images when the theme has two appearances, so macOS switches it with the system.
    private func file(_ theme: Theme, size: CGSize, _ context: TargetContext) -> URL {
        directory(context).appending(path: "\(theme.id)-\(Int(size.width))x\(Int(size.height)).\(theme.alternate == nil ? "png" : "heic")")
    }

    public func files(in context: TargetContext) -> [URL] { [directory(context)] }

    public func isInstalled(in context: TargetContext) -> Bool { true }

    public func changes(for theme: Theme, in context: TargetContext) async throws -> [FileChange] {
        var changes: [FileChange] = []
        var rendered: Set<String> = []
        for size in await Self.screenSizes() where rendered.insert("\(size.width)x\(size.height)").inserted {
            let width = Int(size.width), height = Int(size.height)
            let image = theme.alternate == nil
                ? try await WallpaperRenderer.render(theme: theme, width: width, height: height)
                : try DynamicWallpaper.heic(
                    light: try await WallpaperRenderer.render(theme: theme.variant(.light), width: width, height: height),
                    dark: try await WallpaperRenderer.render(theme: theme.variant(.dark), width: width, height: height)
                )
            changes.append(FileChange(url: file(theme, size: size, context), contents: image))
        }
        return changes
    }

    public func didApply(_ theme: Theme, in context: TargetContext) async throws {
        try await MainActor.run {
            for screen in NSScreen.screens {
                try NSWorkspace.shared.setDesktopImageURL(file(theme, size: screen.pixelSize, context), for: screen, options: [:])
            }
        }
    }

    public func capturedState(in context: TargetContext) async -> [String: String] {
        await MainActor.run {
            Dictionary(NSScreen.screens.compactMap { screen in
                NSWorkspace.shared.desktopImageURL(for: screen).map { (screen.localizedName, $0.path(percentEncoded: false)) }
            }, uniquingKeysWith: { first, _ in first })
        }
    }

    public func restoreState(_ state: [String: String], in context: TargetContext) async throws {
        try await MainActor.run {
            for screen in NSScreen.screens {
                guard let path = state[screen.localizedName] else { continue }
                try NSWorkspace.shared.setDesktopImageURL(URL(fileURLWithPath: path), for: screen, options: [:])
            }
        }
    }

    @MainActor
    static func screenSizes() -> [CGSize] {
        NSScreen.screens.map(\.pixelSize)
    }
}

extension NSScreen {
    var pixelSize: CGSize {
        CGSize(width: (frame.width * backingScaleFactor).rounded(), height: (frame.height * backingScaleFactor).rounded())
    }
}
