#if os(visionOS)
  import ForceGraphCore
  import ForceGraphRealityKit
  import ForceGraphScene
  import RealityKit
  import SwiftUI

  @main
  @available(visionOS 2.0, *)
  struct ForceGraphVisionSample: App {
    var body: some Scene {
      WindowGroup { GraphVolume() }.windowStyle(.volumetric)
    }
  }

  @available(visionOS 2.0, *)
  struct GraphVolume: View {
    private let controller: ForceGraphController<String, String>
    private let scheduler: ForceGraphSceneScheduler<String, String>
    @State private var renderer = RealityKitGraphSynchronizer<String, String>()

    init() {
      let scene = ForceGraphScene(
        nodes: [
          SceneNode(
            physics: ForceNode(id: "a", x: -0.2, y: 0), visual: NodeVisual(label: "A", radius: 0.03)
          ),
          SceneNode(
            physics: ForceNode(id: "b", x: 0.2, y: 0), visual: NodeVisual(label: "B", radius: 0.03)),
        ],
        links: [SceneLink(id: "ab", physics: ForceLink(source: "a", target: "b"))],
        dimensions: .two, policy: LayoutPolicy(warmupTicks: 0), topologyRevision: 1)
      let controller = ForceGraphController(scene: scene)
      self.controller = controller
      self.scheduler = ForceGraphSceneScheduler(controller: controller)
    }

    var body: some View {
      RealityView { content in content.add(renderer.root) }
        .task {
          for await frame in await scheduler.start() { renderer.synchronize(frame: frame) }
        }
        .onDisappear { Task { await scheduler.stop() } }
    }
  }
#endif
