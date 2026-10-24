import Compression
import Foundation

/// Firefox's `mozLz40` container: magic, little-endian decompressed size, raw LZ4 block.
public enum MozLZ4 {
    public enum Error: Swift.Error {
        case badMagic, decompressionFailed, compressionFailed
    }

    private static let magic = Array("mozLz40\0".utf8)

    public static func decode(_ data: Data) throws -> Data {
        let bytes = [UInt8](data)
        guard bytes.count > 12, Array(bytes[0..<8]) == magic else { throw Error.badMagic }
        let size = bytes[8..<12].enumerated().reduce(0) { $0 | Int($1.element) << (8 * $1.offset) }
        var output = [UInt8](repeating: 0, count: size)
        let written = bytes.withUnsafeBufferPointer { source in
            compression_decode_buffer(&output, size, source.baseAddress! + 12, bytes.count - 12, nil, COMPRESSION_LZ4_RAW)
        }
        guard written == size else { throw Error.decompressionFailed }
        return Data(output)
    }

    public static func encode(_ data: Data) throws -> Data {
        let source = [UInt8](data)
        var output = [UInt8](repeating: 0, count: source.count + source.count / 255 + 64)
        let written = compression_encode_buffer(&output, output.count, source, source.count, nil, COMPRESSION_LZ4_RAW)
        guard written > 0 else { throw Error.compressionFailed }
        let size = (0..<4).map { UInt8((source.count >> (8 * $0)) & 0xFF) }
        return Data(magic + size + output[0..<written])
    }
}
