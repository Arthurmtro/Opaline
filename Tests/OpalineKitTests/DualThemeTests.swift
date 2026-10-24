import Foundation
import ImageIO
import Testing
@testable import OpalineKit

struct DualThemeTests {
    static let json = ##"""
    {
      "name": "Dune",
      "appearance": "dark",
      "palette": { "base": "#1C1A16", "text": "#EDE6D6", "accent": "#E0A458" },
      "alternate": { "palette": { "base": "#F6F1E7", "text": "#2A241B", "accent": "#9A5B12" } }
    }
    """##

    func dune() throws -> Theme { try ThemeFile.decode(Data(Self.json.utf8)) }

    @Test func readsTheAlternateAndBuildsVariants() throws {
        let theme = try dune()
        let alternate = try #require(theme.alternate)
        #expect(alternate.appearance == .light)
        #expect(alternate.palette.base.hex == "#F6F1E7")
        #expect(alternate.palette.success.hex == "#1A7F37")
        #expect(theme.appearances == [.dark, .light])

        let light = theme.variant(.light)
        #expect(light.appearance == .light)
        #expect(light.palette.accent.hex == "#9A5B12")
        #expect(light.alternate?.palette.base == theme.palette.base)
        #expect(theme.variant(.dark) == theme)
        #expect(theme.variantName(.light) == "Dune Light")
        #expect(try Fixtures.sage().variantName(.dark) == "Sage")
    }

    @Test func roundTripsAndUpdatesVariants() throws {
        var theme = try dune()
        #expect(try ThemeFile.decode(ThemeFile.encode(theme)) == theme)
        var light = theme.variant(.light)
        light.palette.accent = HexColor("#123456")!
        theme.update(light)
        #expect(theme.alternate?.palette.accent.hex == "#123456")
        #expect(theme.palette.accent.hex == "#E0A458")
    }

    @Test func derivesAnOppositeVariant() throws {
        let sage = try Fixtures.sage()
        let light = ThemeVariant.opposite(of: sage)
        #expect(light.appearance == .light)
        #expect(light.palette.base.hsl.lightness > 0.85)
        #expect(light.palette.text.hsl.lightness < 0.15)
    }

    @Test func claudeCodeWearsTheMacVariant() async throws {
        let theme = try dune()
        let environment = try Fixtures.temporaryEnvironment()
        try FileManager.default.createDirectory(at: environment.url("~/.claude"), withIntermediateDirectories: true)
        for appearance in Appearance.allCases {
            let context = TargetContext(environment: environment, appearance: appearance)
            let changes = try await ClaudeCodeTarget().changes(for: theme, in: context)
            let file = try #require(changes.first { $0.url.lastPathComponent == "dune.json" })
            let document = try #require(try JSONSerialization.jsonObject(with: file.contents) as? [String: Any])
            #expect(document["base"] as? String == appearance.rawValue)
        }
    }

    @Test func appsFollowTheMac() throws {
        let theme = try dune()
        let ghostty = GhosttyTarget.config("background-image = ~/old.png\n", theme: theme, backdrop: "~/x.png")
        #expect(ghostty.contains("theme = light:Dune Light,dark:Dune Dark"))
        #expect(ghostty.contains("background-image =\n# <<< opaline <<<"))
        #expect(!ghostty.contains("~/x.png"))

        let cmux = try CmuxTarget.config("{}\n", theme: theme)
        #expect(try JSONCEditor.value(at: ["app", "appearance"], in: cmux) == "\"system\"")
        #expect(try JSONCEditor.value(at: ["sidebarAppearance", "lightModeTintColor"], in: cmux) == "\"#F6F1E7\"")
        #expect(try JSONCEditor.value(at: ["sidebarAppearance", "darkModeTintColor"], in: cmux) == "\"#1C1A16\"")
        let single = try CmuxTarget.config(cmux, theme: try Fixtures.sage())
        #expect(try JSONCEditor.value(at: ["sidebarAppearance", "lightModeTintColor"], in: single) == "null")
        #expect(try JSONCEditor.value(at: ["app", "appearance"], in: single) == "\"dark\"")

        let zen = ZenTarget.userChrome("/* mine */\n", theme: theme)
        #expect(zen.hasPrefix("/* mine */"))
        #expect(zen.contains("@media (prefers-color-scheme: light)"))
        #expect(zen.contains("--zen-main-browser-background-toolbar-old: linear-gradient(-30deg"))
        #expect(zen.contains("zen-workspace {"))
        #expect(!ZenTarget.userChrome(zen, theme: try Fixtures.sage()).contains("@media"))

        let zedFromString = try ZedTarget.settings("{ \"theme\": \"One\" }", theme: theme)
        #expect(try JSONCEditor.value(at: ["theme", "mode"], in: zedFromString) == "\"system\"")
        #expect(try JSONCEditor.value(at: ["theme", "light"], in: zedFromString) == "\"Dune Light\"")
        let zedFromObject = try ZedTarget.settings("{ \"theme\": { \"mode\": \"dark\", \"dark\": \"One\" } }", theme: theme)
        #expect(try JSONCEditor.value(at: ["theme", "dark"], in: zedFromObject) == "\"Dune Dark\"")
        #expect(try JSONCEditor.value(at: ["theme", "mode"], in: zedFromObject) == "\"system\"")

        let family = try #require(try JSONSerialization.jsonObject(with: ZedTarget.themeFile(theme)) as? [String: Any])
        #expect((family["themes"] as? [[String: Any]])?.compactMap { $0["name"] as? String } == ["Dune Dark", "Dune Light"])
    }

    @Test func dynamicWallpaperHasBothImagesAndTheAppearanceTag() throws {
        let theme = try dune()
        let heic = try DynamicWallpaper.heic(
            light: BackdropRenderer.render(theme: theme.variant(.light), width: 64, height: 36),
            dark: BackdropRenderer.render(theme: theme, width: 64, height: 36)
        )
        let source = try #require(CGImageSourceCreateWithData(heic as CFData, nil))
        #expect(CGImageSourceGetCount(source) == 2)
        let metadata = try #require(CGImageSourceCopyMetadataAtIndex(source, 0, nil))
        let tag = try #require(CGImageMetadataCopyStringValueWithPath(metadata, nil, "apple_desktop:apr" as CFString) as String?)
        let indexes = try PropertyListSerialization.propertyList(from: try #require(Data(base64Encoded: tag)), format: nil) as? [String: Int]
        #expect(indexes == ["l": 0, "d": 1])
    }
}
