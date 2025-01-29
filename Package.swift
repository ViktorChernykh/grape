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
    dependencies: [
		.package(url: "https://github.com/ViktorChernykh/trader-user-dto.git", from: "0.0.1"),
	],
    targets: [
        .target(name: "Grape", dependencies: [
			.product(name: "TraderUserDto", package: "trader-user-dto"),
		]),
        .testTarget(name: "GrapeTests", dependencies: ["Grape"]),
    ]
)
