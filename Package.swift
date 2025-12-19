// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "OxideMaster",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "OxideMaster",
            targets: ["OxideMaster"]
        )
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "OxideMaster",
            path: "OxideMaster",
            exclude: ["Info.plist"],
            resources: [
                .process("Assets.xcassets")
            ]
        )
    ]
)
