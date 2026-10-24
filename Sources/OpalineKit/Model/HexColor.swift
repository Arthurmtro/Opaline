import Foundation

/// An sRGB color stored as `#RRGGBB` or `#RRGGBBAA`, the format every target config uses.
public struct HexColor: Hashable, Sendable, Codable, CustomStringConvertible {
    public var red: Double
    public var green: Double
    public var blue: Double
    public var alpha: Double

    public init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = red.clamped
        self.green = green.clamped
        self.blue = blue.clamped
        self.alpha = alpha.clamped
    }

    public init?(_ string: String) {
        var hex = string.trimmingCharacters(in: .whitespaces)
        guard hex.hasPrefix("#") else { return nil }
        hex.removeFirst()
        if hex.count == 3 || hex.count == 4 {
            hex = hex.map { "\($0)\($0)" }.joined()
        }
        guard hex.count == 6 || hex.count == 8, let value = UInt64(hex, radix: 16) else { return nil }
        let hasAlpha = hex.count == 8
        let shift: UInt64 = hasAlpha ? 8 : 0
        self.init(
            red: Double((value >> (16 + shift)) & 0xFF) / 255,
            green: Double((value >> (8 + shift)) & 0xFF) / 255,
            blue: Double((value >> shift) & 0xFF) / 255,
            alpha: hasAlpha ? Double(value & 0xFF) / 255 : 1
        )
    }

    public init(from decoder: Decoder) throws {
        let string = try decoder.singleValueContainer().decode(String.self)
        guard let color = HexColor(string) else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Invalid color \(string)"))
        }
        self = color
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(hex)
    }

    /// `#RRGGBB`, plus `AA` when the color is translucent.
    public var hex: String {
        let rgb = [red, green, blue].map(Self.byte).map { String(format: "%02X", $0) }.joined()
        return alpha < 1 ? "#\(rgb)\(String(format: "%02X", Self.byte(alpha)))" : "#\(rgb)"
    }

    /// Always `#RRGGBB`, dropping any alpha.
    public var opaqueHex: String { withAlpha(1).hex }

    public var description: String { hex }

    public var rgbBytes: (red: Int, green: Int, blue: Int) {
        (Self.byte(red), Self.byte(green), Self.byte(blue))
    }

    public func withAlpha(_ alpha: Double) -> HexColor {
        HexColor(red: red, green: green, blue: blue, alpha: alpha)
    }

    /// Linear blend: `fraction` 0 keeps `self`, 1 gives `other`.
    public func mixed(with other: HexColor, _ fraction: Double) -> HexColor {
        HexColor(
            red: red + (other.red - red) * fraction,
            green: green + (other.green - green) * fraction,
            blue: blue + (other.blue - blue) * fraction,
            alpha: alpha + (other.alpha - alpha) * fraction
        )
    }

    public var hsl: (hue: Double, saturation: Double, lightness: Double) {
        let maxValue = max(red, green, blue), minValue = min(red, green, blue)
        let lightness = (maxValue + minValue) / 2
        guard maxValue != minValue else { return (0, 0, lightness) }
        let delta = maxValue - minValue
        let saturation = lightness > 0.5 ? delta / (2 - maxValue - minValue) : delta / (maxValue + minValue)
        let hue: Double
        switch maxValue {
        case red: hue = (green - blue) / delta + (green < blue ? 6 : 0)
        case green: hue = (blue - red) / delta + 2
        default: hue = (red - green) / delta + 4
        }
        return (hue * 60, saturation, lightness)
    }

    public init(hue: Double, saturation: Double, lightness: Double, alpha: Double = 1) {
        guard saturation > 0 else {
            self.init(red: lightness, green: lightness, blue: lightness, alpha: alpha)
            return
        }
        let q = lightness < 0.5 ? lightness * (1 + saturation) : lightness + saturation - lightness * saturation
        let p = 2 * lightness - q
        let h = hue.truncatingRemainder(dividingBy: 360) / 360
        func channel(_ t: Double) -> Double {
            let t = t < 0 ? t + 1 : (t > 1 ? t - 1 : t)
            if t < 1.0 / 6 { return p + (q - p) * 6 * t }
            if t < 1.0 / 2 { return q }
            if t < 2.0 / 3 { return p + (q - p) * (2.0 / 3 - t) * 6 }
            return p
        }
        self.init(red: channel(h + 1.0 / 3), green: channel(h), blue: channel(h - 1.0 / 3), alpha: alpha)
    }

    private static func byte(_ component: Double) -> Int { Int((component * 255).rounded()) }
}

private extension Double {
    /// Clamped to 0...1 and snapped to 8 bits, so a color equals what its hex code says and survives a file round trip.
    var clamped: Double { (Swift.min(Swift.max(self, 0), 1) * 255).rounded() / 255 }
}
