import SwiftUI
import OpalineKit

struct ThemesView: View {
    @Environment(AppModel.self) private var model
    let theme: Theme
    @State private var editing: Theme?
    @State private var confirmingApply = false
    @State private var confirmingDelete = false
    @State private var previewingWallpaper = false
    @State private var query = ""
    @State private var filter: GalleryFilter = .all
    @State private var hoveredCard: String?
    @FocusState private var searching: Bool

    private var shown: Theme { theme.variant(model.appearance) }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 36) {
                hero
                    .frame(width: 340, alignment: .leading)
                ThemePreview(theme: theme)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(.horizontal, 44)
            .padding(.top, 52)
            .padding(.bottom, 22)
            .frame(maxHeight: .infinity)

            gallery
        }
        .sheet(item: $editing) { draft in
            ThemeEditorView(theme: draft) { saved in
                model.save(saved)
                editing = nil
            } onCancel: {
                editing = nil
            }
            .environment(model)
        }
        .sheet(isPresented: $previewingWallpaper) {
            WallpaperPreviewSheet(theme: shown).environment(model)
        }
        .confirmationDialog("Apply \(theme.name)?", isPresented: $confirmingApply) {
            Button("Apply and Restart \(model.appsThatWillRestart.joined(separator: ", "))") { model.apply(theme) }
        } message: {
            Text("\(model.appsThatWillRestart.joined(separator: " and ")) will close for a moment and reopen with the theme. Your tabs come back.")
        }
        .confirmationDialog(model.library.isModifiedBuiltIn(theme) ? "Reset \(theme.name)?" : "Delete \(theme.name)?", isPresented: $confirmingDelete) {
            Button(model.library.isModifiedBuiltIn(theme) ? "Reset to Original" : "Delete", role: .destructive) { model.delete(theme) }
        } message: {
            Text(model.library.isModifiedBuiltIn(theme)
                 ? "Your changes are removed and the theme shipped with Opaline comes back."
                 : "The theme file is removed. Apps keep their current colors until you apply another theme.")
        }
    }

    private var hero: some View {
        let appliedCount = model.applied.themeByTarget.values.filter { $0 == theme.id }.count
        return VStack(alignment: .leading, spacing: 18) {
            Text(theme.alternate != nil ? "DARK + LIGHT THEME" : (theme.appearance == .dark ? "DARK THEME" : "LIGHT THEME"))
                .font(.system(size: 11, weight: .bold)).kerning(1.6)
                .foregroundStyle(shown.palette.accent.color)
            Text(theme.name)
                .font(.system(size: 46, weight: .bold, design: .rounded))
                .lineLimit(2)
                .minimumScaleFactor(0.6)
            Text(appliedCount > 0 ? "On \(appliedCount) of your apps. By \(theme.author)." : "By \(theme.author). Not applied yet.")
                .font(.system(size: 14))
                .foregroundStyle(Color.primary.opacity(0.65))

            HStack(spacing: -6) {
                ForEach(Array(shown.swatches.enumerated()), id: \.offset) { _, color in
                    Circle()
                        .fill(color.color)
                        .frame(width: 26, height: 26)
                        .overlay(Circle().strokeBorder(.black.opacity(0.35), lineWidth: 2))
                }
            }
            .padding(.vertical, 4)

            HStack(spacing: 22) {
                BigRoundButton(theme: shown, title: "Apply", subtitle: "\(model.targetsToApply.count) apps") {
                    if model.appsThatWillRestart.isEmpty { model.apply(theme) } else { confirmingApply = true }
                }
                VStack(alignment: .leading, spacing: 10) {
                    Button { editing = theme } label: { Label("Edit", systemImage: "slider.horizontal.3") }
                        .buttonStyle(PillButtonStyle())
                    Button { previewingWallpaper = true } label: { Label("Wallpaper", systemImage: "photo") }
                        .buttonStyle(PillButtonStyle())
                    Menu {
                        Button("Save as File…") { model.exporting = theme }
                        Button("Copy JSON") { model.copyJSON(of: theme) }
                    } label: {
                        Label("Export", systemImage: "square.and.arrow.up")
                    }
                    .menuStyle(.button)
                    .buttonStyle(PillButtonStyle())
                    .menuIndicator(.hidden)
                    .fixedSize()
                    Button { model.duplicate(theme) } label: { Label("Duplicate", systemImage: "plus.square.on.square") }
                        .buttonStyle(PillButtonStyle())
                    if model.library.isModifiedBuiltIn(theme) {
                        Button { confirmingDelete = true } label: { Label("Reset", systemImage: "arrow.uturn.backward") }
                            .buttonStyle(PillButtonStyle())
                    } else {
                        Button { confirmingDelete = true } label: { Label("Delete", systemImage: "trash") }
                            .buttonStyle(PillButtonStyle())
                            .disabled(model.library.isPristineBuiltIn(theme))
                            .help(model.library.isPristineBuiltIn(theme) ? "Themes shipped with Opaline can be edited and reset, not deleted." : "")
                    }
                }
            }
            .padding(.top, 8)
        }
    }

    private var shownThemes: [Theme] {
        let words = query.lowercased().split(separator: " ")
        return model.themes
            .filter { item in
                let text = "\(item.name) \(item.author)".lowercased()
                return words.allSatisfy { text.contains($0) } && filter.includes(item, model: model)
            }
            .sorted { lhs, rhs in
                let (left, right) = (model.favoriteIDs.contains(lhs.id), model.favoriteIDs.contains(rhs.id))
                return left != right ? left : lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }
    }

    private var gallery: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                HStack(spacing: 7) {
                    Image(systemName: "magnifyingglass").foregroundStyle(Color.primary.opacity(0.5))
                    TextField("Search themes", text: $query)
                        .textFieldStyle(.plain)
                        .focused($searching)
                    if !query.isEmpty {
                        Button { query = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(Color.primary.opacity(0.45)) }
                            .buttonStyle(.plain)
                    }
                }
                .font(.system(size: 12.5))
                .padding(.horizontal, 11)
                .padding(.vertical, 7)
                .frame(width: 230)
                .background(Color.primary.opacity(searching ? 0.12 : 0.07), in: Capsule())
                .overlay(Capsule().strokeBorder(searching ? shown.palette.accent.color.opacity(0.7) : Color.primary.opacity(0.1), lineWidth: 1))

                ForEach(GalleryFilter.allCases, id: \.self) { item in
                    Button { withAnimation(.easeInOut(duration: 0.2)) { filter = item } } label: {
                        Label(item.title, systemImage: item.symbol)
                            .font(.system(size: 12, weight: .semibold))
                            .padding(.horizontal, 11)
                            .padding(.vertical, 6)
                            .foregroundStyle(filter == item ? shown.palette.deep.color : Color.primary.opacity(0.8))
                            .background(Capsule().fill(filter == item ? AnyShapeStyle(shown.palette.accent.color) : AnyShapeStyle(Color.primary.opacity(0.07))))
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
                Text(shownThemes.count == 1 ? "1 theme" : "\(shownThemes.count) themes")
                    .font(.system(size: 11.5)).foregroundStyle(Color.primary.opacity(0.5))
            }
            .padding(.horizontal, 44)
            .padding(.top, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    VStack(spacing: 10) {
                        DashedCard(symbol: "plus", title: "New Theme", subtitle: "From \(theme.name)") {
                            if let copy = model.duplicate(theme, named: "New Theme") { editing = copy }
                        }
                        DashedCard(symbol: "square.and.arrow.down", title: "Import", subtitle: "File, drop or ⇧⌘V") {
                            model.isImporting = true
                        }
                    }
                    ForEach(shownThemes) { item in
                        ZStack(alignment: .topLeading) {
                            Button {
                                withAnimation(.easeInOut(duration: 0.3)) { model.selectedThemeID = item.id }
                            } label: {
                                ThemeCard(theme: item.variant(model.appearance), selected: item.id == theme.id, applied: model.appliedThemeID == item.id)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(item.name)
                            .contextMenu {
                                Button(model.favoriteIDs.contains(item.id) ? "Remove from Favorites" : "Add to Favorites") { model.toggleFavorite(item) }
                                Button("Duplicate") { model.duplicate(item) }
                                Button("Copy JSON") { model.copyJSON(of: item) }
                            }
                            FavoriteButton(isFavorite: model.favoriteIDs.contains(item.id), visible: hoveredCard == item.id || item.id == theme.id) {
                                model.toggleFavorite(item)
                            }
                            .padding(16)
                        }
                        .onHover { inside in
                            if inside { hoveredCard = item.id } else if hoveredCard == item.id { hoveredCard = nil }
                        }
                    }
                    if shownThemes.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("No theme matches").font(.system(size: 14, weight: .semibold))
                            Text(filter == .favorites && query.isEmpty ? "Star a theme to keep it here." : "Try another word or filter.")
                                .font(.system(size: 12)).foregroundStyle(Color.primary.opacity(0.55))
                        }
                        .frame(width: 210, height: 140, alignment: .leading)
                        .padding(.leading, 8)
                    }
                }
                .padding(.horizontal, 44)
                .padding(.top, 12)
                .padding(.bottom, 20)
            }
        }
        .background(.black.opacity(shown.appearance == .dark ? 0.18 : 0.05))
        .overlay(alignment: .top) { Rectangle().fill(Color.primary.opacity(0.07)).frame(height: 1) }
        .background {
            Button("") { searching = true }
                .keyboardShortcut("f")
                .hidden()
        }
    }
}

enum GalleryFilter: CaseIterable {
    case all, favorites, mine, dark, light

    var title: String {
        switch self {
        case .all: "All"
        case .favorites: "Favorites"
        case .mine: "Mine"
        case .dark: "Dark"
        case .light: "Light"
        }
    }

    var symbol: String {
        switch self {
        case .all: "square.grid.2x2"
        case .favorites: "star.fill"
        case .mine: "person.fill"
        case .dark: "moon.fill"
        case .light: "sun.max.fill"
        }
    }

    @MainActor
    func includes(_ theme: Theme, model: AppModel) -> Bool {
        switch self {
        case .all: true
        case .favorites: model.favoriteIDs.contains(theme.id)
        case .mine: model.library.userIDs.contains(theme.id)
        case .dark: theme.appearances.contains(.dark)
        case .light: theme.appearances.contains(.light)
        }
    }
}

/// Star in the corner of a theme card: always shown for favorites, while the card is hovered for the others.
private struct FavoriteButton: View {
    let isFavorite: Bool
    let visible: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: isFavorite ? "star.fill" : "star")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(isFavorite ? Color(red: 0.98, green: 0.82, blue: 0.4) : .white)
                .frame(width: 26, height: 26)
                .background(.black.opacity(0.45), in: Circle())
                .overlay(Circle().strokeBorder(.white.opacity(0.18), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .opacity(isFavorite || visible ? 1 : 0)
        .animation(.easeInOut(duration: 0.15), value: visible)
        .help(isFavorite ? "Remove from favorites" : "Add to favorites")
    }
}

private struct ThemeCard: View {
    @Environment(AppModel.self) private var model
    let theme: Theme
    let selected: Bool
    let applied: Bool
    @State private var hovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .bottomLeading) {
                WallpaperView(theme: theme)
                    .frame(width: 190, height: 96)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                HStack(spacing: 4) {
                    ForEach(Array(theme.swatches.prefix(6).enumerated()), id: \.offset) { _, color in
                        RoundedRectangle(cornerRadius: 3).fill(color.color).frame(width: 14, height: 14)
                    }
                }
                .padding(10)
                if applied {
                    StatusPill(text: "Applied", tone: .positive)
                        .padding(8)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                }
            }
            .frame(width: 190, height: 96)
            .task(id: theme) { await model.wallpapers.load(theme) }
            Text(theme.name).font(.system(size: 13, weight: .semibold))
        }
        .padding(10)
        .background(Color.primary.opacity(selected ? 0.12 : (hovering ? 0.07 : 0.04)), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(selected ? theme.palette.accent.color : Color.primary.opacity(0.08), lineWidth: selected ? 2 : 1)
        )
        .scaleEffect(hovering ? 1.02 : 1)
        .animation(.spring(response: 0.3, dampingFraction: 0.75), value: hovering)
        .onHover { hovering = $0 }
        .contentShape(Rectangle())
    }
}

private struct DashedCard: View {
    let symbol: String
    let title: String
    let subtitle: String
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: symbol).font(.system(size: 18, weight: .semibold)).frame(width: 22)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 13, weight: .semibold))
                    Text(subtitle).font(.system(size: 10.5)).foregroundStyle(Color.primary.opacity(0.5)).lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .foregroundStyle(Color.primary.opacity(hovering ? 0.95 : 0.75))
            .padding(.horizontal, 14)
            .frame(width: 176, height: 66)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
                    .foregroundStyle(Color.primary.opacity(hovering ? 0.4 : 0.2))
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}
