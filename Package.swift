// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "DiaRouter",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .executable(name: "DiaRouter", targets: ["DiaRouter"]),
        .executable(name: "DiaRouterLoginItem", targets: ["DiaRouterLoginItem"]),
    ],
    targets: [
        .executableTarget(
            name: "DiaRouter",
            path: "Sources/DiaRouter"
        ),
        .executableTarget(
            name: "DiaRouterLoginItem",
            path: "Sources/DiaRouterLoginItem"
        ),
        .testTarget(
            name: "DiaRouterTests",
            dependencies: ["DiaRouter"],
            path: "Tests/DiaRouterTests"
        ),
    ]
)
