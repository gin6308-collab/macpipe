// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MacPipe",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "MacPipe", targets: ["MacPipe"]),
        .executable(name: "MacPipeWorkbench", targets: ["MacPipeWorkbench"]),
        .executable(name: "macpipe", targets: ["MacPipeCLI"]),
        .library(name: "MacPipeCore", targets: ["MacPipeCore"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "MacPipe",
            dependencies: ["MacPipeCore"]
        ),
        .executableTarget(
            name: "MacPipeWorkbench",
            dependencies: []
        ),
        .executableTarget(
            name: "MacPipeCLI",
            dependencies: ["MacPipeCore"]
        ),
        .target(
            name: "MacPipeCore",
            dependencies: []
        ),
        .testTarget(
            name: "MacPipeCoreTests",
            dependencies: ["MacPipeCore"]
        )
    ]
)
