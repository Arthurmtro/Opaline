import Foundation

enum KitResources {
    /// The copied `Resources` folder; its place inside the bundle differs between SwiftPM and Xcode builds.
    private static let root = Bundle.module.url(forResource: "Resources", withExtension: nil)!

    static func url(_ name: String) -> URL {
        root.appending(path: name)
    }

    static func text(_ name: String) throws -> String {
        try String(contentsOf: url(name), encoding: .utf8)
    }
}
