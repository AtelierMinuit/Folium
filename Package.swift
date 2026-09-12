// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ScribeMac",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "ScribeMac", targets: ["ScribeMac"]),
        .library(name: "ScribeMacCore", targets: ["ScribeMacCore"])
    ],
    targets: [
        .target(
            name: "ScribeMacCore",
            path: "Sources/ScribeMacCore",
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency")
            ]
        ),
        .executableTarget(
            name: "ScribeMac",
            dependencies: ["ScribeMacCore"],
            path: "Sources/ScribeMac",
            exclude: ["Resources"],
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "ScribeMacTests",
            dependencies: ["ScribeMacCore"],
            path: "Tests/ScribeMacTests",
            resources: [
                .copy("../Fixtures")
            ],
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency")
            ]
        )
    ]
)
