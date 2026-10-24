# Opaline theme format

An Opaline theme is one JSON file. It describes **color roles**, not app settings: Opaline translates the roles into the
config of every app it themes (terminal, editor, browser, Claude Code, wallpaper...). This page is written to be read by
people and by AI assistants. To make a theme with Claude, see [Make a theme with an AI](#make-a-theme-with-an-ai).

- JSON Schema: [`schema/theme.schema.json`](../schema/theme.schema.json)
- Examples: the built-in themes in [`themes/defaults`](../themes/defaults)
- Import: drop the file on the Opaline window, use **File › Import Theme…**, or copy the JSON and press **⇧⌘V**.

## The smallest valid theme

Only `name` and three colors are required. Everything else is derived from them.

```json
{
  "name": "Ocean Glass",
  "palette": { "base": "#0E1A24", "text": "#E3EEF5", "accent": "#4FC3F7" }
}
```

Add any key below to override the derived value. Unknown keys are ignored.

## Top-level keys

| Key | Type | Required | Default | Meaning |
|---|---|---|---|---|
| `name` | string | yes |  | Display name. |
| `id` | string | no | slug of `name` | File name and identifier. `[a-z0-9-]`. |
| `author` | string | no | `""` | Shown under the name. |
| `appearance` | `"dark"` \| `"light"` | no | `"dark"` | Drives defaults, app schemes (Zen, cmux, Zed, Claude Code). |
| `palette` | object | yes |  | UI color roles. `base`, `text`, `accent` required. |
| `terminal` | object | no | derived | `ansi`: exactly 16 colors. |
| `syntax` | object | no | derived | Code highlighting roles. |
| `backdrop` | object | no | derived | Terminal and web page glow. |
| `browser` | object | no | derived | Browser workspace gradient. |
| `wallpaper` | object | no | derived | Desktop wallpaper texts and colors. |
| `assets` | object | no | `{}` | Inline SVG files, keyed by name, used by `wallpaper.monogram` / `wallpaper.wordmark`. |
| `alternate` | object | no | none | Colors for the opposite appearance. See [Light and dark versions](#light-and-dark-versions). |
| `$schema`, `format`, `version` | | no |  | Written on export. `format` must be `"opaline-theme"` when present. |

Colors are hex strings: `#RGB`, `#RGBA`, `#RRGGBB` or `#RRGGBBAA`.

## `palette`: interface roles

Listed from background to foreground. "Derived" shows the formula used when the key is missing
(`mix(a, b, t)` moves from `a` towards `b` by `t`).

| Role | Where it shows | Derived from |
|---|---|---|
| `base` **(required)** | Main content background: editor, terminal, web pages. | |
| `text` **(required)** | Default text. | |
| `accent` **(required)** | Brand color: cursor, focused borders, links, keywords, buttons. | |
| `deep` | Window chrome: title bars, tab bars, status bar, wallpaper background. | dark: `mix(base, black, .25)`; light: `mix(base, text, .04)` |
| `surface` | Side panels (file tree, sidebars). | `mix(base, deep, .5)` |
| `elevated` | Popovers, cards, inputs, menus. | `mix(base, text, .06)` |
| `hover` | Hovered rows and buttons. | `mix(base, text, .10)` |
| `highlight` | Raised highlights: your own messages in Claude Code, active rows. | `mix(base, accent, .15)` |
| `selection` | Selected text and selected list items. | `mix(base, accent, .28)` |
| `border` | Visible borders and dividers. | `mix(base, text, .13)` |
| `borderSubtle` | Faint separators, indent guides. | `mix(base, text, .08)` |
| `accentSoft` | Lighter accent: secondary highlights, suggestions. | `mix(accent, text, .35)` |
| `accentDeep` | Darker accent: primary button fill, focused input border. | `mix(accent, base, .40)` |
| `accentDim` | Very muted accent: inactive focus, guides. | `mix(accent, base, .60)` |
| `textMuted` | Secondary text, line numbers of the active line context. | `mix(text, base, .42)` |
| `textSubtle` | Placeholders, hints. | `mix(text, base, .60)` |
| `textFaint` | Disabled text, line numbers. | `mix(text, base, .72)` |
| `success` | Additions, passing checks. | dark `#88CF94`, light `#1A7F37` |
| `warning` | Warnings, modified files. | dark `#E3C07D`, light `#9A6700` |
| `error` | Errors, deletions. | dark `#E07A72`, light `#CF222E` |
| `info` | Informational badges, renamed files. | dark `#7CC6BE`, light `#1B7C83` |

## `terminal.ansi`: the 16 terminal colors

Order: `black, red, green, yellow, blue, magenta, cyan, white`, then the 8 bright variants in the same order.
Used by Ghostty, cmux and Zed's terminal. Derived from `palette` (red = `error`, green = `success`, yellow = `warning`)
plus default blue, magenta and cyan. In a dark theme "black" is a raised background tone and "white" a soft text tone; in a
light theme "black" is the text color.

## `syntax`: code highlighting

| Role | Tokens | Derived from |
|---|---|---|
| `keyword` | `if`, `return`, `func`, tags | `accent` |
| `function` | function and method names, links | ANSI cyan |
| `type` | types, classes, attributes | `warning` |
| `string` | string literals | `success` |
| `number` | numbers, booleans, constants | `mix(error, warning, .3)` |
| `comment` | comments (rendered italic) | `textSubtle` |
| `property` | object properties | `mix(text, textMuted, .5)` |
| `variable` | variables | `text` |
| `special` | labels, preprocessor, regex, special variables | ANSI magenta |
| `operator` | operators | `accentSoft` |
| `punctuation` | brackets and delimiters | `textMuted` |

## `backdrop`, `browser`, `wallpaper`

| Key | Type | Meaning | Default |
|---|---|---|---|
| `backdrop.glow` | color | Glow rising from the bottom-right corner of the terminal and of web pages. | `accent` |
| `backdrop.glowStrength` | 0…1 | Glow intensity at the corner. Keep 0.1–0.25. | dark 0.2, light 0.12 |
| `backdrop.grain` | 0…8 | Film grain strength. 0 disables it. | 2.5 |
| `backdrop.webHue` | 0…360 | Hue GitHub's blue-greys are rotated to (dark themes). | hue of `accent` |
| `browser.colors` | colors | Browser workspace gradient, first color dominant. 1–3 colors. | `[base, mix(base, accent, .35)]` |
| `browser.opacity` | 0.3…0.8 | Gradient opacity. Higher is less transparent. | 0.8 |
| `browser.texture` | 0…1 | Grain on the browser gradient. | 0.125 |
| `wallpaper.holo` | colors | Iridescent stops for the logo ring, in order around the circle. 4–8 colors. | Opaline's mint, lime, apricot, rose, lilac, sky |
| `wallpaper.tagline` | strings | Words under the title, e.g. `["DESIGN", "APPLY", "EVERYWHERE"]`. | `[]` |
| `wallpaper.ringText` | string | Text repeated around the logo. Uppercase reads best. | `name` in uppercase |
| `wallpaper.cornerTopLeft`, `cornerBottomLeft`, `cornerBottomRight` | string | Small corner labels. Empty hides them. | `""` |
| `wallpaper.monogram` | string | Key in `assets` of an SVG logo drawn in the center. Missing: the theme initials. | none |
| `wallpaper.wordmark` | string | Key in `assets` of an SVG title. Missing: the theme name in letter-spaced text. | none |

### Logos (`assets`)

SVG markup stored as strings. The wallpaper uses them as **masks**: only the shape counts, colors are replaced by the
iridescent gradient (monogram) or the text color (wordmark). Requirements:

- a `viewBox` (the wordmark's width/height ratio comes from it);
- filled shapes, no strokes (use `fill-rule="evenodd"` for rings);
- no external references, scripts or raster images.

```json
"wallpaper": { "monogram": "logo.svg" },
"assets": {
  "logo.svg": "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 48 48\"><path fill-rule=\"evenodd\" d=\"M24 0a24 24 0 1 1 0 48a24 24 0 1 1 0-48zm0 3a21 21 0 1 0 0 42a21 21 0 1 0 0-42z\"/></svg>"
}
```

## Light and dark versions

A theme can carry both appearances. Put the colors of the other one in `alternate`: it has the same sections as the root
(`palette`, `terminal`, `syntax`, `backdrop`, `browser`), its appearance is the opposite of `appearance`, and it follows
the same rules: only `palette.base`, `palette.text` and `palette.accent` are required, the rest is derived. Name, author,
wallpaper texts and logos are shared.

```json
{
  "name": "Dune",
  "appearance": "dark",
  "palette": { "base": "#1C1A16", "text": "#EDE6D6", "accent": "#E0A458" },
  "alternate": {
    "palette": { "base": "#F6F1E7", "text": "#2A241B", "accent": "#9A5B12" }
  }
}
```

What follows the Mac's light/dark switch when a theme has both:

| App | Behaviour |
|---|---|
| Zed | both themes in one family ("Dune Dark", "Dune Light"), `theme.mode: "system"` |
| Terminal (Ghostty, cmux) | `theme = light:Dune Light,dark:Dune Dark`; no glow image (Ghostty has one for both), an earlier one is reset |
| cmux interface | appearance `system`, sidebar tint per mode |
| Wallpaper | a dynamic HEIC with both images, switched by macOS |
| Zen | window scheme follows the Mac; the space gradient is the primary one, `userChrome.css` swaps in the other under `prefers-color-scheme` |
| Claude Code | one base per custom theme: the Opaline app rewrites it on each switch while it runs (Claude Code reloads it live) |
| GitHub | the dark colors only |

In the app, **Edit › Add Light Version** (or Dark) creates a starting point from the current colors, and the preview has
a moon/sun switch.

## Design rules

Opaline accepts any colors, but these rules make a theme that works in every app:

1. **Contrast.** `text` on `base`: at least 7:1. `textMuted` on `base`: at least 4.5:1. `accent` on `base`: at least 3:1.
   Text must stay readable on `selection` and `highlight`.
2. **Layer order.** In a dark theme, lightness goes `deep` < `surface` < `base` < `elevated` < `hover`; reverse it
   for a light theme. Steps of 2–5 % lightness look calm.
3. **One accent.** Use `accent` and its variants for focus and brand. Keep `success`, `warning`, `error` recognizable
   (green, yellow/orange, red family) so diffs and checks still read correctly.
4. **Distinct syntax.** `keyword`, `function`, `type`, `string` and `number` should be clearly different hues.
   `comment` is the quietest.
5. **ANSI order matters.** Tools rely on index 1 being red, 2 green, 4 blue. Bright variants are lighter in dark themes
   and darker in light themes.
6. **Glow is subtle.** `backdrop.glowStrength` above 0.3 makes terminal text harder to read.

## Make a theme with an AI

Paste this into Claude (or any assistant), describe the mood you want, then copy the answer and press **⇧⌘V** in Opaline.
The answer can contain prose around the JSON: Opaline extracts the first `{` to the last `}`.

```text
Create an Opaline theme as one JSON object, following the format at
https://github.com/Arthurmtro/Opaline/blob/main/docs/THEME_FORMAT.md

Mood: <describe it: e.g. "deep forest at night, mossy greens, warm amber accent">

Requirements:
- "format": "opaline-theme", "version": 1, a "name", an "author", "appearance" ("dark" or "light").
- A complete "palette" with every role (base, text, accent, deep, surface, elevated, hover, highlight, selection,
  border, borderSubtle, accentSoft, accentDeep, accentDim, textMuted, textSubtle, textFaint, success, warning, error, info).
- "terminal": { "ansi": [16 colors] } in ANSI order, "syntax" with all 11 roles,
  "backdrop", "browser" and "wallpaper" (holo, tagline, ringText, corners).
- Optional: an "alternate" object with the light version (or dark, for a light theme): palette, terminal, syntax,
  backdrop and browser, following the same rules for its own appearance.
- Follow the design rules: text/base contrast >= 7:1, muted text >= 4.5:1, accent >= 3:1, layered backgrounds,
  distinct syntax hues, recognizable success/warning/error.
- Colors as #RRGGBB. Output only the JSON.
```

## Validate a file

The app reports the exact problem on import, for example `palette.accent: Invalid color blue` or
`terminal.ansi: needs exactly 16 colors, found 12`. To check a file outside the app, validate it against the schema:

```sh
npx --yes ajv-cli validate --spec=draft2020 -s schema/theme.schema.json -d my-theme.json
```
