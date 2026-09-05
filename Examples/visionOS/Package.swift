// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "ForceGraphVisionSample",
  platforms: [.visionOS(.v2)],
  dependencies: [.package(path: "../..")],
  targets: [
    .executableTarget(
      name: "ForceGraphVisionSample",
      dependencies: [
        .product(name: "ForceGraphScene", package: "force-graph-kit"),
        .product(name: "ForceGraphRealityKit", package: "force-graph-kit"),
      ])
  ]
)
