// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "LiveTransCore",
    platforms: [
        .iOS(.v18),
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "LiveTransCore",
            targets: ["LiveTransCore"]
        )
    ],
    targets: [
        .target(
            name: "LiveTransCore"
        ),
        .testTarget(
            name: "LiveTransCoreTests",
            dependencies: ["LiveTransCore"]
        )
    ]
)