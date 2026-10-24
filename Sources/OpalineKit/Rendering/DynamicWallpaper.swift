import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// A HEIC holding a light and a dark image, tagged so macOS switches between them with the system appearance.
enum DynamicWallpaper {
    enum Failure: Error {
        case unreadableImage, encodingFailed
    }

    /// `light` and `dark` are PNG data of the same size.
    static func heic(light: Data, dark: Data) throws -> Data {
        let lightImage = try image(light), darkImage = try image(dark)
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, UTType.heic.identifier as CFString, 2, nil) else {
            throw Failure.encodingFailed
        }
        CGImageDestinationAddImageAndMetadata(destination, lightImage, try appearanceMetadata(), nil)
        CGImageDestinationAddImage(destination, darkImage, nil)
        guard CGImageDestinationFinalize(destination) else { throw Failure.encodingFailed }
        return output as Data
    }

    /// `apple_desktop:apr`: a base64 binary plist naming the image index for each appearance.
    private static func appearanceMetadata() throws -> CGImageMetadata {
        let metadata = CGImageMetadataCreateMutable()
        let namespace = "http://ns.apple.com/namespace/1.0/" as CFString
        guard CGImageMetadataRegisterNamespaceForPrefix(metadata, namespace, "apple_desktop" as CFString, nil) else {
            throw Failure.encodingFailed
        }
        let indexes = try PropertyListSerialization.data(fromPropertyList: ["l": 0, "d": 1], format: .binary, options: 0)
        guard let tag = CGImageMetadataTagCreate(namespace, "apple_desktop" as CFString, "apr" as CFString, .string,
                                                 indexes.base64EncodedString() as CFString),
              CGImageMetadataSetTagWithPath(metadata, nil, "apple_desktop:apr" as CFString, tag) else {
            throw Failure.encodingFailed
        }
        return metadata
    }

    private static func image(_ png: Data) throws -> CGImage {
        guard let source = CGImageSourceCreateWithData(png as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { throw Failure.unreadableImage }
        return image
    }
}
