// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Fake",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Fake", targets: ["Fake"]),
        .library(name: "FakeCore", targets: ["FakeCore"])
    ],
    targets: [
        .target(name: "FakeCore"),
        .executableTarget(name: "Fake", dependencies: ["FakeCore"]),
        .testTarget(name: "FakeCoreTests", dependencies: ["FakeCore"])
    ]
)
