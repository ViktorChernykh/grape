// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "grape",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
    ],
    products: [
        .library(name: "Grape", targets: ["Grape"]),
	],
	dependencies: [
		.package(url: "git@github.com:ViktorChernykh/trader-user-dto.git", from: "0.8.0"),
	],
	targets: [
		.target(
			name: "Grape",
			dependencies: [
				.product(name: "TraderUserDto", package: "trader-user-dto"),
			],
		),
		.testTarget(name: "GrapeTests", dependencies: ["Grape"]),
	]
)
