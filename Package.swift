// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "OpalineKit",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "OpalineKit", targets: ["OpalineKit"]),
    ],
    targets: [
        .target(
            name: "OpalineKit",
            resources: [.copy("Resources")]
        ),
        .testTarget(
            name: "OpalineKitTests",
            dependencies: ["OpalineKit"]
        ),
    ]
)
