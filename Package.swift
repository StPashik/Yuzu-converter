// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "YuzuConverter",
    defaultLocalization: "en",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "YuzuApp", targets: ["YuzuApp"])],
    dependencies: [.package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.10.1")],
    targets: [
        .target(name: "YuzuCore"),
        .executableTarget(name: "YuzuApp", dependencies: ["YuzuCore", .product(name: "Sparkle", package: "Sparkle")],
                          resources: [.process("Resources")],
                          linkerSettings: [.unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])]),
        .testTarget(name: "YuzuCoreTests", dependencies: ["YuzuCore"]),
        .testTarget(name: "YuzuAppTests", dependencies: ["YuzuApp"])
    ]
)
