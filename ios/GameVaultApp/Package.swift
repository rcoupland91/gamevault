// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GameVaultApp",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .executable(name: "GameVaultApp", targets: ["GameVaultApp"])
    ],
    targets: [
        .executableTarget(
            name: "GameVaultApp",
            path: "Sources/GameVaultApp",
            resources: [
                .process("Resources")
            ]
        )
    ]
)
