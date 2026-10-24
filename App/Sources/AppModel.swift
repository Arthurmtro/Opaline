import AppKit
import Observation
import OpalineKit

/// Progress of the apply (or restore) shown in the sheet.
struct ApplyRun: Identifiable {
    enum Kind { case apply, restore }

    let id = UUID()
    var kind: Kind
    var title: String
    var targets: [TargetInfo]
    var phases: [String: ApplyEvent.Phase] = [:]
    var finished = false
    var error: String?

    var completed: Int {
        phases.values.filter { phase in
            switch phase {
            case .done, .skipped, .failed: true
            default: false
            }
        }.count
    }

    var fraction: Double {
        targets.isEmpty ? 1 : Double(completed) / Double(targets.count)
    }
}

@MainActor
@Observable
final class AppModel {
    let environment = OpalineEnvironment.current
    let wallpapers = WallpaperCache()
    var themes: [Theme] = []
    var library = ThemeLibrary.empty
    var customTargets: [CustomTargetDefinition] = []
    var snapshots: [Snapshot] = []
    var applied = AppliedState()
    var selectedThemeID: String?
    /// Which version of light and dark themes the window and the preview wear; starts as the Mac's.
    var appearance: Appearance = .system
    var run: ApplyRun?
    var errorMessage: String?
    /// Short confirmation shown at the bottom of the window.
    var toast: String?
    var isImporting = false
    var exporting: Theme?
    var enabledTargetIDs: Set<String> {
        didSet { UserDefaults.standard.set(Array(enabledTargetIDs), forKey: Self.enabledKey) }
    }

    private static let enabledKey = "enabledTargets"
    private static let favoritesKey = "favoriteThemes"

    var favoriteIDs: Set<String> = Set(UserDefaults.standard.stringArray(forKey: favoritesKey) ?? []) {
        didSet { UserDefaults.standard.set(Array(favoriteIDs), forKey: Self.favoritesKey) }
    }

    func toggleFavorite(_ theme: Theme) {
        if favoriteIDs.contains(theme.id) { favoriteIDs.remove(theme.id) } else { favoriteIDs.insert(theme.id) }
    }
    private var themeStore: ThemeStore { ThemeStore(environment: environment) }
    private var customStore: CustomTargetStore { CustomTargetStore(environment: environment) }
    private var context: TargetContext { TargetContext(environment: environment) }

    init() {
        let saved = UserDefaults.standard.stringArray(forKey: Self.enabledKey)
        enabledTargetIDs = Set(saved ?? BuiltInTargets.all.map(\.info.id))
        load()
        followAppearance()
        DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("AppleInterfaceThemeChangedNotification"), object: nil, queue: .main
        ) { _ in
            Task { @MainActor in self.followAppearance() }
        }
    }

    /// Rewrites the apps that can't follow the Mac's light and dark switch themselves.
    func followAppearance() {
        let engine = ApplyEngine(environment: environment)
        let (themes, targets) = (themes, targets)
        Task {
            do {
                try await engine.followAppearance(themes, targets: targets)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    var targets: [any ThemeTarget] {
        BuiltInTargets.all + customTargets.map { CustomTarget(definition: $0) }
    }

    var selectedTheme: Theme? {
        themes.first { $0.id == selectedThemeID } ?? themes.first
    }

    /// The selected theme in `appearance`, for colors only: actions take the whole theme.
    var shownTheme: Theme? { selectedTheme?.variant(appearance) }

    var appliedThemeID: String? {
        let counts = Dictionary(grouping: applied.themeByTarget.values, by: { $0 }).mapValues(\.count)
        return counts.max { $0.value < $1.value }?.key
    }

    func load() {
        do {
            library = try themeStore.load()
            themes = library.themes
            customTargets = try customStore.load()
            snapshots = try SnapshotStore(environment: environment).load()
            applied = AppliedState.load(in: environment)
            if selectedThemeID == nil || !themes.contains(where: { $0.id == selectedThemeID }) {
                selectedThemeID = appliedThemeID ?? themes.first?.id
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func isInstalled(_ target: any ThemeTarget) -> Bool {
        target.isInstalled(in: context)
    }

    func files(of target: any ThemeTarget) -> [String] {
        target.files(in: context).map(environment.display)
    }

    func isEnabled(_ target: any ThemeTarget) -> Bool {
        enabledTargetIDs.contains(target.info.id)
    }

    func setEnabled(_ enabled: Bool, for target: any ThemeTarget) {
        if enabled { enabledTargetIDs.insert(target.info.id) } else { enabledTargetIDs.remove(target.info.id) }
    }

    var targetsToApply: [any ThemeTarget] {
        targets.filter { isEnabled($0) && isInstalled($0) }
    }

    /// Names of running apps the apply will close and reopen.
    var appsThatWillRestart: [String] {
        let bundleIDs = Set(targetsToApply.filter(\.info.quitsApp).compactMap(\.info.bundleIdentifier))
        return bundleIDs.compactMap { NSRunningApplication.runningApplications(withBundleIdentifier: $0).first?.localizedName }.sorted()
    }

    func theme(id: String) -> Theme? { themes.first { $0.id == id } }

    // MARK: Apply and restore

    func apply(_ theme: Theme) {
        let targets = targetsToApply
        run = ApplyRun(kind: .apply, title: "Applying \(theme.name)", targets: targets.map(\.info))
        let engine = ApplyEngine(environment: environment)
        Task {
            do {
                _ = try await engine.apply(theme, to: targets) { event in
                    Task { @MainActor in self.run?.phases[event.targetID] = event.phase }
                }
            } catch {
                run?.error = error.localizedDescription
            }
            run?.finished = true
            load()
        }
    }

    func restore(_ snapshot: Snapshot) {
        let involved = targets.filter { snapshot.targetIDs.contains($0.info.id) }
        run = ApplyRun(kind: .restore, title: "Restoring before \(snapshot.themeName)", targets: involved.map(\.info))
        let engine = ApplyEngine(environment: environment)
        Task {
            do {
                try await engine.restore(snapshot, targets: involved)
                for target in involved { run?.phases[target.info.id] = .done }
            } catch {
                run?.error = error.localizedDescription
            }
            run?.finished = true
            load()
        }
    }

    func deleteSnapshot(_ snapshot: Snapshot) {
        perform { try SnapshotStore(environment: environment).delete(snapshot) }
    }

    // MARK: Themes

    func save(_ theme: Theme) {
        perform { try themeStore.save(theme) }
        selectedThemeID = theme.id
    }

    @discardableResult
    func duplicate(_ theme: Theme, named name: String? = nil) -> Theme? {
        var copy: Theme?
        perform { copy = try themeStore.duplicate(theme, named: name ?? "\(theme.name) Copy", existing: themes) }
        if let copy { selectedThemeID = copy.id }
        return copy
    }

    func delete(_ theme: Theme) {
        perform { try themeStore.delete(theme) }
    }

    // MARK: Import and export

    /// Adds theme files picked or dropped by the user and selects the last one.
    func importThemes(from urls: [URL]) {
        var imported: [Theme] = []
        var failures: [String] = []
        for url in urls {
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            do {
                let theme = try ThemeFile.decode(Data(contentsOf: url))
                imported.append(try themeStore.add(theme, existing: themes + imported))
            } catch {
                failures.append("\(url.lastPathComponent): \(error.localizedDescription)")
            }
        }
        finishImport(imported, failures: failures)
    }

    /// Adds the theme in the clipboard, raw JSON or a chat answer that contains it.
    func pasteTheme() {
        guard let text = NSPasteboard.general.string(forType: .string) else {
            errorMessage = "The clipboard has no text. Copy a theme file's content first."
            return
        }
        do {
            let theme = try themeStore.add(try ThemeFile.decode(Data(text.utf8)), existing: themes)
            finishImport([theme], failures: [])
        } catch {
            finishImport([], failures: ["Clipboard: \(error.localizedDescription)"])
        }
    }

    private func finishImport(_ imported: [Theme], failures: [String]) {
        load()
        if let last = imported.last { selectedThemeID = last.id }
        if !imported.isEmpty { show(imported.count == 1 ? "Imported \(imported[0].name)" : "Imported \(imported.count) themes") }
        if !failures.isEmpty { errorMessage = failures.joined(separator: "\n\n") }
    }

    func exportFile(for theme: Theme) -> ThemeJSONFile? {
        do {
            return ThemeJSONFile(data: try ThemeFile.encode(theme))
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func copyJSON(of theme: Theme) {
        guard let file = exportFile(for: theme) else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(String(decoding: file.data, as: UTF8.self), forType: .string)
        show("Copied \(theme.name) as JSON")
    }

    func show(_ message: String) {
        toast = message
        Task {
            try? await Task.sleep(for: .seconds(2.4))
            if toast == message { toast = nil }
        }
    }

    // MARK: Custom apps

    func save(_ definition: CustomTargetDefinition) {
        perform { try customStore.save(definition) }
        enabledTargetIDs.insert(CustomTarget(definition: definition).info.id)
    }

    func delete(_ definition: CustomTargetDefinition) {
        perform { try customStore.delete(definition) }
    }

    private func perform(_ action: () throws -> Void) {
        do {
            try action()
        } catch {
            errorMessage = error.localizedDescription
        }
        load()
    }
}
