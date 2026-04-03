// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "JustAVPNCore",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(name: "JustAVPNCore", targets: ["JustAVPNCore"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "JustAVPNCore",
            dependencies: []
        ),
        .testTarget(
            name: "JustAVPNCoreTests",
            dependencies: ["JustAVPNCore"]
        ),
    ]
)
