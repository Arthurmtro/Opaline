import AppKit
import Foundation
import WebKit

/// Renders the wallpaper template with a theme, through an offscreen WKWebView.
@MainActor
public enum WallpaperRenderer {
    public static func html(for theme: Theme) throws -> String {
        let p = theme.palette
        let style = theme.wallpaper
        func rgb(_ color: HexColor) -> String {
            let bytes = color.rgbBytes
            return "\(bytes.red), \(bytes.green), \(bytes.blue)"
        }
        func mask(_ file: String?) -> String? {
            guard let file, var svg = theme.assets[file] else { return nil }
            svg = svg.replacingOccurrences(of: "<svg ", with: "<svg fill=\"white\" ")
            return "url(data:image/svg+xml;base64,\(Data(svg.utf8).base64EncodedString())) center / contain no-repeat"
        }
        let monogram = mask(style.monogram)
        let wordmark = mask(style.wordmark)
        let initials = theme.name.split(separator: " ").prefix(2).compactMap(\.first).map(String.init).joined()
        let ringMask = "url(\"data:image/svg+xml;base64,\(Data(#"<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48"><circle cx="24" cy="24" r="22" fill="none" stroke="white" stroke-width="2.6"/></svg>"#.utf8).base64EncodedString())\") center / contain no-repeat"

        let mark = monogram == nil
            ? #"<div class="mark"><div class="holo"></div><div class="sheen"></div><div class="initials">\#(escape(initials))</div></div>"#
            : #"<div class="mark"><div class="holo"></div><div class="sheen"></div></div>"#
        let title = wordmark == nil ? #"<div class="title">\#(escape(theme.name.uppercased()))</div>"# : #"<div class="wordmark"></div>"#
        let tagline = style.tagline.map(escape).joined(separator: " <b>·</b> ")
        let ringUnit = String(decoding: try JSONEncoder().encode("\(style.ringText)\u{00A0}\u{00A0}•\u{00A0}\u{00A0}"), as: UTF8.self)

        let values: [String: String] = [
            "deep": p.deep.opaqueHex, "text": p.text.opaqueHex, "textMuted": p.textMuted.opaqueHex, "accent": p.accent.opaqueHex,
            "holo": (style.holo + style.holo.prefix(1)).map(\.opaqueHex).joined(separator: ", "),
            "glowRGB": rgb(theme.backdrop.glow), "accentRGB": rgb(p.accent), "accentSoftRGB": rgb(p.accentSoft),
            "textRGB": rgb(p.text), "textMutedRGB": rgb(p.textMuted),
            "baseLift": p.base.mixed(with: p.text, 0.015).opaqueHex,
            "deeper": p.deep.mixed(with: HexColor(red: 0, green: 0, blue: 0), 0.3).opaqueHex,
            "monogramMask": monogram ?? ringMask,
            "wordmarkMask": wordmark ?? "none",
            "wordmarkRatio": wordmarkRatio(style.wordmark.flatMap { theme.assets[$0] }),
            "mark": mark, "title": title, "tagline": tagline, "ringUnit": ringUnit,
            "corners": [("tl", style.cornerTopLeft), ("bl", style.cornerBottomLeft), ("br", style.cornerBottomRight)]
                .filter { !$0.1.isEmpty }
                .map { #"<div class="corner \#($0.0)">\#(escape($0.1))</div>"# }
                .joined(separator: "\n  "),
        ]
        return values.reduce(try KitResources.text("wallpaper.html")) { $0.replacingOccurrences(of: "{{\($1.key)}}", with: $1.value) }
    }

    public static func render(theme: Theme, width: Int, height: Int) async throws -> Data {
        let size = CGSize(width: width, height: height)
        let webView = WKWebView(frame: CGRect(origin: .zero, size: size))
        let window = RenderWindow(contentRect: CGRect(origin: CGPoint(x: -30_000, y: -30_000), size: size), styleMask: .borderless, backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = webView
        window.orderBack(nil)
        defer {
            window.contentView = nil
            window.close()
        }

        let loader = NavigationWaiter()
        webView.navigationDelegate = loader
        webView.loadHTMLString(try html(for: theme), baseURL: nil)
        try await loader.wait()
        // Hidden windows get no animation frames, so give layout and the ring script a fixed moment instead.
        try await Task.sleep(for: .milliseconds(400))

        let configuration = WKSnapshotConfiguration()
        configuration.rect = CGRect(origin: .zero, size: size)
        configuration.afterScreenUpdates = false
        let image = try await webView.takeSnapshot(configuration: configuration)
        return try png(image, width: width, height: height)
    }

    private static func png(_ image: NSImage, width: Int, height: Int) throws -> Data {
        guard let source = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
              let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
        else { throw TargetError.unsupported("Could not render the wallpaper") }
        context.interpolationQuality = .high
        context.draw(source, in: CGRect(x: 0, y: 0, width: width, height: height))
        return BackdropRenderer.png(context.makeImage()!)
    }

    private static func wordmarkRatio(_ svg: String?) -> String {
        guard let svg,
              let box = svg.firstMatch(of: /viewBox="([\d.\s-]+)"/) else { return "1" }
        let parts = box.1.split(separator: " ").compactMap { Double($0) }
        return parts.count == 4 ? String(format: "%.4f", parts[2] / parts[3]) : "1"
    }

    private static func escape(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;")
    }
}

/// An offscreen window that keeps the size it is given, even when larger than any screen.
private final class RenderWindow: NSWindow {
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect { frameRect }
}

@MainActor
private final class NavigationWaiter: NSObject, WKNavigationDelegate {
    private var continuation: CheckedContinuation<Void, Error>?

    func wait() async throws {
        try await withCheckedThrowingContinuation { self.continuation = $0 }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        continuation?.resume()
        continuation = nil
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        continuation?.resume(throwing: error)
        continuation = nil
    }
}
