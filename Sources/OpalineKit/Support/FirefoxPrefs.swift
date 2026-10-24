import Foundation

/// Edits `user_pref(...)` lines of a Firefox-family `prefs.js`.
public enum FirefoxPrefs {
    public enum Value: Sendable, Equatable {
        case bool(Bool)
        case int(Int)
        case string(String)

        var literal: String {
            switch self {
            case .bool(let value): value ? "true" : "false"
            case .int(let value): String(value)
            case .string(let value): String(decoding: try! JSONEncoder().encode(value), as: UTF8.self)
            }
        }
    }

    public static func set(_ values: [(String, Value)], in text: String) -> String {
        var lines = text.components(separatedBy: "\n")
        for (name, value) in values {
            let line = "user_pref(\"\(name)\", \(value.literal));"
            if let index = lines.firstIndex(where: { $0.hasPrefix("user_pref(\"\(name)\",") }) {
                lines[index] = line
            } else {
                let insertAt = lines.last == "" ? lines.count - 1 : lines.count
                lines.insert(line, at: insertAt)
            }
        }
        return lines.joined(separator: "\n")
    }
}
