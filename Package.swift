// swift-tools-version: 5.5

import PackageDescription

let package = Package(
    name: "grape",
    platforms: [
        .macOS(.v12),
        .iOS(.v13),
    ],
    products: [
        .library(name: "Grape", targets: ["Grape"]),
    ],
    dependencies: [],
    targets: [
        .target(name: "Grape", dependencies: []),
        .testTarget(name: "GrapeTests", dependencies: ["Grape"]),
    ]
)
