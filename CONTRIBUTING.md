# Contributing

## Your own themes

`themes/custom/` (a shortcut to `Sources/OpalineKit/Resources/Themes/custom/`) is ignored by git: theme files you put
there are bundled into your local builds next to the defaults and never enter the history. Keep personal or company
themes there.

## Share a theme

1. Make it in the app or by hand (see [docs/THEME_FORMAT.md](docs/THEME_FORMAT.md)).
2. Export it (**Export › Save as File…**) and check it against [schema/theme.schema.json](schema/theme.schema.json).
3. Open a pull request adding it to `themes/defaults/<id>.json`, with a screenshot of the preview.

Built-in themes must follow the design rules of the format guide, use your own or permissively licensed colors (credit
the source in `author`), and contain no brand logos you do not own.

## Add an app

An app is a `ThemeTarget` in `Sources/OpalineKit/Targets`:

- `changes(for:in:)` returns the files to write. The engine snapshots every original before writing; never write files
  anywhere else.
- Edit user configs in place: `JSONCEditor` for JSON with comments, `ManagedBlock` for line-based configs,
  `FirefoxPrefs` for `prefs.js`. Keep the user's comments and unrelated settings.
- Set `quitsApp` when the app rewrites its files on quit; the engine closes and reopens it.
- `didApply` reloads the app when it can (a CLI command, a signal).
- Add tests in `Tests/OpalineKitTests` with a sample of the real config file, comments included.
- Register it in `BuiltInTargets.all` and document it in the README table.

If a template is enough (one file, no merging), users can add the app themselves with **Add App**; prefer documenting
the template in an issue.

## Development

```sh
swift test       # engine tests
Scripts/run.sh   # build and launch the app
```

## Release (maintainers)

`OPALINE_TEAM_ID=<team id> Scripts/release.sh <version>` from a clean `main`: builds a universal app, signs it with the
Developer ID of the Apple account signed in to Xcode, waits for notarization, publishes the GitHub release and updates
the cask in [`homebrew-tap`](https://github.com/Arthurmtro/homebrew-tap).

Code style: Swift 6, small focused types, no force unwraps outside static data, comments only for the why.
