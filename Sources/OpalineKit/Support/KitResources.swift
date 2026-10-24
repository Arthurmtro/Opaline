import Foundation

enum KitResources {
    static func url(_ name: String) -> URL {
        Bundle.module.resourceURL!.appending(path: "Resources/\(name)")
    }

    static func text(_ name: String) throws -> String {
        try String(contentsOf: url(name), encoding: .utf8)
    }
}
