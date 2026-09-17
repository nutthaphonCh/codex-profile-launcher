// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CodexProfileLauncher",
    platforms: [.macOS(.v12)],
    products: [
        .executable(name: "CodexProfileLauncher", targets: ["CodexProfileLauncher"]),
        .library(name: "CodexProfileLauncherCore", targets: ["CodexProfileLauncherCore"]),
    ],
    targets: [
        .target(name: "CodexProfileLauncherCore"),
        .executableTarget(
            name: "CodexProfileLauncher",
            dependencies: ["CodexProfileLauncherCore"]
        ),
        .testTarget(
            name: "CodexProfileLauncherCoreTests",
            dependencies: ["CodexProfileLauncherCore"]
        ),
    ]
)
