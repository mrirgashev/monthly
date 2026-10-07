// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MonthlyNative",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "MonthlyNative", targets: ["MonthlyNative"]),
        .library(name: "WallpaperCore", targets: ["WallpaperCore"])
    ],
    targets: [
        .target(name: "WallpaperCore", resources: [.process("Resources")]),
        .executableTarget(name: "MonthlyNative", dependencies: ["WallpaperCore"]),
        .testTarget(name: "WallpaperCoreTests", dependencies: ["WallpaperCore"]),
        .testTarget(name: "RenderingTests", dependencies: ["MonthlyNative", "WallpaperCore"])
    ]
)
