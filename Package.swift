// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "YuzuConverter",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "YuzuApp", targets: ["YuzuApp"])],
    targets: [
        .target(name: "YuzuCore"),
        .executableTarget(name: "YuzuApp", dependencies: ["YuzuCore"],
                          resources: [.copy("Resources/YuzuMenuBar.pdf")]),
        .testTarget(name: "YuzuCoreTests", dependencies: ["YuzuCore"]),
        .testTarget(name: "YuzuAppTests", dependencies: ["YuzuApp"])
    ]
)
