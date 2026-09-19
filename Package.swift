// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "ImmersiveKit",
    platforms: [
        .iOS(.v26),
        .macOS(.v26),
    ],
    products: [
        .library(
            name: "ImmersiveKit",
            targets: ["ImmersiveKit"]
        ),
    ],
    dependencies: [
        .package(
            url: "https://github.com/danielcr12/PrismCore.git",
            from: "1.1.0"
        ),
    ],
    targets: [
        .target(
            name: "ImmersiveKit",
            dependencies: [
                .product(
                    name: "PrismCoreBackgrounds",
                    package: "PrismCore"
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
