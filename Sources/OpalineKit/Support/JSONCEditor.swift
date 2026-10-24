import Foundation

/// Sets values in a JSON-with-comments document while keeping comments, order and formatting intact.
public enum JSONCEditor {
    public enum Error: Swift.Error, Equatable {
        case notAnObject
        case malformed(offset: Int)
    }

    /// Sets the value at `path` (object keys) to `value`, a JSON literal. Missing objects are created.
    public static func set(_ path: [String], to value: String, in text: String) throws -> String {
        let bytes = Array(text.utf8)
        var scanner = Scanner(bytes: bytes)
        scanner.skipTrivia()
        guard scanner.peek == UInt8(ascii: "{") else { throw Error.notAnObject }
        let edit = try locate(path, value: value, objectStart: scanner.offset, bytes: bytes, depth: 0)
        var result = bytes
        result.replaceSubrange(edit.range, with: Array(edit.replacement.utf8))
        return String(decoding: result, as: UTF8.self)
    }

    /// The raw JSON text of the value at `path`, or nil when a key is missing.
    public static func value(at path: [String], in text: String) throws -> String? {
        let bytes = Array(text.utf8)
        var scanner = Scanner(bytes: bytes)
        scanner.skipTrivia()
        guard scanner.peek == UInt8(ascii: "{") else { throw Error.notAnObject }
        var objectStart = scanner.offset
        for (index, key) in path.enumerated() {
            guard let member = try members(ofObjectAt: objectStart, bytes: bytes).last(where: { $0.key == key }) else { return nil }
            if index == path.count - 1 {
                return String(decoding: bytes[member.valueRange], as: UTF8.self)
            }
            guard bytes[member.valueRange.lowerBound] == UInt8(ascii: "{") else { return nil }
            objectStart = member.valueRange.lowerBound
        }
        return nil
    }

    /// JSON literal for a string value.
    public static func literal(_ string: String) -> String { quoted(string) }

    private struct Edit {
        var range: Range<Int>
        var replacement: String
    }

    private struct Member {
        var key: String
        var valueRange: Range<Int>
    }

    private static func locate(_ path: [String], value: String, objectStart: Int, bytes: [UInt8], depth: Int) throws -> Edit {
        let members = try self.members(ofObjectAt: objectStart, bytes: bytes)
        let key = path[0]
        if let member = members.last(where: { $0.key == key }) {
            if path.count == 1 {
                return Edit(range: member.valueRange, replacement: value)
            }
            if bytes[member.valueRange.lowerBound] == UInt8(ascii: "{") {
                return try locate(Array(path.dropFirst()), value: value, objectStart: member.valueRange.lowerBound, bytes: bytes, depth: depth + 1)
            }
            let indent = lineIndent(at: member.valueRange.lowerBound, bytes: bytes)
            return Edit(range: member.valueRange, replacement: nested(Array(path.dropFirst()), value: value, indent: indent))
        }
        return insertion(path, value: value, objectStart: objectStart, members: members, bytes: bytes)
    }

    private static func insertion(_ path: [String], value: String, objectStart: Int, members: [Member], bytes: [UInt8]) -> Edit {
        let parentIndent = lineIndent(at: objectStart, bytes: bytes)
        let indent = members.first.map { lineIndent(at: $0.valueRange.lowerBound, bytes: bytes) } ?? parentIndent + "  "
        let memberValue = path.count == 1 ? value : nested(Array(path.dropFirst()), value: value, indent: indent)
        let member = "\(quoted(path[0])): \(memberValue)"
        let insertAt = objectStart + 1
        let replacement = members.isEmpty
            ? "\n\(indent)\(member)\n\(parentIndent)"
            : "\n\(indent)\(member),"
        if members.isEmpty, let close = closingBrace(after: insertAt, bytes: bytes) {
            return Edit(range: insertAt..<close, replacement: replacement)
        }
        return Edit(range: insertAt..<insertAt, replacement: replacement)
    }

    private static func nested(_ path: [String], value: String, indent: String) -> String {
        guard let key = path.first else { return value }
        let inner = indent + "  "
        return "{\n\(inner)\(quoted(key)): \(nested(Array(path.dropFirst()), value: value, indent: inner))\n\(indent)}"
    }

    private static func quoted(_ key: String) -> String {
        String(decoding: try! JSONEncoder().encode(key), as: UTF8.self)
    }

    private static func closingBrace(after offset: Int, bytes: [UInt8]) -> Int? {
        var scanner = Scanner(bytes: bytes, offset: offset)
        scanner.skipTrivia()
        return scanner.peek == UInt8(ascii: "}") ? scanner.offset : nil
    }

    private static func lineIndent(at offset: Int, bytes: [UInt8]) -> String {
        var start = offset
        while start > 0, bytes[start - 1] != UInt8(ascii: "\n") { start -= 1 }
        var end = start
        while end < bytes.count, bytes[end] == UInt8(ascii: " ") || bytes[end] == UInt8(ascii: "\t") { end += 1 }
        return String(decoding: bytes[start..<end], as: UTF8.self)
    }

    private static func members(ofObjectAt start: Int, bytes: [UInt8]) throws -> [Member] {
        var scanner = Scanner(bytes: bytes, offset: start + 1)
        var members: [Member] = []
        while true {
            scanner.skipTrivia()
            guard let byte = scanner.peek else { throw Error.malformed(offset: scanner.offset) }
            if byte == UInt8(ascii: "}") { return members }
            if byte == UInt8(ascii: ",") { scanner.offset += 1; continue }
            let keyRange = try scanner.skipValue()
            let key = try JSONDecoder().decode(String.self, from: Data(bytes[keyRange]))
            scanner.skipTrivia()
            guard scanner.peek == UInt8(ascii: ":") else { throw Error.malformed(offset: scanner.offset) }
            scanner.offset += 1
            scanner.skipTrivia()
            members.append(Member(key: key, valueRange: try scanner.skipValue()))
        }
    }

    private struct Scanner {
        let bytes: [UInt8]
        var offset = 0

        var peek: UInt8? { offset < bytes.count ? bytes[offset] : nil }

        mutating func skipTrivia() {
            while let byte = peek {
                if byte == UInt8(ascii: " ") || byte == UInt8(ascii: "\n") || byte == UInt8(ascii: "\r") || byte == UInt8(ascii: "\t") {
                    offset += 1
                } else if byte == UInt8(ascii: "/"), offset + 1 < bytes.count, bytes[offset + 1] == UInt8(ascii: "/") {
                    while let next = peek, next != UInt8(ascii: "\n") { _ = next; offset += 1 }
                } else if byte == UInt8(ascii: "/"), offset + 1 < bytes.count, bytes[offset + 1] == UInt8(ascii: "*") {
                    offset += 2
                    while offset + 1 < bytes.count, !(bytes[offset] == UInt8(ascii: "*") && bytes[offset + 1] == UInt8(ascii: "/")) { offset += 1 }
                    offset += 2
                } else {
                    return
                }
            }
        }

        /// Skips one JSON value and returns its byte range.
        mutating func skipValue() throws -> Range<Int> {
            let start = offset
            guard let byte = peek else { throw Error.malformed(offset: offset) }
            switch byte {
            case UInt8(ascii: "\""):
                offset += 1
                while let next = peek, next != UInt8(ascii: "\"") {
                    offset += next == UInt8(ascii: "\\") ? 2 : 1
                }
                offset += 1
            case UInt8(ascii: "{"), UInt8(ascii: "["):
                let close = byte == UInt8(ascii: "{") ? UInt8(ascii: "}") : UInt8(ascii: "]")
                offset += 1
                while true {
                    skipTrivia()
                    guard let next = peek else { throw Error.malformed(offset: offset) }
                    if next == close { offset += 1; break }
                    if next == UInt8(ascii: ",") || next == UInt8(ascii: ":") { offset += 1; continue }
                    _ = try skipValue()
                }
            default:
                while let next = peek, !",}] \n\r\t/".utf8.contains(next) { offset += 1 }
            }
            guard offset > start, offset <= bytes.count else { throw Error.malformed(offset: start) }
            return start..<offset
        }
    }
}
