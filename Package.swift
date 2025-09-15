// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "JNetworkManager",
    platforms: [.iOS(.v15),
                .macOS(.v12),
                .tvOS(.v15),
                .watchOS(.v8)],
    products: [
        .library(
            name: "JNetworkManager",
            targets: ["JNetworkManager"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/Alamofire/Alamofire.git", .upToNextMajor(from: "5.9.1"))
    ],
    targets: [
        .target(
            name: "JNetworkManager",
            dependencies: ["Alamofire"],
            swiftSettings: [
//                .unsafeFlags(["-enable-actor-data-race-checks"], .when(configuration: .debug))
                .swiftLanguageMode(.v6)
            ]
        ),
        .testTarget(
            name: "JNetworkManagerTests",
            dependencies: ["JNetworkManager"]
        ),
    ]
)

