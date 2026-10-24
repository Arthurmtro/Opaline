import Foundation

/// Flat `key -> value` view of a theme for templates: `palette.accent`, `terminal.ansi.4`, `syntax.keyword`, `name`...
public enum ThemeTokens {
    public static func values(for theme: Theme) -> [String: String] {
        let data = try! JSONEncoder().encode(theme)
        let object = try! JSONSerialization.jsonObject(with: data)
        var values: [String: String] = [:]
        flatten(object, prefix: "", into: &values)
        return values
    }

    /// Renders `{{token}}` and `{{token | filter}}` placeholders. Filters: `rgb` (`136, 207, 148`), `nohash` (`88CF94`),
    /// `opaque` (drops alpha), `upper`, `lower`. Unknown tokens are left as-is so a typo stays visible.
    public static func render(_ template: String, theme: Theme) -> String {
        let values = values(for: theme)
        let pattern = /\{\{\s*([\w.]+)\s*(?:\|\s*(\w+)\s*)?\}\}/
        return template.replacing(pattern) { match in
            let key = String(match.1)
            guard let value = values[key] else { return String(match.0) }
            guard let filter = match.2 else { return value }
            let color = HexColor(value)
            switch filter {
            case "rgb":
                guard let bytes = color?.rgbBytes else { return value }
                return "\(bytes.red), \(bytes.green), \(bytes.blue)"
            case "nohash": return String(value.trimmingPrefix("#"))
            case "opaque": return color?.opaqueHex ?? value
            case "upper": return value.uppercased()
            case "lower": return value.lowercased()
            default: return value
            }
        }
    }

    private static func flatten(_ value: Any, prefix: String, into values: inout [String: String]) {
        switch value {
        case let dictionary as [String: Any]:
            for (key, child) in dictionary {
                flatten(child, prefix: prefix.isEmpty ? key : "\(prefix).\(key)", into: &values)
            }
        case let array as [Any]:
            for (index, child) in array.enumerated() {
                flatten(child, prefix: "\(prefix).\(index)", into: &values)
            }
        case is NSNull:
            break
        default:
            values[prefix] = "\(value)"
        }
    }
}
