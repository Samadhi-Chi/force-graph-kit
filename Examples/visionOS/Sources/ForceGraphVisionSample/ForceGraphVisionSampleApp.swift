#if os(visionOS)
  import ForceGraphCore
  import ForceGraphScene
  import SwiftUI

  @main
  @available(visionOS 2.0, *)
  @MainActor
  struct ForceGraphVisionSample: App {
    private let controller: ForceGraphController<String, String>
    private let scheduler: ForceGraphSceneScheduler<String, String>

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

    var body: some Scene {
      WindowGroup {
        ForceGraphVolumeExample(controller: controller, scheduler: scheduler)
      }.windowStyle(.volumetric)
    }
  }
#endif
