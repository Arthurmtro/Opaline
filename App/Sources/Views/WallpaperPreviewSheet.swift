import SwiftUI
import OpalineKit

/// Renders the theme's wallpaper at the main screen's size, without applying it.
struct WallpaperPreviewSheet: View {
    @Environment(\.dismiss) private var dismiss
    let theme: Theme
    @State private var image: NSImage?
    @State private var error: String?

    private var screenSize: CGSize {
        let screen = NSScreen.main ?? NSScreen.screens[0]
        return CGSize(width: screen.frame.width * screen.backingScaleFactor, height: screen.frame.height * screen.backingScaleFactor)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(theme.name) wallpaper").font(.system(size: 20, weight: .bold, design: .rounded))
                    Text("Rendered at \(Int(screenSize.width)) × \(Int(screenSize.height)), your main screen. Apply sets one per screen.")
                        .font(.system(size: 12)).foregroundStyle(Color.primary.opacity(0.6))
                }
                Spacer()
                Button("Close") { dismiss() }
                    .buttonStyle(PillButtonStyle())
                    .keyboardShortcut(.cancelAction)
            }
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.black.opacity(0.35))
                if let image {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .padding(8)
                        .transition(.opacity)
                } else if let error {
                    Text(error).foregroundStyle(theme.palette.error.color)
                } else {
                    ProgressView("Rendering…").controlSize(.large)
                }
            }
            .frame(width: 980, height: 980 * screenSize.height / screenSize.width + 16)
        }
        .padding(28)
        .background(ThemeBackdrop(theme: theme))
        .preferredColorScheme(theme.colorScheme)
        .task {
            do {
                let png = try await WallpaperRenderer.render(theme: theme, width: Int(screenSize.width), height: Int(screenSize.height))
                withAnimation { image = NSImage(data: png) }
            } catch {
                self.error = error.localizedDescription
            }
        }
    }
}
