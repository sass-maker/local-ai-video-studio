// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "LocalVideoStudio",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "StudioCore", targets: ["StudioCore"]),
        .library(name: "MediaEngine", targets: ["MediaEngine"]),
        .library(name: "StudioAgentSupport", targets: ["StudioAgentSupport"]),
        .executable(name: "LocalVideoStudio", targets: ["StudioApp"]),
        .executable(name: "studio-agent", targets: ["StudioAgent"]),
    ],
    targets: [
        .target(name: "StudioCore"),
        .target(
            name: "MediaEngine",
            dependencies: ["StudioCore"],
            linkerSettings: [
                .linkedFramework("AVFoundation"),
                .linkedFramework("CoreImage"),
            ]
        ),
        .executableTarget(
            name: "StudioApp",
            dependencies: ["StudioCore", "MediaEngine"],
            resources: [.process("Resources")],
            linkerSettings: [
                .linkedFramework("SwiftUI"),
                .linkedFramework("AVKit"),
            ]
        ),
        .target(
            name: "StudioAgentSupport",
            dependencies: ["StudioCore", "MediaEngine"]
        ),
        .executableTarget(
            name: "StudioAgent",
            dependencies: ["StudioAgentSupport"]
        ),
        .testTarget(
            name: "StudioCoreTests",
            dependencies: ["StudioCore"],
            resources: [.process("Fixtures")]
        ),
        .testTarget(name: "MediaEngineTests", dependencies: ["MediaEngine"]),
        .testTarget(name: "StudioAgentSupportTests", dependencies: ["StudioAgentSupport"]),
    ]
)
