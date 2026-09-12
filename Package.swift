// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Folium",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Folium", targets: ["Folium"]),
        .library(name: "FoliumCore", targets: ["FoliumCore"])
    ],
    targets: [
        .target(
            name: "FoliumCore",
            path: "Sources/FoliumCore",
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency")
            ]
        ),
        .executableTarget(
            name: "Folium",
            dependencies: ["FoliumCore"],
            path: "Sources/Folium",
            exclude: ["Resources"],
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "FoliumTests",
            dependencies: ["FoliumCore"],
            path: "Tests/FoliumTests",
            resources: [
                .copy("../Fixtures")
            ],
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency")
            ]
        )
    ]
)
