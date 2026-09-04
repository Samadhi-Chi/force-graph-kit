// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ForceGraphKit",
    products: [.library(name: "ForceGraphCore", targets: ["ForceGraphCore"])],
    targets: [
        .target(name: "ForceGraphCore"),
        .testTarget(name: "ForceGraphCoreTests", dependencies: ["ForceGraphCore"])
    ]
)
