import SwiftUI
import OpalineKit

extension HexColor {
    var color: Color { Color(.sRGB, red: red, green: green, blue: blue, opacity: alpha) }

    init(_ color: Color) {
        let resolved = NSColor(color).usingColorSpace(.sRGB) ?? .black
        self.init(red: resolved.redComponent, green: resolved.greenComponent, blue: resolved.blueComponent, alpha: resolved.alphaComponent)
    }
}

extension Theme {
    /// The theme's most characteristic colors, for dots and mini cards.
    var swatches: [HexColor] {
        [palette.accent, palette.accentSoft, syntax.function, syntax.type, syntax.number, syntax.special, syntax.string]
    }

    var colorScheme: ColorScheme { appearance == .dark ? .dark : .light }

    var holoGradient: AngularGradient {
        AngularGradient(colors: (wallpaper.holo + wallpaper.holo.prefix(1)).map(\.color), center: .center)
    }
}

/// The window background: the theme's deep color with its accent glowing from two corners.
struct ThemeBackdrop: View {
    let theme: Theme

    var body: some View {
        ZStack {
            LinearGradient(colors: [theme.palette.deep.color, theme.palette.base.color], startPoint: .topLeading, endPoint: .bottomTrailing)
            RadialGradient(colors: [theme.backdrop.glow.color.opacity(0.28), .clear], center: .bottomTrailing, startRadius: 0, endRadius: 720)
            RadialGradient(colors: [theme.palette.accentSoft.color.opacity(0.10), .clear], center: .topLeading, startRadius: 0, endRadius: 520)
            Grain().opacity(0.05).blendMode(.overlay)
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.5), value: theme)
    }
}

/// Film grain with a fixed seed, so it does not shimmer on redraw.
struct Grain: View {
    var body: some View {
        Canvas { context, size in
            var random = StableRandom()
            for _ in 0..<Int(size.width * size.height / 18) {
                let point = CGPoint(x: .random(in: 0...size.width, using: &random), y: .random(in: 0...size.height, using: &random))
                context.fill(Path(CGRect(origin: point, size: CGSize(width: 1, height: 1))), with: .color(.white.opacity(.random(in: 0.2...1, using: &random))))
            }
        }
        .drawingGroup()
        .allowsHitTesting(false)
    }
}

struct StableRandom: RandomNumberGenerator {
    private var state: UInt64 = 0x5EED_BE10

    mutating func next() -> UInt64 {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return state
    }
}

struct GlassCard<Content: View>: View {
    var padding: CGFloat = 20
    var radius: CGFloat = 22
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(LinearGradient(colors: [Color.primary.opacity(0.18), Color.primary.opacity(0.04)], startPoint: .top, endPoint: .bottom), lineWidth: 1)
            )
    }
}

/// The signature round button, ringed by the theme's iridescent colors.
struct BigRoundButton: View {
    let theme: Theme
    let title: String
    let subtitle: String
    let action: () -> Void
    @State private var spin = false
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(theme.holoGradient)
                    .blur(radius: 26)
                    .opacity(hovering ? 0.75 : 0.5)
                    .scaleEffect(1.05)
                Circle()
                    .strokeBorder(theme.holoGradient, lineWidth: 3)
                    .rotationEffect(.degrees(spin ? 360 : 0))
                Circle()
                    .fill(
                        RadialGradient(colors: [theme.palette.accent.color, theme.palette.accentDeep.color], center: .init(x: 0.35, y: 0.3), startRadius: 4, endRadius: 110)
                    )
                    .padding(7)
                    .overlay(Circle().stroke(.white.opacity(0.25), lineWidth: 1).padding(7))
                VStack(spacing: 4) {
                    Text(title)
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                    Text(subtitle)
                        .font(.system(size: 11, weight: .medium))
                        .opacity(0.8)
                }
                .foregroundStyle(theme.palette.deep.color)
            }
            .frame(width: 148, height: 148)
            .scaleEffect(hovering ? 1.04 : 1)
            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: hovering)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .onAppear {
            withAnimation(.linear(duration: 14).repeatForever(autoreverses: false)) { spin = true }
        }
    }
}

struct PillButtonStyle: ButtonStyle {
    var prominent = false
    var tint: Color = .white

    func makeBody(configuration: Configuration) -> some View {
        PillLabel(configuration: configuration, prominent: prominent, tint: tint)
    }

    private struct PillLabel: View {
        let configuration: Configuration
        let prominent: Bool
        let tint: Color
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .font(.system(size: 13, weight: .semibold))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .foregroundStyle(prominent ? Color.black.opacity(0.85) : .primary)
                .background(
                    Capsule().fill(prominent ? AnyShapeStyle(tint) : AnyShapeStyle(Color.primary.opacity(configuration.isPressed ? 0.18 : 0.1)))
                )
                .overlay(Capsule().strokeBorder(Color.primary.opacity(prominent ? 0 : 0.14), lineWidth: 1))
                .scaleEffect(configuration.isPressed ? 0.97 : 1)
                .opacity(isEnabled ? 1 : 0.35)
        }
    }
}

struct StatusPill: View {
    enum Tone { case positive, neutral, warning, negative }

    let text: String
    let tone: Tone

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .foregroundStyle(color)
            .background(Capsule().fill(color.opacity(0.16)))
    }

    private var color: Color {
        switch tone {
        case .positive: Color(red: 0.53, green: 0.81, blue: 0.58)
        case .neutral: Color.primary.opacity(0.7)
        case .warning: Color(red: 0.89, green: 0.75, blue: 0.49)
        case .negative: Color(red: 0.88, green: 0.48, blue: 0.45)
        }
    }
}

struct SectionTitle: View {
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(size: 28, weight: .bold, design: .rounded))
            if let subtitle {
                Text(subtitle).font(.system(size: 13)).foregroundStyle(Color.primary.opacity(0.6))
            }
        }
    }
}

/// The app's icon, or an SF Symbol tile when there is no app bundle.
struct TargetIcon: View {
    let info: TargetInfo
    var size: CGFloat = 44
    var tint: Color = .white

    var body: some View {
        if let url = info.appURL, FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path(percentEncoded: false)))
                .resizable()
                .interpolation(.high)
                .frame(width: size, height: size)
        } else {
            RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                .fill(LinearGradient(colors: [tint.opacity(0.9), tint.opacity(0.55)], startPoint: .top, endPoint: .bottom))
                .frame(width: size * 0.84, height: size * 0.84)
                .overlay(Image(systemName: info.symbol).font(.system(size: size * 0.38, weight: .semibold)).foregroundStyle(.black.opacity(0.75)))
                .frame(width: size, height: size)
        }
    }
}
