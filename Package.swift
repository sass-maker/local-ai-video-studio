// swift-tools-version: 6.0

import Foundation
import PackageDescription

// Xcode 26.6 crashes while coverage-instrumenting the SwiftUI executable. The
// quality gate still performs a separate full build with both executables.
let coverageOnly = ProcessInfo.processInfo.environment["FLEET_CODE_HEALTH_COVERAGE"] == "1"

var products: [Product] = [
    .library(name: "StudioCore", targets: ["StudioCore"]),
    .library(name: "MediaEngine", targets: ["MediaEngine"]),
    .library(name: "StudioAgentSupport", targets: ["StudioAgentSupport"]),
]

var targets: [Target] = [
    .target(name: "StudioCore"),
    .target(
        name: "MediaEngine",
        dependencies: ["StudioCore"],
        linkerSettings: [
            .linkedFramework("AVFoundation"),
            .linkedFramework("CoreImage"),
        ]
    ),
    .target(
        name: "StudioAgentSupport",
        dependencies: ["StudioCore", "MediaEngine"]
    ),
    .testTarget(
        name: "StudioCoreTests",
        dependencies: ["StudioCore"],
        resources: [.process("Fixtures")]
    ),
    .testTarget(name: "MediaEngineTests", dependencies: ["MediaEngine"]),
    .testTarget(name: "StudioAgentSupportTests", dependencies: ["StudioAgentSupport"]),
]

if !coverageOnly {
    products += [
        .executable(name: "LocalVideoStudio", targets: ["StudioApp"]),
        .executable(name: "studio-agent", targets: ["StudioAgent"]),
    ]
    targets += [
        .executableTarget(
            name: "StudioApp",
            dependencies: ["StudioCore", "MediaEngine"],
            resources: [.process("Resources")],
            linkerSettings: [
                .linkedFramework("SwiftUI"),
                .linkedFramework("AVKit"),
            ]
        ),
        .executableTarget(
            name: "StudioAgent",
            dependencies: ["StudioAgentSupport"]
        ),
    ]
}

let package = Package(
    name: "LocalVideoStudio",
    platforms: [.macOS(.v14)],
    products: products,
    targets: targets
)
