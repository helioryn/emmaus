// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Emmaus",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Emmaus",
            path: "Sources/Emmaus",
            linkerSettings: [.linkedLibrary("sqlite3")]
        ),
        .testTarget(
            name: "EmmausTests",
            dependencies: ["Emmaus"],
            path: "Tests/EmmausTests",
            linkerSettings: [.linkedLibrary("sqlite3")]
        )
    ]
)
