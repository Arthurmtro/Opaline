import Foundation
import Testing
@testable import OpalineKit

struct HexColorTests {
    @Test func parsesAndFormats() throws {
        let color = try #require(HexColor("#88cf94"))
        #expect(color.hex == "#88CF94")
        #expect(color.rgbBytes == (136, 207, 148))
        #expect(HexColor("#88CF9440")?.hex == "#88CF9440")
        #expect(HexColor("#abc")?.hex == "#AABBCC")
        #expect(HexColor("88CF94") == nil)
    }

    @Test func roundTripsThroughHSL() throws {
        let color = try #require(HexColor("#4F8A5C"))
        let (hue, saturation, lightness) = color.hsl
        #expect(HexColor(hue: hue, saturation: saturation, lightness: lightness).hex == "#4F8A5C")
    }
}

struct JSONCEditorTests {
    let document = """
    {
      "$schema": "https://example.com/schema.json",
      // A comment that must survive.
      "app": {
        "appearance": "light", // trailing comment
        "confirmQuit": "always",
      },
      /* block comment */
      "list": [1, 2, {"a": "}"}],
    }
    """

    @Test func replacesNestedValueAndKeepsComments() throws {
        let result = try JSONCEditor.set(["app", "appearance"], to: "\"dark\"", in: document)
        #expect(result.contains("\"appearance\": \"dark\", // trailing comment"))
        #expect(result.contains("// A comment that must survive."))
        #expect(result.contains("/* block comment */"))
        #expect(result.contains("\"confirmQuit\": \"always\""))
    }

    @Test func insertsMissingMembersAndObjects() throws {
        var result = try JSONCEditor.set(["app", "accentColor"], to: "\"#88CF94\"", in: document)
        result = try JSONCEditor.set(["sidebar", "tint", "color"], to: "\"#1A201C\"", in: result)
        #expect(try JSONCEditor.value(at: ["app", "accentColor"], in: result) == "\"#88CF94\"")
        #expect(try JSONCEditor.value(at: ["sidebar", "tint", "color"], in: result) == "\"#1A201C\"")
        #expect(try JSONCEditor.value(at: ["app", "appearance"], in: result) == "\"light\"")
        #expect(result.contains("\n    \"accentColor\": \"#88CF94\","))
    }

    @Test func handlesEmptyObjects() throws {
        let result = try JSONCEditor.set(["theme"], to: "\"custom:sage\"", in: "{}\n")
        let object = try JSONSerialization.jsonObject(with: Data(result.utf8)) as? [String: String]
        #expect(object == ["theme": "custom:sage"])
    }

    @Test func readsValues() throws {
        #expect(try JSONCEditor.value(at: ["list"], in: document) == "[1, 2, {\"a\": \"}\"}]")
        #expect(try JSONCEditor.value(at: ["missing"], in: document) == nil)
    }
}

struct FormatTests {
    @Test func mozLZ4RoundTrips() throws {
        let payload = Data(String(repeating: "{\"spaces\":[{\"name\":\"Work\"}]}", count: 200).utf8)
        let encoded = try MozLZ4.encode(payload)
        #expect(encoded.prefix(8) == Data("mozLz40\0".utf8))
        #expect(encoded.count < payload.count)
        #expect(try MozLZ4.decode(encoded) == payload)
    }

    @Test func setsFirefoxPrefs() {
        let prefs = "user_pref(\"a\", 1);\nuser_pref(\"zen.view.window.scheme\", 2);\n"
        let result = FirefoxPrefs.set([("zen.view.window.scheme", .int(0)), ("flag", .bool(true)), ("name", .string("x\"y"))], in: prefs)
        #expect(result == "user_pref(\"a\", 1);\nuser_pref(\"zen.view.window.scheme\", 0);\nuser_pref(\"flag\", true);\nuser_pref(\"name\", \"x\\\"y\");\n")
    }

    @Test func rendersTokens() throws {
        let theme = try Fixtures.sage()
        let output = ThemeTokens.render("bg={{palette.base}} rgb={{ palette.accent | rgb }} hex={{palette.accent|nohash}} ansi={{terminal.ansi.4}} name={{name}} keep={{nope}}", theme: theme)
        #expect(output == "bg=#1A201C rgb=136, 207, 148 hex=88CF94 ansi=#7FA8D9 name=Sage keep={{nope}}")
    }
}

enum Fixtures {
    static func sage() throws -> Theme { try builtIn("sage") }
    static func catppuccin() throws -> Theme { try builtIn("catppuccin-mocha") }

    static func builtIn(_ id: String) throws -> Theme {
        try ThemeFile.decode(Data(contentsOf: KitResources.url("Themes/defaults/\(id).json")))
    }

    static func temporaryEnvironment() throws -> OpalineEnvironment {
        let root = FileManager.default.temporaryDirectory.appending(path: "opaline-tests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return OpalineEnvironment(
            home: root.appending(path: "home", directoryHint: .isDirectory),
            supportDirectory: root.appending(path: "support", directoryHint: .isDirectory),
            applicationsDirectory: root.appending(path: "Applications", directoryHint: .isDirectory)
        )
    }
}
