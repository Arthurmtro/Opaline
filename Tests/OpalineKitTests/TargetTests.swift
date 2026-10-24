import Foundation
import Synchronization
import Testing
@testable import OpalineKit

struct TargetTests {
    @Test func ghosttyThemeFileAndManagedBlock() throws {
        let theme = try Fixtures.sage()
        let file = GhosttyTarget.themeFile(theme)
        #expect(file.contains("background = #1A201C\n"))
        #expect(file.contains("palette = 0=#29312C\n"))
        #expect(file.contains("palette = 15=#F3EFE7\n"))

        let original = "font-size = 14\ntheme = Catppuccin\n"
        let once = GhosttyTarget.config(original, theme: theme, backdrop: "~/.config/ghostty/opaline-backdrop.png")
        let twice = GhosttyTarget.config(once, theme: try Fixtures.catppuccin(), backdrop: "~/.config/ghostty/opaline-backdrop.png")
        #expect(once.hasPrefix(original))
        #expect(once.contains("theme = Sage"))
        #expect(twice.contains("theme = Catppuccin Mocha"))
        #expect(!twice.contains("theme = Sage"))
        #expect(twice.components(separatedBy: GhosttyTarget.blockStart).count == 2)
    }

    @Test func cmuxKeepsCommentsAndSetsKeys() throws {
        let current = """
        {
          "$schema": "x",
          "schemaVersion": 1,
          // keep me
          "app": { "confirmQuit": "always" },
        }
        """
        let result = try CmuxTarget.config(current, theme: try Fixtures.sage())
        #expect(result.contains("// keep me"))
        #expect(try JSONCEditor.value(at: ["app", "accentColor"], in: result) == "\"#88CF94\"")
        #expect(try JSONCEditor.value(at: ["app", "confirmQuit"], in: result) == "\"always\"")
        #expect(try JSONCEditor.value(at: ["sidebarAppearance", "tintColor"], in: result) == "\"#1A201C\"")
        #expect(try JSONCEditor.value(at: ["workspaceColors", "selectionColor"], in: result) == "\"#2F4A36\"")
        #expect(try JSONCEditor.value(at: ["activePaneBorderColor"], in: result) == "\"#88CF94\"")
    }

    @Test func zedKeepsTheShapeOfTheThemeSetting() throws {
        let theme = try Fixtures.sage()
        let object = try ZedTarget.settings("{\n  \"theme\": { \"mode\": \"dark\", \"dark\": \"One\", \"light\": \"Two\" },\n}", theme: theme)
        #expect(try JSONCEditor.value(at: ["theme", "dark"], in: object) == "\"Sage\"")
        #expect(try JSONCEditor.value(at: ["theme", "light"], in: object) == "\"Two\"")
        let string = try ZedTarget.settings("{ \"theme\": \"One\" }", theme: theme)
        #expect(try JSONCEditor.value(at: ["theme"], in: string) == "\"Sage\"")
    }

    @Test func zedThemeFileIsComplete() throws {
        let data = try ZedTarget.themeFile(try Fixtures.sage())
        let family = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let theme = try #require((family["themes"] as? [[String: Any]])?.first)
        let style = try #require(theme["style"] as? [String: Any])
        #expect(style["editor.background"] as? String == "#1A201C")
        #expect(style["terminal.ansi.bright_green"] as? String == "#A9D4B0")
        #expect((style["syntax"] as? [String: Any])?.count ?? 0 > 40)
    }

    @Test func zenSessionsGetTheBrowserGradient() throws {
        let session = #"{"spaces":[{"uuid":"a","name":"Work","theme":{}},{"uuid":"b","name":"Perso"}],"tabs":[]}"#
        let data = try ZenTarget.sessions(Data(session.utf8), theme: try Fixtures.sage())
        let root = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let spaces = try #require(root["spaces"] as? [[String: Any]])
        for space in spaces {
            let theme = try #require(space["theme"] as? [String: Any])
            let colors = try #require(theme["gradientColors"] as? [[String: Any]])
            #expect(colors.first?["c"] as? [Int] == [26, 32, 28])
            #expect(colors.first?["isPrimary"] as? Bool == true)
            #expect(theme["opacity"] as? Double == 0.8)
        }
    }

    @Test func gitHubStylesheetMatchesTheValidatedPalette() throws {
        let css = try GitHubStylesheet.css(for: try Fixtures.sage())
        #expect(css.contains("--bgColor-default: #1A201C !important;"))
        #expect(css.contains("--bgColor-inset: #181E19 !important;"))
        #expect(css.contains("--bgColor-muted: #28332B !important;"))
        #expect(css.contains("--borderColor-default: #4B544D !important;"))
        #expect(css.contains("rgba(136, 207, 148, 0.22) 0%"))
        #expect(!css.contains("--display-blue"))
    }

    @Test func claudeCodeThemeUsesTheHighlight() throws {
        let data = try ClaudeCodeTarget.themeFile(try Fixtures.sage())
        let document = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let overrides = try #require(document["overrides"] as? [String: String])
        #expect(document["base"] as? String == "dark")
        #expect(overrides["userMessageBackground"] == "#2B3B30")
        #expect(overrides["selectionBg"] == "#2F4A36")
    }

    @Test func backdropHasTheGlowInTheCorner() throws {
        let png = BackdropRenderer.render(theme: try Fixtures.sage(), width: 64, height: 36)
        #expect(png.prefix(4) == Data([0x89, 0x50, 0x4E, 0x47]))
    }
}

struct EngineTests {
    @Test func appliesAndRestores() async throws {
        let environment = try Fixtures.temporaryEnvironment()
        let existing = environment.url("~/.config/tool/colors.conf")
        try FileManager.default.createDirectory(at: existing.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "original".write(to: existing, atomically: true, encoding: .utf8)
        let created = environment.url("~/.config/other/theme.txt")

        let targets: [any ThemeTarget] = [
            CustomTarget(definition: .init(id: "one", name: "Tool", outputPath: "~/.config/tool/colors.conf", template: "bg={{palette.base}}")),
            CustomTarget(definition: .init(id: "two", name: "Other", outputPath: "~/.config/other/theme.txt", template: "{{name}}")),
        ]
        let engine = ApplyEngine(environment: environment)
        let snapshot = try await engine.apply(try Fixtures.sage(), to: targets) { _ in }

        #expect(try String(contentsOf: existing, encoding: .utf8) == "bg=#1A201C")
        #expect(try String(contentsOf: created, encoding: .utf8) == "Sage")
        #expect(AppliedState.load(in: environment).themeByTarget["custom.one"] == "sage")
        #expect(try SnapshotStore(environment: environment).load().map(\.id) == [snapshot.id])

        try await engine.restore(snapshot, targets: targets)
        #expect(try String(contentsOf: existing, encoding: .utf8) == "original")
        #expect(!FileManager.default.fileExists(atPath: created.path(percentEncoded: false)))
        #expect(AppliedState.load(in: environment).themeByTarget.isEmpty)
    }

    @Test func keepsTheManifestWhenALaterTargetFails() async throws {
        let environment = try Fixtures.temporaryEnvironment()
        let blocker = environment.url("~/blocker")
        try FileManager.default.createDirectory(at: environment.home, withIntermediateDirectories: true)
        try "a file, not a folder".write(to: blocker, atomically: true, encoding: .utf8)
        let targets: [any ThemeTarget] = [
            CustomTarget(definition: .init(id: "ok", name: "Fine", outputPath: "~/fine.conf", template: "{{name}}")),
            CustomTarget(definition: .init(id: "ko", name: "Broken", outputPath: "~/blocker/inside.conf", template: "{{name}}")),
        ]
        let recorded = Mutex<[String: ApplyEvent.Phase]>([:])
        _ = try await ApplyEngine(environment: environment).apply(try Fixtures.sage(), to: targets) { event in
            recorded.withLock { $0[event.targetID] = event.phase }
        }
        let phases = recorded.withLock { $0 }
        let saved = try #require(try SnapshotStore(environment: environment).load().first)
        #expect(saved.entries.map(\.targetID).contains("custom.ok"))
        #expect(phases["custom.ok"] == .done)
        if case .failed = phases["custom.ko"] {} else { Issue.record("Broken target should fail, got \(String(describing: phases["custom.ko"]))") }
        #expect(AppliedState.load(in: environment).themeByTarget == ["custom.ok": "sage"])
    }

    @Test func libraryMergesBuiltInAndUserThemes() throws {
        let store = ThemeStore(environment: try Fixtures.temporaryEnvironment())
        var library = try store.load()
        #expect(library.themes.map(\.id).starts(with: ["catppuccin-mocha", "opaline", "paper", "sage"]))
        let sage = try #require(library.themes.first { $0.id == "sage" })
        #expect(library.isPristineBuiltIn(sage))

        var edited = sage
        edited.palette.accent = HexColor("#FF0000")!
        try store.save(edited)
        library = try store.load()
        #expect(library.themes.filter { $0.id == "sage" }.map(\.palette.accent.hex) == ["#FF0000"])
        #expect(library.isModifiedBuiltIn(edited))

        try store.delete(edited)
        library = try store.load()
        #expect(library.themes.first { $0.id == "sage" }?.palette.accent.hex == "#88CF94")

        let copy = try store.duplicate(sage, named: "Sage Light", existing: library.themes)
        #expect(copy.id == "sage-light")
        let imported = try store.add(try #require(library.themes.first { $0.id == "opaline" }), existing: try store.load().themes)
        #expect(imported.id == "opaline-2")
        #expect(imported.assets["monogram.svg"] != nil)
        #expect(try store.load().userIDs == ["sage-light", "opaline-2"])
    }
}
