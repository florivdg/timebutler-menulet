// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "TimebutlerMenulet",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "TimebutlerMenulet",
            path: "Sources/TimebutlerMenulet"
        ),
        .testTarget(
            name: "TimebutlerMenuletTests",
            dependencies: ["TimebutlerMenulet"]
        )
    ]
)
