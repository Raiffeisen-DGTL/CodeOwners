// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "CodeOwners",
    platforms: [.macOS(.v14)],
    products: [
        .library(
            name: "CodeOwners",
            targets: ["CodeOwners"]),
        .library(
            name: "CodeOwnersSwiftUI",
            targets: ["CodeOwnersSwiftUI"])
    ],
    dependencies: [
        .package(url: "hhttps://github.com/Raiffeisen-DGTL/MagicDesign.git", .upToNextMajor(from: "1.0.0"))
    ],
    targets: [
        .target(
            name: "CodeOwners",
            path: "Sources/Service"
        ),
        .target(
            name: "CodeOwnersSwiftUI",
            dependencies: [
                "CodeOwners", 
                .product(name: "MagicDesign", package: "MagicDesign")
            ],
            path: "Sources/SwiftUI"
        )
    ]
)
