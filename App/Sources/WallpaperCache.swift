import AppKit
import Observation
import OpalineKit

/// Small wallpaper renders for previews and cards, one at a time so the app stays responsive.
@MainActor
@Observable
final class WallpaperCache {
    static let size = CGSize(width: 1600, height: 900)
    private static let limit = 16

    private(set) var images: [Theme: NSImage] = [:]
    private var order: [Theme] = []
    @ObservationIgnored private var queue: Task<Void, Never>?

    /// Renders the theme's wallpaper unless it is cached; waits for renders queued before it.
    func load(_ theme: Theme) async {
        guard images[theme] == nil else { return }
        let previous = queue
        let task = Task { [weak self] in
            await previous?.value
            guard let self, self.images[theme] == nil, !Task.isCancelled else { return }
            guard let png = try? await WallpaperRenderer.render(theme: theme, width: Int(Self.size.width), height: Int(Self.size.height)),
                  let image = NSImage(data: png) else { return }
            self.store(image, for: theme)
        }
        queue = task
        await task.value
    }

    private func store(_ image: NSImage, for theme: Theme) {
        images[theme] = image
        order.append(theme)
        while order.count > Self.limit {
            images[order.removeFirst()] = nil
        }
    }
}
