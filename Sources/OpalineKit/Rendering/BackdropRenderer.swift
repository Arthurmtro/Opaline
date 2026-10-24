import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Base color with a glow rising from the bottom-right corner, plus film grain. Used as the terminal background.
public enum BackdropRenderer {
    public static func render(theme: Theme, width: Int, height: Int) -> Data {
        let base = theme.palette.base.rgbBytes
        let glow = theme.backdrop.glow.rgbBytes
        let strength = theme.backdrop.glowStrength
        var random = SeededRandom(seed: 0xBE10_4DE4)
        var pixels = [UInt8](repeating: 255, count: width * height * 4)

        for y in 0..<height {
            let dy = Double(height - y) / Double(height)
            for x in 0..<width {
                let dx = Double(width - x) / Double(width)
                let distance = min(1, (dx * dx + dy * dy).squareRoot())
                let mix = pow(1 - distance, 2.2) * strength
                let grain = theme.backdrop.grain > 0 ? random.gaussian() * theme.backdrop.grain : 0
                let index = (y * width + x) * 4
                pixels[index] = channel(base.red, glow.red, mix, grain)
                pixels[index + 1] = channel(base.green, glow.green, mix, grain)
                pixels[index + 2] = channel(base.blue, glow.blue, mix, grain)
            }
        }
        return png(pixels, width: width, height: height)
    }

    private static func channel(_ base: Int, _ glow: Int, _ mix: Double, _ grain: Double) -> UInt8 {
        UInt8(max(0, min(255, (Double(base) + Double(glow - base) * mix + grain).rounded())))
    }

    static func png(_ pixels: [UInt8], width: Int, height: Int) -> Data {
        let provider = CGDataProvider(data: Data(pixels) as CFData)!
        let image = CGImage(
            width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue),
            provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent
        )!
        return png(image)
    }

    static func png(_ image: CGImage) -> Data {
        let data = NSMutableData()
        let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(destination, image, nil)
        CGImageDestinationFinalize(destination)
        return data as Data
    }
}

/// SplitMix64, so the grain is the same on every run.
struct SeededRandom {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> Double {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return Double((z ^ (z >> 31)) >> 11) / Double(1 << 53)
    }

    mutating func gaussian() -> Double {
        let u = max(next(), .leastNonzeroMagnitude)
        return (-2 * log(u)).squareRoot() * cos(2 * .pi * next())
    }
}
