// Renders the Opaline app icon set. Usage: swift Scripts/make-icon.swift App/Resources/Assets.xcassets/AppIcon.appiconset
import AppKit
import SwiftUI

let holo = [Color(hex: 0x88CF94), Color(hex: 0xC9E66B), Color(hex: 0xF2C46D), Color(hex: 0xF29BB0), Color(hex: 0xB9A3F0), Color(hex: 0x7CC6E8), Color(hex: 0x88CF94)]

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB, red: Double(hex >> 16 & 0xFF) / 255, green: Double(hex >> 8 & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }
}

struct Swatch: View {
    let fill: AnyShapeStyle
    let stripes: [Color]

    var body: some View {
        RoundedRectangle(cornerRadius: 46, style: .continuous)
            .fill(fill)
            .overlay(alignment: .bottom) {
                VStack(spacing: 10) {
                    ForEach(stripes.indices, id: \.self) { RoundedRectangle(cornerRadius: 12, style: .continuous).fill(stripes[$0]).frame(height: 34) }
                }
                .padding(26)
            }
            .overlay(RoundedRectangle(cornerRadius: 46, style: .continuous).strokeBorder(.white.opacity(0.22), lineWidth: 3))
            .frame(width: 290, height: 440)
            .shadow(color: .black.opacity(0.45), radius: 28, y: 18)
    }
}

struct Icon: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 185, style: .continuous)
                .fill(LinearGradient(colors: [Color(hex: 0x26332B), Color(hex: 0x0E1310)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(
                    RadialGradient(colors: [Color(hex: 0x88CF94).opacity(0.45), .clear], center: .bottomTrailing, startRadius: 0, endRadius: 620)
                        .clipShape(RoundedRectangle(cornerRadius: 185, style: .continuous))
                )
                .overlay(RoundedRectangle(cornerRadius: 185, style: .continuous).strokeBorder(.white.opacity(0.12), lineWidth: 4))
                .frame(width: 824, height: 824)
                .shadow(color: .black.opacity(0.35), radius: 24, y: 14)

            ZStack {
                Swatch(fill: AnyShapeStyle(Color(hex: 0xF3EFE7)), stripes: [Color(hex: 0xD9D5CC), Color(hex: 0x8F9B94), Color(hex: 0x1A201C)])
                    .rotationEffect(.degrees(-20), anchor: .bottom)
                Swatch(fill: AnyShapeStyle(LinearGradient(colors: [Color(hex: 0xA9D4B0), Color(hex: 0x4F8A5C)], startPoint: .top, endPoint: .bottom)),
                       stripes: [Color(hex: 0x88CF94), Color(hex: 0x3A6145), Color(hex: 0x1A201C)])
                    .rotationEffect(.degrees(0), anchor: .bottom)
                Swatch(fill: AnyShapeStyle(AngularGradient(colors: holo, center: .center)), stripes: [.white.opacity(0.55), .white.opacity(0.3), .black.opacity(0.35)])
                    .overlay(
                        LinearGradient(colors: [.white.opacity(0), .white.opacity(0.5), .white.opacity(0)], startPoint: .topLeading, endPoint: .bottomTrailing)
                            .blendMode(.softLight)
                            .clipShape(RoundedRectangle(cornerRadius: 46, style: .continuous))
                            .frame(width: 290, height: 440)
                    )
                    .rotationEffect(.degrees(20), anchor: .bottom)
            }
            .offset(y: -30)
        }
        .frame(width: 1024, height: 1024)
    }
}

@MainActor
func write(size: Int, to folder: URL) throws -> String {
    let renderer = ImageRenderer(content: Icon())
    renderer.scale = CGFloat(size) / 1024
    guard let image = renderer.cgImage else { fatalError("render failed") }
    let rep = NSBitmapImageRep(cgImage: image)
    let name = "icon_\(size).png"
    try rep.representation(using: .png, properties: [:])!.write(to: folder.appending(path: name))
    return name
}

let folder = URL(fileURLWithPath: CommandLine.arguments[1])
let slots: [(Int, Int)] = [(16, 1), (16, 2), (32, 1), (32, 2), (128, 1), (128, 2), (256, 1), (256, 2), (512, 1), (512, 2)]
var images: [[String: String]] = []
MainActor.assumeIsolated {
    for (points, scale) in slots {
        let name = try! write(size: points * scale, to: folder)
        images.append(["idiom": "mac", "size": "\(points)x\(points)", "scale": "\(scale)x", "filename": name])
    }
}
let contents: [String: Any] = ["images": images, "info": ["author": "xcode", "version": 1]]
try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys]).write(to: folder.appending(path: "Contents.json"))
print("icon set written:", Set(images.map { $0["filename"]! }).count, "files")
