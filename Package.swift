// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "clipy",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .executable(name: "clipy", targets: ["clipy"]),
    ],
    targets: [
        .executableTarget(
            name: "clipy"),
    ]
)
