// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "ImmersiveKit",
    platforms: [
        .iOS(.v18),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "ImmersiveKit",
            targets: ["ImmersiveKit"]
        ),
    ],
    dependencies: [
        .package(path: "../PrismCore/PrismBackgroundFoundation"),
    ],
    targets: [
        .target(
            name: "ImmersiveKit",
            dependencies: [
                .product(
                    name: "PrismBackgroundFoundation",
                    package: "PrismBackgroundFoundation"
                ),
            ]
        ),
        .testTarget(
            name: "ImmersiveKitTests",
            dependencies: ["ImmersiveKit"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
