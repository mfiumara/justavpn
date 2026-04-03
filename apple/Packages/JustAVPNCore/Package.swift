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
    dependencies: [
        .package(url: "https://github.com/WireGuard/wireguard-apple.git", from: "1.0.15-26"),
    ],
    targets: [
        .target(
            name: "JustAVPNCore",
            dependencies: [
                .product(name: "WireGuardKit", package: "wireguard-apple"),
            ]
        ),
        .testTarget(
            name: "JustAVPNCoreTests",
            dependencies: ["JustAVPNCore"]
        ),
    ]
)
