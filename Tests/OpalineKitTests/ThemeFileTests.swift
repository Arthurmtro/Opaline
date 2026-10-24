import Foundation
import Testing
@testable import OpalineKit

struct ThemeFileTests {
    @Test func minimalThemeResolvesEveryRole() throws {
        let theme = try ThemeFile.decode(Data(##"{ "name": "Ocean", "palette": { "base": "#0F1720", "text": "#E6EDF3", "accent": "#4FB3FF" } }"##.utf8))
        #expect(theme.id == "ocean")
        #expect(theme.appearance == .dark)
        #expect(theme.palette.accent.hex == "#4FB3FF")
        #expect(theme.palette.selection == theme.palette.base.mixed(with: theme.palette.accent, 0.28))
        #expect(theme.terminal.ansi.count == 16)
        #expect(theme.syntax.keyword == theme.palette.accent)
        #expect(theme.backdrop.glow == theme.palette.accent)
        #expect(abs(theme.backdrop.webHue - theme.palette.accent.hsl.hue) < 0.001)
        #expect(theme.wallpaper.ringText == "OCEAN")
        #expect(theme.assets.isEmpty)
    }

    @Test func explicitValuesWinOverDerivedOnes() throws {
        let json = ##"{ "name": "X", "appearance": "light", "palette": { "base": "#FFFFFF", "text": "#111111", "accent": "#0066FF", "selection": "#CCE0FF" }, "syntax": { "comment": "#999999" } }"##
        let theme = try ThemeFile.decode(Data(json.utf8))
        #expect(theme.palette.selection.hex == "#CCE0FF")
        #expect(theme.syntax.comment.hex == "#999999")
        #expect(theme.terminal.ansi[0] == theme.palette.text)
        #expect(theme.palette.success.hex == "#1A7F37")
    }

    @Test func acceptsAChatAnswerWithAFence() throws {
        let answer = """
        Here is your theme:

        ```json
        { "name": "Dune", "palette": { "base": "#1C1A16", "text": "#EDE6D6", "accent": "#E0A458" } }
        ```
        Enjoy!
        """
        #expect(try ThemeFile.decode(Data(answer.utf8)).name == "Dune")
    }

    @Test func explainsWhatIsWrong() {
        func message(_ json: String) -> String? {
            do {
                _ = try ThemeFile.decode(Data(json.utf8))
                return nil
            } catch {
                return error.localizedDescription
            }
        }
        #expect(message(##"{ "palette": {} }"##) == "name is missing.")
        #expect(message(##"{ "name": "A", "palette": { "base": "#000", "text": "#FFF" } }"##) == "palette.accent is missing.")
        #expect(message(##"{ "name": "A", "palette": { "base": "#000", "text": "#FFF", "accent": "blue" } }"##) == "palette.accent: Invalid color blue")
        #expect(message(##"{ "name": "A", "palette": { "base": "#000", "text": "#FFF", "accent": "#00F" }, "terminal": { "ansi": ["#000"] } }"##)
                == "terminal.ansi: needs exactly 16 colors, found 1")
        #expect(message(##"{ "format": "vscode", "name": "A" }"##) == "format: expected \"opaline-theme\", found \"vscode\"")
        #expect(message("no json here") == "No theme found: the text has no JSON object.")
    }

    @Test(arguments: ["opaline", "sage", "catppuccin-mocha", "paper"])
    func builtInThemesRoundTrip(id: String) throws {
        let theme = try Fixtures.builtIn(id)
        let exported = try ThemeFile.encode(theme)
        #expect(try ThemeFile.decode(exported) == theme)
        let text = String(decoding: exported, as: UTF8.self)
        #expect(text.contains(##""format" : "opaline-theme""##))
        #expect(text.contains(Theme.schemaURL))
    }
}
