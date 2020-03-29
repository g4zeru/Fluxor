// swift-tools-version:5.1

import PackageDescription

let package = Package(
    name: "Fluxor",
    platforms: [
        .macOS(.v10_15),
        .iOS(.v13),
        .tvOS(.v13),
    ],
    products: [
        .library(
            name: "Fluxor",
            targets: ["Fluxor"]),
    ],
    dependencies: [
        .package(
            url: "https://github.com/Flight-School/AnyCodable",
            from: "0.2.3"),
    ],
    targets: [
        .target(
            name: "Fluxor",
            dependencies: ["AnyCodable"]),
        .testTarget(
            name: "FluxorTests",
            dependencies: ["Fluxor"]),
    ]
)
