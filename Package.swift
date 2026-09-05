// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "ForceGraphKit",
  platforms: [.macOS(.v14), .iOS(.v17), .visionOS(.v1)],
  products: [
    .library(name: "ForceGraphCore", targets: ["ForceGraphCore"]),
    .library(name: "ForceGraphScene", targets: ["ForceGraphScene"]),
    .library(name: "ForceGraphRealityKit", targets: ["ForceGraphRealityKit"]),
    .executable(name: "force-graph-demo", targets: ["ForceGraphDemo"]),
    .executable(name: "force-graph-benchmark", targets: ["ForceGraphBenchmark"]),
  ],
  targets: [
    .target(name: "ForceGraphCore"),
    .target(name: "ForceGraphScene", dependencies: ["ForceGraphCore"]),
    .target(name: "ForceGraphRealityKit", dependencies: ["ForceGraphScene"]),
    .executableTarget(
      name: "ForceGraphDemo", dependencies: ["ForceGraphCore"], path: "Examples/CLI"),
    .executableTarget(
      name: "ForceGraphBenchmark", dependencies: ["ForceGraphCore"],
      path: "Benchmarks/ForceGraphBenchmark"),
    .testTarget(name: "ForceGraphCoreTests", dependencies: ["ForceGraphCore"]),
    .testTarget(name: "ForceGraphSceneTests", dependencies: ["ForceGraphScene"]),
    .testTarget(
      name: "ForceGraphRealityKitTests",
      dependencies: ["ForceGraphRealityKit", "ForceGraphScene"]),
  ]
)
