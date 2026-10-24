import Foundation
import Testing
@testable import OpalineKit

@MainActor
struct RenderingTests {
    @Test func rendersAThemeWithoutLogo() async throws {
        let html = try WallpaperRenderer.html(for: try Fixtures.catppuccin())
        #expect(html.contains(#"<div class="initials">CM</div>"#))
        #expect(html.contains(#"<div class="title">CATPPUCCIN MOCHA</div>"#))
        #expect(!html.contains("{{"))
    }
}
