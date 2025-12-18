// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DiskOxide",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "DiskOxide",
            targets: ["DiskOxide"]
        )
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "DiskOxide",
            path: "DiskOxide",
            exclude: ["Info.plist"]
        )
    ]
)
